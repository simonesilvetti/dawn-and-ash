class_name World
extends Node3D
## Partita in corso. Server/allenamento: esegue Sim a tick fisso e applica gli eventi localmente.
## Client: riceve snapshot (interpolazione) ed eventi (ritardati per sincronizzarli), predice il proprio eroe.
## Vedi wiki/systems/netcode.md.

signal finished(result: Dictionary)
signal leave_requested

var mode: int = Game.Mode.TRAINING
var is_server := true
var local_peer: int = 1
var quality: int = 1
var sim: Sim
var running := false
var countdown: float = 0.0

var units: Dictionary = {}              # id -> Unit (sul server = sim.units)
var views: Dictionary = {}              # id -> UnitView
var hero_data: Dictionary = {}          # peer -> HeroData (sul server = sim.heroes)
var game_time: float = 0.0
var wave_in: float = Game.FIRST_WAVE
var team_kills := [0, 0]
var over := false
var winner: int = -1
var forfeit := false

var map_root: Node3D
var units_root: Node3D
var vfx: Vfx
var cam: CameraRig
var ui: CanvasLayer
var overlay: Overlay
var hud: Hud

var _acc: float = 0.0
var _state_timer: float = 0.0
var _view_pool: Dictionary = {}
var _remote_peers: Array = []          # peer dei client in gioco (server)
var _remote_ready: Dictionary = {}

# --- Client: interpolazione ---
var _buffers: Dictionary = {}           # id -> Array [[t, Vector2, facing]]
var _clock: float = 0.0                 # stima del tempo server
var _clock_init := false
var _event_queue: Array = []            # [[t, events]]
var _max_jump_seen: float = 0.0

# --- Client: predizione del proprio eroe ---
var _pred_pos := Vector2.ZERO
var _pred_active := false
var _pred_goal := Vector2.ZERO
var _pred_has_goal := false
var _pred_target: int = 0
var _pred_hist: Array = []              # [[local_time, pos]]
var _srv_sample: Array = []             # ultimo stato server del proprio eroe: [local_time_arrivo, pos]
var _correction := Vector2.ZERO         # correzione residua da applicare gradualmente
var _last_cmd_time: float = -100.0
var _cmd_times: Dictionary = {}         # seq -> istante locale di invio
var _srv_local_time: float = -1.0
var _latest_snap_t: float = -1.0
var _prev_snap_t: float = -1.0
var _local_time: float = 0.0
var recon_err_sum: float = 0.0
var recon_err_n: int = 0
var recon_err_max: float = 0.0

# --- Input ---
var hovered_id: int = 0
var targeting_slot: int = -1
var attack_move_mode := false
var _drag_timer: float = 0.0
var _range_ring: MeshInstance3D
var _aoe_ring: MeshInstance3D
var _cmd_seq: int = 0
var input_enabled := true
var _music_state := "calm"
var _motes: GPUParticles3D
var _last_combat_time: float = -100.0

const AI_TEAM_COLOR := 0
## Allineamento temporale della riconciliazione, in tick (determinato con i test di rete).
static var RECON_TICK_OFFSET: float = 0.0


func setup(m: int, peer: int) -> void:
	mode = m
	is_server = m != Game.Mode.CLIENT
	local_peer = peer
	quality = int(Game.settings.quality)
	Game.local_team = Game.Team.RADIANT if is_server else Game.Team.DIRE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply_quality(get_viewport())
	map_root = Node3D.new()
	map_root.name = "Map"
	add_child(map_root)
	MapBuilder.build(map_root, quality)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	vfx = Vfx.new()
	vfx.world = self
	vfx.quality = quality
	add_child(vfx)
	cam = CameraRig.new()
	cam.vfx = vfx
	cam.follow_target = func() -> Vector3: return local_hero_pos3()
	add_child(cam)
	if quality >= 1:
		_motes = MapBuilder.make_ambient_motes()
		add_child(_motes)
	_build_target_rings()
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	overlay = Overlay.new()
	overlay.world = self
	ui.add_child(overlay)
	hud = Hud.new()
	hud.world = self
	ui.add_child(hud)
	vfx.warmup()
	_prewarm_views()

	if is_server:
		sim = Sim.new(mode == Game.Mode.TRAINING)
		units = sim.units
		hero_data = sim.heroes
		sim.add_hero(local_peer, Game.Team.RADIANT, Game.player_name)
		_flush_events()
		if mode == Game.Mode.TRAINING:
			running = true
		else:
			countdown = -1.0    # in attesa che il client carichi
	cam.center_on(MapData.to3(MapData.FOUNTAIN[Game.local_team] + MapData.team_dir(Game.local_team) * 12.0), true)
	Audio.play_music("calm")
	if mode == Game.Mode.TRAINING:
		hud.notify("Distruggi l'Antico del Culto della Cenere!", Color(1, 0.85, 0.4))


## Antialiasing e risoluzione 3D per preset (Bassa / Media / Alta).
func _apply_quality(vp: Viewport) -> void:
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][quality]
	vp.screen_space_aa = [Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_DISABLED][quality]
	vp.scaling_3d_scale = [0.75, 1.0, 1.0][quality]


func _build_target_rings() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/vfx/fx_ring.gdshader")
		m.set_shader_parameter("color", Color(0.5, 0.8, 1.0, 0.6) if i == 0 else Color(1.0, 0.55, 0.2, 0.8))
		m.set_shader_parameter("thickness", 0.04 if i == 0 else 0.1)
		m.set_shader_parameter("fill", 0.0 if i == 0 else 0.25)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		if i == 0: _range_ring = mi
		else: _aoe_ring = mi


# ============================================================================
# Accesso allo stato
# ============================================================================

func local_hero_data() -> HeroData:
	return hero_data.get(local_peer)


func local_hero_unit() -> Unit:
	var hd := local_hero_data()
	return units.get(hd.unit_id) if hd else null


func local_hero_pos3() -> Vector3:
	var hd := local_hero_data()
	if hd and views.has(hd.unit_id):
		return (views[hd.unit_id] as UnitView).vis_pos
	return Vector3.ZERO


func view_hit_point(id: int) -> Vector3:
	var v: UnitView = views.get(id)
	if v == null or v.dead:
		return Vector3.INF
	var h := 1.2
	if v.kind == Game.Kind.TOWER: h = 5.0
	elif v.kind == Game.Kind.ANCIENT: h = 6.0
	return v.vis_pos + Vector3(0, h, 0)


func hero_of_unit(id: int) -> HeroData:
	for hd in hero_data.values():
		if hd.unit_id == id:
			return hd
	return null


# ============================================================================
# Ciclo principale
# ============================================================================

func _process(delta: float) -> void:
	_local_time += delta
	var t0 := Time.get_ticks_usec()
	if is_server:
		_server_process(delta)
	else:
		_client_process(delta)
	var t1 := Time.get_ticks_usec()
	_update_views(delta)
	var t2 := Time.get_ticks_usec()
	if _motes:
		_motes.global_position = cam.focus + Vector3(0, 2.5, 0)
	if Game.prof_enabled:
		Game.prof_add("sim+eventi", t1 - t0)
		Game.prof_add("viste", t2 - t1)
	_update_hover()
	_update_targeting_rings()
	_update_music()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and input_enabled and targeting_slot < 0 and not attack_move_mode:
		_drag_timer -= delta
		if _drag_timer <= 0.0:
			_drag_timer = 0.12
			_right_click(get_viewport().get_mouse_position(), false)


func _server_process(delta: float) -> void:
	if countdown > 0.0:
		countdown -= delta
		if countdown <= 0.0:
			running = true
	if not running:
		return
	_acc += delta
	var n := 0
	while _acc >= Game.TICK and n < 5:
		_acc -= Game.TICK
		n += 1
		sim.tick()
		_flush_events()
		if not _remote_peers.is_empty():
			var full := sim.tick_n % Game.SNAPSHOT_FULL_EVERY == 0
			_send_snapshots(sim.build_snapshot(full))
	if n == 5:
		_acc = 0.0   # evita la "spirale della morte" se il frame è lentissimo
	game_time = sim.time
	wave_in = sim.next_wave_in()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = 0.2
		team_kills = [0, 0]
		for hd in sim.heroes.values():
			team_kills[hd.team] += hd.kills
		if not _remote_peers.is_empty():
			Net.send_state(_remote_peers, _state_dict())


## Snapshot per ogni client, con intestazione personale: ultimo comando eseguito e relativo tick
## (permette al client di allineare esattamente la riconciliazione, anche con jitter).
func _send_snapshots(body: PackedByteArray) -> void:
	for peer in _remote_peers:
		var head := StreamPeerBuffer.new()
		head.put_u32(sim.last_seq.get(peer, 0))
		head.put_u32(sim.last_seq_tick.get(peer, 0))
		var data := head.data_array
		data.append_array(body)
		Net.send_snapshot(peer, data)


func _state_dict() -> Dictionary:
	var hs: Array = []
	for hd in sim.heroes.values():
		hs.append(hd.to_dict())
	return {"time": sim.time, "wave": sim.next_wave_in(), "k": team_kills, "h": hs, "cd": countdown}


func _flush_events() -> void:
	if sim.events.is_empty():
		return
	var evs := sim.events
	sim.events = []
	_apply_events(evs)
	if not _remote_peers.is_empty():
		Net.send_events(_remote_peers, sim.tick_n, evs)


func _client_process(delta: float) -> void:
	if countdown > 0.0:
		countdown -= delta
	_clock += delta
	game_time = _clock
	wave_in = maxf(0.0, wave_in - delta)
	for hd in hero_data.values():
		for i in 4:
			hd.cooldowns[i] = maxf(0.0, hd.cooldowns[i] - delta)
		if hd.respawn_timer > 0.0:
			hd.respawn_timer = maxf(0.0, hd.respawn_timer - delta)
	# eventi sincronizzati con il tempo di rendering (stesso ritardo dell'interpolazione)
	var render_t := _clock - Game.INTERP_DELAY
	while not _event_queue.is_empty() and _event_queue[0][0] <= render_t + 0.0001:
		_apply_events(_event_queue.pop_front()[1])
	_update_prediction(delta)


# ============================================================================
# Server: giocatori remoti
# ============================================================================

func add_remote_player(peer: int, pname: String) -> void:
	if not is_server or _remote_peers.has(peer):
		return
	Game.opponent_name = pname
	sim.add_hero(peer, Game.Team.DIRE, pname)
	# stato iniziale completo, poi gli eventi normali
	var initial := sim.spawn_events_for_all()
	Net.send_events([peer], sim.tick_n, initial)
	_remote_peers.append(peer)
	_flush_events()
	_send_snapshots(sim.build_snapshot(true))
	Net.send_state(_remote_peers, _state_dict())
	countdown = 3.0
	Net.send_countdown(_remote_peers, 3.0)


func remote_player_left(peer: int) -> void:
	if not _remote_peers.has(peer):
		return
	_remote_peers.erase(peer)
	if not over:
		forfeit = true
		_end_game(Game.local_team)


func receive_command(peer: int, seq: int, cmd: Array) -> void:
	if is_server and running and _remote_peers.has(peer):
		sim.queue_command(peer, cmd, seq)


# ============================================================================
# Client: ricezione
# ============================================================================

func client_receive_events(tick: int, evs: Array) -> void:
	var t := tick * Game.TICK
	if not _clock_init:
		_clock = t
		_clock_init = true
	# lo spawn iniziale va applicato subito
	if _event_queue.is_empty() and t <= _clock - Game.INTERP_DELAY:
		_apply_events(evs)
	else:
		_event_queue.append([t, evs])


func client_receive_state(d: Dictionary) -> void:
	wave_in = float(d.get("wave", wave_in))
	team_kills = d.get("k", team_kills)
	for hdict in d.get("h", []):
		var peer := int(hdict.get("p", 0))
		var hd: HeroData = hero_data.get(peer)
		if hd == null:
			hd = HeroData.new()
			hero_data[peer] = hd
		hd.from_dict(hdict)


func client_set_countdown(c: float) -> void:
	countdown = c


func client_receive_snapshot(data: PackedByteArray) -> void:
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	if data.size() < 14:
		return
	var ack_seq := buf.get_u32()
	var ack_tick := buf.get_u32()
	var tick := buf.get_u32()
	var count := buf.get_u16()
	var t := tick * Game.TICK
	if t <= _prev_snap_t:
		return   # snapshot vecchio o duplicato
	var prev_snap := _latest_snap_t
	_latest_snap_t = t
	_prev_snap_t = t
	# istante locale corrispondente allo stato del proprio eroe in questo snapshot
	if _cmd_times.has(ack_seq):
		_srv_local_time = float(_cmd_times[ack_seq]) + (tick - ack_tick + 1) * Game.TICK
	else:
		_srv_local_time = -1.0
	if not _clock_init:
		_clock = t
		_clock_init = true
	# sincronizzazione morbida dell'orologio sul tempo del server
	var diff := t - _clock
	if absf(diff) > 0.3:
		_clock = t
	else:
		_clock += diff * 0.05
	for i in count:
		if buf.get_position() + 3 > data.size():
			return   # pacchetto troncato: ignora il resto (mai crashare)
		var id := buf.get_u16()
		var mask := buf.get_u8()
		var u: Unit = units.get(id)
		var p := Vector2.INF
		var f := 0.0
		if mask & Sim.M_POS:
			p = Vector2(buf.get_16() / 100.0, buf.get_16() / 100.0)
			f = buf.get_u8() / 256.0 * TAU
		var hp := -1.0
		var mana := -1.0
		if mask & Sim.M_HP: hp = buf.get_u16()
		if mask & Sim.M_MANA: mana = buf.get_u16()
		var fl := -1
		if mask & Sim.M_FLAGS: fl = buf.get_u8()
		var mh := -1.0
		var mm := -1.0
		if mask & Sim.M_MAX:
			mh = buf.get_u16()
			mm = buf.get_u16()
		if u == null:
			continue
		if p != Vector2.INF:
			var b: Array = _buffers.get(id, [])
			if not b.is_empty() and b.back()[0] >= t:
				continue
			# non inviata negli snapshot precedenti = era ferma: aggiungi un campione di "sosta"
			if not b.is_empty() and b.back()[0] < prev_snap - 0.001:
				b.append([prev_snap, b.back()[1], b.back()[2]])
			if not b.is_empty():
				var jump: float = (b.back()[1] as Vector2).distance_to(p)
				_max_jump_seen = maxf(_max_jump_seen, jump)
			b.append([t, p, f])
			if b.size() > 12:
				b.pop_front()
			_buffers[id] = b
			u.pos = p
			u.facing = f
			if u.owner_peer == local_peer and u.is_hero():
				_srv_sample = [_srv_local_time if _srv_local_time >= 0.0 else _local_time - Net.rtt, p]
		if hp >= 0.0:
			u.hp = hp
		if mana >= 0.0: u.mana = mana
		if fl >= 0:
			u.flags = fl
			u.invulnerable = (fl & Unit.F_INVULN) != 0
		if mh >= 0.0:
			u.max_hp = maxf(1.0, mh)
			u.max_mana = mm


func _interp_pos(id: int, render_t: float) -> Array:
	var b: Array = _buffers.get(id, [])
	if b.is_empty():
		var u: Unit = units.get(id)
		return [u.pos if u else Vector2.ZERO, u.facing if u else 0.0]
	if render_t <= b[0][0]:
		return [b[0][1], b[0][2]]
	for i in range(b.size() - 1):
		var a: Array = b[i]
		var c: Array = b[i + 1]
		if render_t >= a[0] and render_t <= c[0]:
			var k: float = (render_t - a[0]) / maxf(0.0001, c[0] - a[0])
			if (a[1] as Vector2).distance_to(c[1]) > 4.0:
				return [c[1] if k > 0.5 else a[1], c[2]]   # teletrasporto: niente interpolazione
			return [(a[1] as Vector2).lerp(c[1], k), lerp_angle(a[2], c[2], k)]
	# oltre l'ultimo campione: se snapshot più recenti non la contengono, l'unità è ferma
	var last: Array = b.back()
	if last[0] < _latest_snap_t - 0.001:
		return [last[1], last[2]]
	# altrimenti (pacchetti in ritardo) estrapolazione breve (max 200 ms)
	if b.size() >= 2:
		var prev: Array = b[b.size() - 2]
		var dt: float = last[0] - prev[0]
		if dt > 0.0:
			var vel: Vector2 = ((last[1] as Vector2) - prev[1]) / dt
			if vel.length() < 15.0:
				var ex := minf(render_t - last[0], 0.2)
				return [(last[1] as Vector2) + vel * ex, last[2]]
	return [last[1], last[2]]


# --- Predizione del proprio eroe -------------------------------------------

func _local_hero_speed() -> float:
	var hd := local_hero_data()
	var s: float = Game.HERO.move_speed
	if hd:
		for it in hd.items:
			if it != "":
				s += Game.ITEMS[it].get("move_speed", 0.0)
	var u := local_hero_unit()
	if u and (u.flags & Unit.F_SLOWED):
		s *= 0.6
	return s


func _update_prediction(delta: float) -> void:
	var u := local_hero_unit()
	if u == null:
		_pred_active = false
		return
	var server_now: Array = _interp_pos(u.id, _clock)   # stato server più recente
	var blocked := not u.alive or (u.flags & (Unit.F_STUNNED | Unit.F_CASTING | Unit.F_DEAD)) != 0
	if not _pred_active or blocked:
		_pred_pos = server_now[0]
		_pred_active = true
		_pred_hist.clear()
		if blocked:
			return
	# negli stati stabili (attacco in corso, fermo) senza comandi recenti si segue il server
	if _local_time - _last_cmd_time > Net.rtt + 0.15:
		if (u.flags & Unit.F_ATTACKING) != 0 or (u.flags & Unit.F_MOVING) == 0:
			_pred_has_goal = false
			_pred_target = 0
	# movimento predetto (stesse regole del server)
	var goal := Vector2.INF
	if _pred_target != 0:
		var t: Unit = units.get(_pred_target)
		if t == null or not t.alive:
			_pred_target = 0
		else:
			var tp: Vector2 = _interp_pos(t.id, _clock - Game.INTERP_DELAY)[0]
			if _pred_pos.distance_to(tp) > Game.HERO.attack_range + u.radius + t.radius:
				goal = tp
	elif _pred_has_goal:
		goal = _pred_goal
	if goal != Vector2.INF:
		var to := goal - _pred_pos
		var step := _local_hero_speed() * delta
		if to.length() <= step:
			_pred_pos = goal
			if _pred_target == 0:
				_pred_has_goal = false
		else:
			_pred_pos += to.normalized() * step
		_pred_pos = MapData.clamp_walkable(_client_push_buildings(_pred_pos, u.radius, to.normalized()), u.radius)
	# Riconciliazione: ogni nuovo stato del server viene confrontato con la predizione di allora.
	# Lo stato del tick T riflette i comandi arrivati ~RTT/2 dopo l'invio e giunge qui ~RTT/2 dopo:
	# corrisponde quindi alla predizione di (arrivo - RTT - mezzo tick).
	_pred_hist.append([_local_time, _pred_pos])
	while _pred_hist.size() > 120:
		_pred_hist.pop_front()
	if not _srv_sample.is_empty():
		var at: float = _srv_sample[0] + Game.TICK * RECON_TICK_OFFSET
		var past := _pred_pos
		for h in _pred_hist:
			if h[0] >= at:
				past = h[1]
				break
		var err: Vector2 = (_srv_sample[1] as Vector2) - past
		_srv_sample = []
		var el := err.length()
		recon_err_sum += el
		recon_err_n += 1
		recon_err_max = maxf(recon_err_max, el)
		if el > 3.0:
			# errore grande (es. respinto, rallentato): riallineamento immediato
			_pred_pos += err
			_correction = Vector2.ZERO
			_pred_hist.clear()
		elif el > 0.02:
			_correction = err
	if _correction.length() > 0.001:
		# correzione morbida in ~150 ms, applicata anche alla cronologia
		var stepc := _correction * minf(1.0, delta * 7.0)
		_pred_pos += stepc
		_correction -= stepc
		for h in _pred_hist:
			h[1] = (h[1] as Vector2) + stepc


func _client_push_buildings(p: Vector2, r: float, dir: Vector2) -> Vector2:
	for u in units.values():
		if not u.is_building() or (not u.alive and u.kind != Game.Kind.ANCIENT):
			continue
		var d: Vector2 = p - u.pos
		var min_d: float = u.radius + r
		var l := d.length()
		if l < min_d:
			var n := d / l if l > 0.001 else Vector2.RIGHT
			var tangent := Vector2(-n.y, n.x)
			if tangent.dot(dir) < 0.0:
				tangent = -tangent
			p = u.pos + n * min_d + tangent * 0.05
	return p


# ============================================================================
# Eventi (comuni a server e client)
# ============================================================================

func _apply_events(evs: Array) -> void:
	for e in evs:
		if not (e is Array) or e.is_empty():
			continue
		match e[0]:
			"spawn":
				var ts := Time.get_ticks_usec()
				_ev_spawn(e)
				if Game.prof_enabled:
					Game.prof_add("ev_spawn", Time.get_ticks_usec() - ts)
			"despawn": _ev_despawn(int(e[1]))
			"death":
				var td := Time.get_ticks_usec()
				_ev_death(int(e[1]), int(e[2]))
				if Game.prof_enabled:
					Game.prof_add("ev_death", Time.get_ticks_usec() - td)
			"respawn": _ev_respawn(int(e[1]), Vector2(e[2], e[3]))
			"attack": _ev_attack(int(e[1]), int(e[2]))
			"cast": _ev_cast(int(e[1]), int(e[2]))
			"proj": _ev_proj(e)
			"proj_end":
				vfx.end_projectile(int(e[1]))
			"dmg": _ev_dmg(int(e[1]), int(e[2]), int(e[3]), int(e[4]) if e.size() > 4 else 0)
			"gold": _ev_gold(int(e[1]), int(e[2]), Vector2(e[3], e[4]))
			"fx": _ev_fx(str(e[1]), Vector2(e[2], e[3]), int(e[4]))
			"notify": _ev_notify(str(e[1]), int(e[2]))
			"wave":
				if int(e[1]) == 1:
					hud.notify("Prima ondata in arrivo!", Color(1, 0.9, 0.5))
					Audio.play_ui("alert")
			"game_over": _end_game(int(e[1]))


func _ev_spawn(e: Array) -> void:
	var id := int(e[1])
	var u: Unit = units.get(id)
	if u == null:
		if is_server:
			return
		u = Unit.new()
		u.id = id
		u.kind = int(e[2])
		u.team = int(e[3])
		u.subtype = str(e[4])
		u.pos = Vector2(e[5], e[6])
		u.facing = float(e[7])
		u.owner_peer = int(e[8])
		u.max_hp = float(e[9])
		u.hp = u.max_hp
		u.radius = _radius_for(u)
		if u.is_creep():
			u.attack_point = Game.CREEPS[u.kind].attack_point
			u.move_speed = Game.CREEPS[u.kind].move_speed
		elif u.is_hero():
			u.attack_point = Game.HERO.attack_point
			u.move_speed = Game.HERO.move_speed
		units[id] = u
		_buffers[id] = [[_clock - Game.INTERP_DELAY, u.pos, u.facing]]
	if views.has(id):
		return
	var v := _get_view(u)
	views[id] = v
	if u.is_creep() and u.team == Game.Team.DIRE:
		v.play_spawn()
	if u.is_hero() and u.owner_peer == local_peer:
		cam.center_on(u.pos3(), true)


func _radius_for(u: Unit) -> float:
	if u.is_hero():
		return Game.HERO.radius
	if u.is_creep():
		return Game.CREEPS[u.kind].radius
	return Game.BUILDINGS.get(u.subtype, {"radius": 1.0}).radius


func _get_view(u: Unit) -> UnitView:
	var key := UnitView.make_key(u.kind, u.team)
	var v: UnitView = null
	if key != "building" and key != "hero":
		var pool: Array = _view_pool.get(key, [])
		if not pool.is_empty():
			v = pool.pop_back()
	if v == null:
		v = UnitView.new()
		units_root.add_child(v)
	v.setup(u.id, u.kind, u.team, u.subtype, quality)
	v.facing = u.facing
	v.update_visual(0.0, u.pos3(), u.facing, false, 0.0, u.invulnerable, false)
	return v


## Pre-crea i modelli dei creep (istanziare un glTF animato durante la partita causa scatti).
func _prewarm_views() -> void:
	var per_type := 14
	for k in [Game.Kind.CREEP_MELEE, Game.Kind.CREEP_RANGED, Game.Kind.CREEP_SIEGE]:
		for t in [0, 1]:
			var key := UnitView.make_key(k, t)
			var pool: Array = _view_pool.get(key, [])
			var n := per_type if k == Game.Kind.CREEP_MELEE else (6 if k == Game.Kind.CREEP_RANGED else 3)
			for i in n:
				var v := UnitView.new()
				units_root.add_child(v)
				v.setup(0, k, t, "", quality)
				v.position = Vector3(0, -50, 0)
				v.park()
				pool.append(v)
			_view_pool[key] = pool


func _ev_despawn(id: int) -> void:
	var v: UnitView = views.get(id)
	views.erase(id)
	overlay._trail.erase(id)
	if not is_server:
		units.erase(id)
		_buffers.erase(id)
	if v == null:
		return
	if v.model_key != "building" and v.model_key != "hero":
		v.park()
		var pool: Array = _view_pool.get(v.model_key, [])
		pool.append(v)
		_view_pool[v.model_key] = pool
	else:
		v.queue_free()


func _ev_death(id: int, killer: int) -> void:
	var u: Unit = units.get(id)
	if u and not is_server:
		u.alive = false
		u.hp = 0.0
	var v: UnitView = views.get(id)
	if v:
		v.die()
		if u:
			if u.is_creep():
				Audio.play_3d("bones_%d" % randi_range(1, 3) if u.team == Game.Team.DIRE else "death_soft", v.vis_pos, -4.0)
			elif u.kind == Game.Kind.TOWER:
				Audio.play_3d("collapse", v.vis_pos, 2.0)
	if u and u.is_hero():
		if u.owner_peer == local_peer:
			hud.notify("Sei stato ucciso!", Color(1, 0.35, 0.3))
			_pred_has_goal = false
			_pred_target = 0
		elif hero_of_unit(killer) == local_hero_data():
			hud.notify("Hai ucciso l'eroe nemico!", Color(1, 0.85, 0.3))
			Audio.play_ui("alert")


func _ev_respawn(id: int, p: Vector2) -> void:
	var u: Unit = units.get(id)
	if u and not is_server:
		u.alive = true
		u.pos = p
		u.hp = u.max_hp
		_buffers[id] = [[_clock - Game.INTERP_DELAY, p, u.facing]]
	var v: UnitView = views.get(id)
	if v:
		v.revive()
		vfx.effect("respawn", MapData.to3(p), u.team if u else 0)
		Audio.play_3d("respawn", MapData.to3(p))
	if u and u.owner_peer == local_peer:
		_pred_active = false
		cam.center_on(MapData.to3(p), true)
		hud.notify("Il fuoco di Aethra arde in me!", Color(1, 0.7, 0.35))


func _ev_attack(id: int, target: int) -> void:
	var v: UnitView = views.get(id)
	var u: Unit = units.get(id)
	if v == null or u == null:
		return
	if v.building_model == null:
		v.play_attack(u.attack_point)
	var t: Unit = units.get(target)
	if u.is_hero() or (t and t.is_hero()):
		_mark_combat(u, t)
	if u.kind == Game.Kind.CREEP_MELEE and _near_camera(v.vis_pos, 40.0):
		Audio.play_3d("hit_melee_%d" % randi_range(1, 3), v.vis_pos, -10.0)


func _mark_combat(a: Unit, b: Unit) -> void:
	var hd := local_hero_data()
	if hd == null:
		return
	if (a and a.id == hd.unit_id) or (b and b.id == hd.unit_id):
		_last_combat_time = game_time


func _ev_cast(id: int, slot: int) -> void:
	var v: UnitView = views.get(id)
	if v:
		v.play_cast(slot)
	var u: Unit = units.get(id)
	if u and u.owner_peer == local_peer:
		_last_combat_time = game_time
	if v and slot == 0:
		Audio.play_3d("fireball_cast", v.vis_pos)


func _ev_proj(e: Array) -> void:
	var pid := int(e[1])
	var ptype := str(e[2])
	var src: Unit = units.get(int(e[3]))
	var team := src.team if src else 0
	var start := Vector3(e[5], 1.4, e[6])
	if src and src.is_building():
		start.y = 6.5 if src.kind == Game.Kind.TOWER else 3.0
	var dir := Vector3(e[7], 0, e[8])
	vfx.spawn_projectile(pid, ptype, team, start, int(e[4]), dir, float(e[9]), Game.ABILITIES[0].range if ptype == "fireball" else 0.0)
	if _near_camera(start, 45.0):
		match ptype:
			"bolt": Audio.play_3d("bolt_cast_%d" % randi_range(1, 2), start, -4.0)
			"tower", "fountain": Audio.play_3d("tower_shot", start, -6.0)


func _ev_dmg(target: int, amount: int, kind: int, src: int) -> void:
	var v: UnitView = views.get(target)
	if v == null:
		return
	v.flash()
	var hd := local_hero_data()
	var local_id := hd.unit_id if hd else -1
	var col := Color(1, 1, 1)
	if kind == 1:
		col = Color(1.0, 0.6, 0.2)
	if target == local_id:
		col = Color(1.0, 0.3, 0.25)
	# i numeri si mostrano solo per i danni che riguardano l'eroe locale (meno confusione)
	if src == local_id or target == local_id or mode != Game.Mode.TRAINING:
		overlay.add_number(v.vis_pos + Vector3(0, v.height, 0), str(amount), col, 1.0 if kind == 0 else 1.25)
	if src == local_id or target == local_id:
		_last_combat_time = game_time
		Audio.play_3d("bolt_hit_%d" % randi_range(1, 2) if kind == 0 else "explosion_1", v.vis_pos, -6.0)


func _ev_gold(unit_id: int, amount: int, p: Vector2) -> void:
	var hd := local_hero_data()
	if hd == null or hd.unit_id != unit_id:
		return
	overlay.add_number(MapData.to3(p, 2.5), "+%d" % amount, Color(1.0, 0.85, 0.2), 1.3)
	Audio.play_ui("coins" if randf() < 0.5 else "coins_2")
	var wp := MapData.to3(p, 1.5)
	if not cam.camera.is_position_behind(wp):
		hud.fly_coins(cam.camera.unproject_position(wp), clampi(amount / 15, 2, 6))


func _ev_fx(name: String, p: Vector2, src: int) -> void:
	var u: Unit = units.get(src)
	var team := u.team if u else 0
	var p3 := MapData.to3(p)
	match name:
		"meteor_warn":
			vfx.meteor_warning(p3, Game.ABILITIES[3].aoe, Game.ABILITIES[3].delay)
			return
		"blink_in":
			if u and u.owner_peer == local_peer:
				_pred_active = false
				_pred_has_goal = false
			if not is_server and u:
				_buffers[src] = [[_clock - Game.INTERP_DELAY, p, u.facing]]
	vfx.effect(name, p3, team)
	match name:
		"explosion": Audio.play_3d("explosion_%d" % randi_range(1, 2), p3)
		"blink_out": Audio.play_3d("blink", p3)
		"shockwave": Audio.play_3d("shockwave", p3)
		"meteor_hit":
			Audio.play_3d("big_explosion", p3, 3.0)
			_hit_stop(0.06)
		"deny":
			overlay.add_number(p3 + Vector3(0, 2.2, 0), "!", Color(0.6, 0.85, 1.0), 1.6)
		"levelup":
			if u and u.owner_peer == local_peer:
				Audio.play_ui("level_up")
				hud.notify("Livello %d!" % local_hero_data().level, Color(1, 0.85, 0.3))
		"tower_destroyed":
			Audio.play_3d("big_explosion", p3, 2.0)
			_hit_stop(0.08)
		"ancient_destroyed":
			Audio.play_3d("big_explosion", p3, 6.0)
			if mode == Game.Mode.TRAINING:
				_slow_motion()
		"buy": if u and u.owner_peer == local_peer: Audio.play_ui("buy")


func _ev_notify(what: String, team: int) -> void:
	var mine := team == Game.local_team
	match what:
		"tower":
			if mine:
				hud.notify("Una tua torre è stata distrutta!", Color(1, 0.4, 0.3))
			else:
				hud.notify("La %s ha distrutto una torre del %s!" % [Game.TEAM_SHORT[1 - team], Game.TEAM_SHORT[team]], Color(0.5, 1, 0.6))
			Audio.play_ui("alert")
		"hero_kill":
			pass


## Breve "hit-stop" sui colpi più potenti (solo in allenamento: in rete il tempo non si ferma).
func _hit_stop(dur: float) -> void:
	if mode != Game.Mode.TRAINING or Engine.time_scale < Game.base_time_scale * 0.5:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(dur, true, false, true).timeout.connect(func():
		if Engine.time_scale < Game.base_time_scale * 0.5 and not over:
			Engine.time_scale = Game.base_time_scale)


func _slow_motion() -> void:
	Engine.time_scale = 0.3
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Engine.time_scale = Game.base_time_scale)


func _end_game(w: int) -> void:
	if over:
		return
	over = true
	winner = w
	var victory := w == Game.local_team
	Audio.play_music("victory" if victory else "defeat", false)
	await get_tree().create_timer(2.0 if not forfeit else 0.2, true, false, true).timeout
	var hd := local_hero_data()
	var res := {"victory": victory, "forfeit": forfeit, "time": game_time}
	if hd:
		res.merge(hd.to_dict())
	finished.emit(res)


# ============================================================================
# Viste
# ============================================================================

func _update_views(delta: float) -> void:
	var alpha := clampf(_acc / Game.TICK, 0.0, 1.0)
	var render_t := _clock - Game.INTERP_DELAY
	var local_hd := local_hero_data()
	# area visibile approssimata (cerchio attorno al punto inquadrato, cresce con lo zoom)
	var cam_focus := cam.focus
	var view_r := cam.zoom * 1.6 + 8.0
	var view_r2 := view_r * view_r
	var frame := Engine.get_process_frames()
	for id in views:
		var v: UnitView = views[id]
		var u: Unit = units.get(id)
		if u == null:
			continue
		var p: Vector2
		var f: float = u.facing
		if is_server:
			p = u.prev_pos.lerp(u.pos, alpha)
		elif local_hd and id == local_hd.unit_id and _pred_active:
			p = _pred_pos
			var ip: Array = _interp_pos(id, render_t)
			f = ip[1]
			if _pred_has_goal or _pred_target != 0:
				var g := _pred_goal if _pred_target == 0 else u.pos
				if g.distance_to(p) > 0.2:
					f = (g - p).angle()
		else:
			var ip: Array = _interp_pos(id, render_t)
			p = ip[0]
			f = ip[1]
		var moving: bool
		var stunned: bool
		if is_server:
			moving = u.state == Unit.State.MOVING and u.alive
			stunned = u.is_stunned()
		else:
			moving = (u.flags & Unit.F_MOVING) != 0 and u.alive
			stunned = (u.flags & Unit.F_STUNNED) != 0
			if local_hd and id == local_hd.unit_id and _pred_active:
				moving = (v.vis_pos - MapData.to3(p)).length() > 0.01
		var speed := u.current_move_speed() if is_server else (_local_hero_speed() if u.is_hero() else u.move_speed)
		v.update_visual(delta, MapData.to3(p), f, moving, speed, u.invulnerable, stunned)
		if v.anim and v.kind != Game.Kind.HERO:
			var dx := p.x - cam_focus.x
			var dz := p.y - cam_focus.z
			v.tick_anim(delta, dx * dx + dz * dz < view_r2, frame)


func _near_camera(p: Vector3, r: float) -> bool:
	return Vector2(p.x - cam.focus.x, p.z - cam.focus.z).length() < r


# ============================================================================
# Input del giocatore
# ============================================================================

func send_command(cmd: Array) -> void:
	if over:
		return
	if is_server:
		sim.queue_command(local_peer, cmd)
	else:
		_cmd_seq += 1
		_cmd_times[_cmd_seq] = _local_time
		_cmd_times.erase(_cmd_seq - 200)
		Net.send_command(_cmd_seq, cmd)
		_last_cmd_time = _local_time
		# predizione locale
		match cmd[0]:
			"move", "amove":
				_pred_goal = MapData.clamp_walkable(Vector2(cmd[1], cmd[2]), Game.HERO.radius)
				_pred_has_goal = true
				_pred_target = 0
			"attack":
				_pred_target = int(cmd[1])
				_pred_has_goal = false
			"stop":
				_pred_has_goal = false
				_pred_target = 0
			"cast":
				_pred_has_goal = false
				_pred_target = 0


func _mouse_ground() -> Vector3:
	return cam.ground_point(get_viewport().get_mouse_position())


func _update_hover() -> void:
	var prev := hovered_id
	hovered_id = 0
	if not input_enabled or hud.mouse_over_ui():
		_set_hover(prev, 0)
		return
	var gp := _mouse_ground()
	if gp == Vector3.INF:
		_set_hover(prev, 0)
		return
	var p := Vector2(gp.x, gp.z)
	var best := INF
	for id in views:
		var u: Unit = units.get(id)
		if u == null or not u.alive or u.kind == Game.Kind.FOUNTAIN:
			continue
		if u.team == Game.local_team:
			# alleati selezionabili solo per il deny (A + click su un proprio creep sotto il 50%)
			if not (attack_move_mode and Game.ENABLE_DENY and u.is_creep() and u.hp < u.max_hp * 0.5):
				continue
		var v: UnitView = views[id]
		var d := Vector2(v.vis_pos.x, v.vis_pos.z).distance_to(p)
		var pick := u.radius + (0.9 if not u.is_building() else 0.8)
		if d < pick and d < best:
			best = d
			hovered_id = id
	_set_hover(prev, hovered_id)


func _set_hover(prev: int, cur: int) -> void:
	if prev == cur:
		return
	if prev != 0 and views.has(prev):
		(views[prev] as UnitView).set_hover(false)
	if cur != 0 and views.has(cur):
		(views[cur] as UnitView).set_hover(true)
	hud.set_attack_cursor(cur != 0)


func _update_targeting_rings() -> void:
	var u := local_hero_unit()
	var show := targeting_slot >= 0 and u != null
	_range_ring.visible = show
	_aoe_ring.visible = false
	if not show:
		return
	var ab: Dictionary = Game.ABILITIES[targeting_slot]
	var hp := local_hero_pos3()
	var r: float = ab.range if ab.range > 0.0 else ab.get("aoe", 3.0)
	_range_ring.position = hp + Vector3(0, 0.1, 0)
	_range_ring.scale = Vector3(r, 1, r)
	if ab.has("aoe"):
		var gp := _mouse_ground()
		if gp != Vector3.INF:
			_aoe_ring.visible = true
			var c := gp
			if ab.target == "dir":
				var d := Vector3(gp.x - hp.x, 0, gp.z - hp.z)
				c = hp + d.limit_length(ab.range)
			elif ab.target == "none":
				c = hp
			_aoe_ring.position = c + Vector3(0, 0.12, 0)
			_aoe_ring.scale = Vector3(ab.aoe, 1, ab.aoe)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if targeting_slot >= 0 or attack_move_mode:
				_cancel_targeting()
				return
			_drag_timer = 0.12
			_right_click(event.position, true)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var gp := cam.ground_point(event.position)
			if gp == Vector3.INF:
				return
			if targeting_slot >= 0:
				send_command(["cast", targeting_slot, gp.x, gp.z, hovered_id])
				_cancel_targeting()
			elif attack_move_mode:
				if hovered_id != 0:
					send_command(["attack", hovered_id])
				else:
					send_command(["amove", gp.x, gp.z])
				vfx.click_indicator(gp, true)
				_cancel_targeting()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	for i in 4:
		if event.is_action_pressed(["ability_q", "ability_w", "ability_e", "ability_r"][i]):
			if event.ctrl_pressed:
				send_command(["learn", i])
			else:
				try_ability(i)
			get_viewport().set_input_as_handled()
			return
	for i in 6:
		if event.is_action_pressed("item_%d" % (i + 1)):
			send_command(["use", i])
			return
	if event.is_action_pressed("attack_move"):
		_cancel_targeting()
		attack_move_mode = true
		hud.set_attack_cursor(true)
	elif event.is_action_pressed("stop"):
		_cancel_targeting()
		send_command(["stop"])
	elif event.is_action_pressed("shop"):
		hud.toggle_shop()
	elif event.is_action_pressed("pause") or event.is_action_pressed("pause_alt"):
		if targeting_slot >= 0 or attack_move_mode:
			_cancel_targeting()
		else:
			hud.toggle_pause()
	elif event.is_action_pressed("screenshot"):
		take_screenshot("")
	elif event.is_action_pressed("mute_music"):
		Audio.toggle_music_mute()


func _right_click(pos: Vector2, show_indicator: bool) -> void:
	if hud.mouse_over_ui():
		return
	var gp := cam.ground_point(pos)
	if gp == Vector3.INF:
		return
	if hovered_id != 0:
		send_command(["attack", hovered_id])
		if show_indicator:
			vfx.click_indicator((views[hovered_id] as UnitView).vis_pos, true)
	else:
		send_command(["move", gp.x, gp.z])
		if show_indicator:
			vfx.click_indicator(gp, false)
			Audio.play_ui("move_click", -12.0)


func try_ability(i: int) -> void:
	var hd := local_hero_data()
	var u := local_hero_unit()
	if hd == null or u == null or not u.alive:
		return
	var ab: Dictionary = Game.ABILITIES[i]
	var lvl: int = hd.ability_levels[i]
	if lvl <= 0:
		hud.notify("Abilità non ancora appresa (Ctrl+%s)" % ab.key, Color(1, 0.6, 0.4))
		Audio.play_ui("ui_error")
		return
	if hd.cooldowns[i] > 0.0:
		hud.notify("%s in ricarica" % ab.name, Color(1, 0.6, 0.4))
		Audio.play_ui("ui_error")
		return
	if u.mana < ab.mana[lvl - 1]:
		hud.notify("Mana insufficiente", Color(0.5, 0.7, 1.0))
		Audio.play_ui("ui_error")
		return
	var gp := _mouse_ground()
	if ab.target == "none" or Game.settings.quick_cast:
		if gp == Vector3.INF:
			gp = local_hero_pos3()
		send_command(["cast", i, gp.x, gp.z, hovered_id])
		return
	_cancel_targeting()
	targeting_slot = i
	hud.set_attack_cursor(hovered_id != 0)


func _cancel_targeting() -> void:
	targeting_slot = -1
	attack_move_mode = false
	hud.set_attack_cursor(hovered_id != 0)


func _update_music() -> void:
	var fighting := game_time - _last_combat_time < 5.0
	if fighting and _music_state != "battle":
		_music_state = "battle"
		if Game.ENABLE_MUSIC_CROSSFADE:
			Audio.play_music("battle")
	elif not fighting and _music_state == "battle" and game_time - _last_combat_time > 8.0:
		_music_state = "calm"
		if Game.ENABLE_MUSIC_CROSSFADE:
			Audio.play_music("calm")


func take_screenshot(path: String) -> String:
	if path == "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
		path = "res://screenshots/shot_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	return path


func cheat(what: String) -> void:
	if mode != Game.Mode.TRAINING:
		return
	send_command(["cheat", what])


func _exit_tree() -> void:
	Engine.time_scale = Game.base_time_scale
