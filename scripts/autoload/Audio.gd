extends Node
## Audio: bus separati (Musica, Effetti, UI), musica con crossfade, pool di player 2D/3D,
## variazione di pitch e limite di suoni uguali contemporanei.

const SOUNDS := "res://assets/sounds/"
const MUSIC := "res://assets/music/"
const POOL_3D := 20
const POOL_2D := 8
const MAX_SAME := 3

var _streams: Dictionary = {}
var _p3: Array[AudioStreamPlayer3D] = []
var _p2: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_name := ""
var _music_muted := false
var _fade_tw: Tween
var started_count: int = 0        # per i test automatici
var failed_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 12.0
		p.max_distance = 80.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_p3.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_p2.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	Game.settings_changed.connect(apply_volumes)
	apply_volumes()


func apply_volumes() -> void:
	_set_bus("Master", Game.settings.vol_master)
	_set_bus("Music", 0.0 if _music_muted else Game.settings.vol_music)
	_set_bus("SFX", Game.settings.vol_sfx)
	_set_bus("UI", Game.settings.vol_ui)


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


func toggle_music_mute() -> void:
	_music_muted = not _music_muted
	apply_volumes()


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		failed_count += 1
	_streams[path] = s
	return s


func _count_playing(arr: Array, s: AudioStream) -> int:
	var n := 0
	for p in arr:
		if p.playing and p.stream == s:
			n += 1
	return n


func play_3d(name: String, pos: Vector3, vol_db: float = 0.0) -> void:
	var s := _stream(SOUNDS + name + ".ogg")
	if s == null or _count_playing(_p3, s) >= MAX_SAME:
		return
	var player: AudioStreamPlayer3D = null
	for p in _p3:
		if not p.playing:
			player = p
			break
	if player == null:
		return
	player.stream = s
	player.global_position = pos
	player.volume_db = vol_db
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()
	started_count += 1


func play_ui(name: String, vol_db: float = 0.0) -> void:
	var s := _stream(SOUNDS + name + ".ogg")
	if s == null or _count_playing(_p2, s) >= MAX_SAME:
		return
	for p in _p2:
		if not p.playing:
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = randf_range(0.96, 1.04)
			p.play()
			started_count += 1
			return


## Avvia un brano con crossfade. loop=false per i jingle di vittoria/sconfitta.
func play_music(name: String, loop: bool = true, fade: float = 1.5) -> void:
	if name == _music_name:
		return
	var s := _stream(MUSIC + name + ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_music_name = name
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var cur := _music[_music_idx]
	cur.stream = s
	cur.volume_db = -40.0
	cur.play()
	started_count += 1
	if _fade_tw:
		_fade_tw.kill()
	_fade_tw = create_tween().set_parallel(true)
	_fade_tw.tween_property(cur, "volume_db", 0.0, fade)
	_fade_tw.tween_property(old, "volume_db", -60.0, fade)
	_fade_tw.chain().tween_callback(old.stop)


func stop_music() -> void:
	_music_name = ""
	for m in _music:
		m.stop()


func _exit_tree() -> void:
	shutdown()


## Ferma e rilascia tutto: nessun flusso audio "ancora in uso" all'uscita.
func shutdown() -> void:
	_music_name = ""
	if _fade_tw:
		_fade_tw.kill()
	for p in _music + _p2:
		p.stop()
		p.stream = null
	for p in _p3:
		p.stop()
		p.stream = null
	_streams.clear()
