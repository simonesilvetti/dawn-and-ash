extends Node
## Rete: ENet, lobby, RPC di gioco, ping applicativo e simulatore di lag (--netsim).
## Canali: 0 = lobby (affidabile), 1 = eventi/comandi (affidabile), 2 = snapshot (non affidabile ordinato), 3 = ping.
## Vedi wiki/systems/netcode.md.

signal lobby_changed
signal connection_failed(reason: String)
signal connected
signal game_start
signal host_lost(reason: String)

const DEFAULT_PORT := 7777
const CONNECT_TIMEOUT := 10.0

var peer: ENetMultiplayerPeer
var world: World
var is_host := false
var in_game := false
var lobby: Dictionary = {}              # peer_id -> {"name", "ready"}
var rtt: float = 0.0                    # secondi
var loss: float = 0.0
var netsim := {"latency": 0.0, "jitter": 0.0, "loss": 0.0}   # latency = RTT aggiuntivo in ms
var stats_enabled := false
var bytes_in: int = 0
var bytes_out: int = 0
var snapshots_in: int = 0
var snapshots_dropped: int = 0

var _delayed: Array = []                # [deliver_time, Callable]
var _last_reliable_in: float = 0.0
var _last_reliable_out: float = 0.0
var _ping_timer: float = 0.0
var _connect_timer: float = -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var ns := Game.arg_value("--netsim", "")
	if ns != "":
		for part in ns.split(","):
			var kv := part.split("=")
			if kv.size() == 2 and netsim.has(kv[0]):
				netsim[kv[0]] = float(kv[1])
		print("[net] simulatore di rete attivo: ", netsim)


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func netsim_active() -> bool:
	return netsim.latency > 0.0 or netsim.jitter > 0.0 or netsim.loss > 0.0


# --- Connessione ----------------------------------------------------------------

func host(port: int) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1, 4)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	lobby = {1: {"name": Game.player_name, "ready": false}}
	lobby_changed.emit()
	return OK


func join(ip: String, port: int) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, 4)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	_connect_timer = CONNECT_TIMEOUT
	return OK


func leave() -> void:
	in_game = false
	_delayed.clear()
	_connect_timer = -1.0
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	lobby.clear()
	is_host = false
	rtt = 0.0


func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.contains(":"):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("100."):
			out.append(a)
		elif a.begins_with("172."):
			var second := int(a.split(".")[1])
			if second >= 16 and second <= 31:
				out.append(a)
	return out


func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	# solo un avversario
	if lobby.size() >= 2 or in_game:
		_reject.rpc_id(id, "La partita è già piena.")
		_kick_later(id)
		return
	print("[net] peer connesso: ", id)
	var p := peer.get_peer(id)
	if p:
		p.set_timeout(32, 5000, 8000)


func _kick_later(id: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if peer:
		peer.disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	print("[net] peer disconnesso: ", id)
	lobby.erase(id)
	lobby_changed.emit()
	if in_game and world:
		world.remote_player_left(id)


func _on_connected_to_server() -> void:
	_connect_timer = -1.0
	var p := peer.get_peer(1)
	if p:
		p.set_timeout(32, 5000, 8000)
	_send(func(): _hello.rpc_id(1, Game.VERSION, Game.player_name), true)
	connected.emit()


func _on_connection_failed() -> void:
	_connect_timer = -1.0
	leave()
	connection_failed.emit("Impossibile connettersi all'host.")


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	host_lost.emit("Connessione con l'host persa." if was_in_game else "L'host ha chiuso la partita.")


# --- Lobby -------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: String, pname: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if version != Game.VERSION:
		_reject.rpc_id(id, "Versione diversa: host %s, tu %s. Usate la stessa versione del gioco." % [Game.VERSION, version])
		_kick_later(id)
		return
	if lobby.size() >= 2 or in_game:
		_reject.rpc_id(id, "La partita è già piena.")
		_kick_later(id)
		return
	lobby[id] = {"name": pname.substr(0, 20), "ready": false}
	lobby_changed.emit()
	_lobby_state.rpc(lobby)


@rpc("authority", "call_remote", "reliable", 0)
func _reject(reason: String) -> void:
	leave()
	connection_failed.emit(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _lobby_state(state: Dictionary) -> void:
	lobby = state
	lobby_changed.emit()


func set_ready(r: bool) -> void:
	if is_host:
		lobby[1].ready = r
		lobby_changed.emit()
		_lobby_state.rpc(lobby)
		_check_start()
	else:
		_send(func(): _set_ready.rpc_id(1, r), true)


@rpc("any_peer", "call_remote", "reliable", 0)
func _set_ready(r: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host or not lobby.has(id):
		return
	lobby[id].ready = r
	lobby_changed.emit()
	_lobby_state.rpc(lobby)
	_check_start()


func _check_start() -> void:
	if lobby.size() < 2:
		return
	for v in lobby.values():
		if not v.ready:
			return
	in_game = true
	_start_game.rpc()
	game_start.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _start_game() -> void:
	in_game = true
	for id in lobby:
		if id == 1:
			Game.opponent_name = lobby[id].name
	game_start.emit()


## Il client ha caricato la scena di gioco.
func client_loaded() -> void:
	_send(func(): _client_loaded.rpc_id(1), true)


@rpc("any_peer", "call_remote", "reliable", 0)
func _client_loaded() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host and world and lobby.has(id):
		world.add_remote_player(id, lobby[id].name)


# --- Gioco: server -> client ------------------------------------------------------

func send_events(peers: Array, tick: int, evs: Array) -> void:
	for id in peers:
		_events.rpc_id(id, tick, evs)


func send_snapshot(peer_id: int, data: PackedByteArray) -> void:
	_snapshot.rpc_id(peer_id, data)
	if stats_enabled:
		bytes_out += data.size() + 8


func send_state(peers: Array, d: Dictionary) -> void:
	for id in peers:
		_state.rpc_id(id, d)


func send_countdown(peers: Array, c: float) -> void:
	for id in peers:
		_countdown.rpc_id(id, c)


@rpc("authority", "call_remote", "reliable", 1)
func _events(tick: int, evs: Array) -> void:
	if stats_enabled:
		bytes_in += var_to_bytes(evs).size() + 12
	_recv(_deliver_events.bind(tick, evs), true)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _snapshot(data: PackedByteArray) -> void:
	if stats_enabled:
		bytes_in += data.size() + 8
	snapshots_in += 1
	_recv(_deliver_snapshot.bind(data), false)


@rpc("authority", "call_remote", "reliable", 1)
func _state(d: Dictionary) -> void:
	if stats_enabled:
		bytes_in += var_to_bytes(d).size()
	_recv(_deliver_state.bind(d), true)


@rpc("authority", "call_remote", "reliable", 1)
func _countdown(c: float) -> void:
	_recv(_deliver_countdown.bind(c), true)


# --- Gioco: client -> server ------------------------------------------------------

func send_command(seq: int, cmd: Array) -> void:
	_send(func(): _command.rpc_id(1, seq, cmd), true)


@rpc("any_peer", "call_remote", "reliable", 1)
func _command(seq: int, cmd: Array) -> void:
	if not is_host or world == null:
		return
	# convalida: solo tipi semplici, dimensione contenuta
	if cmd.size() == 0 or cmd.size() > 6:
		return
	for v in cmd:
		var t := typeof(v)
		if t != TYPE_INT and t != TYPE_FLOAT and t != TYPE_STRING and t != TYPE_BOOL:
			return
		if t == TYPE_STRING and (v as String).length() > 24:
			return
	world.receive_command(multiplayer.get_remote_sender_id(), seq, cmd)


@rpc("any_peer", "call_remote", "unreliable", 3)
func _ping(t: float) -> void:
	if is_host:
		_pong.rpc_id(multiplayer.get_remote_sender_id(), t)


@rpc("authority", "call_remote", "unreliable", 3)
func _pong(t: float) -> void:
	_recv(_deliver_pong.bind(t), false)


func _deliver_events(tick: int, evs: Array) -> void:
	if world:
		world.client_receive_events(tick, evs)


func _deliver_snapshot(data: PackedByteArray) -> void:
	if world:
		world.client_receive_snapshot(data)


func _deliver_state(d: Dictionary) -> void:
	if world:
		world.client_receive_state(d)


func _deliver_countdown(c: float) -> void:
	if world:
		world.client_set_countdown(c)


func _deliver_pong(t: float) -> void:
	var r := _now() - t
	rtt = r if rtt <= 0.0 else lerpf(rtt, r, 0.2)


# --- Simulatore di rete ---------------------------------------------------------

func _delay() -> float:
	var one_way: float = netsim.latency * 0.5 / 1000.0
	var j: float = netsim.jitter / 1000.0
	return maxf(0.0, one_way + _rng.randf_range(-j, j))


## Consegna di un messaggio in arrivo (lato client) passando dal simulatore.
func _recv(cb: Callable, reliable: bool) -> void:
	if is_host or not netsim_active():
		cb.call()
		return
	if not reliable and _rng.randf() * 100.0 < netsim.loss:
		snapshots_dropped += 1
		return
	var t := _now() + _delay()
	if reliable:
		# i messaggi affidabili restano in ordine (e una perdita = ritrasmissione = ritardo)
		if _rng.randf() * 100.0 < netsim.loss:
			t += netsim.latency / 1000.0
		t = maxf(t, _last_reliable_in)
		_last_reliable_in = t
	_delayed.append([t, cb])


func _send(cb: Callable, reliable: bool) -> void:
	if is_host or not netsim_active():
		cb.call()
		return
	var t := _now() + _delay()
	if reliable:
		t = maxf(t, _last_reliable_out)
		_last_reliable_out = t
	_delayed.append([t, cb])


func _process(delta: float) -> void:
	if not _delayed.is_empty():
		var now := _now()
		var i := 0
		while i < _delayed.size():
			if _delayed[i][0] <= now:
				var cb: Callable = _delayed[i][1]
				_delayed.remove_at(i)
				if peer:
					cb.call()
			else:
				i += 1
	if _connect_timer > 0.0:
		_connect_timer -= delta
		if _connect_timer <= 0.0:
			leave()
			connection_failed.emit("Timeout: nessuna risposta dall'host (controlla IP, porta e firewall).")
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 0.5
		if is_host:
			for id in lobby:
				if id != 1:
					var p := peer.get_peer(id)
					if p:
						rtt = p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 1000.0
						loss = p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE)
		else:
			var t := _now()
			_send(func(): _ping.rpc_id(1, t), false)
			var p := peer.get_peer(1)
			if p:
				loss = p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) + netsim.loss / 100.0
