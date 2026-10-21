extends Node
## Radice dell'applicazione: menu principale <-> partita, flusso di rete, test automatici.

var menu: MainMenu
var menu_bg: Node3D
var world: World
var end_screen: EndScreen
## Nodo che contiene menu e partita (nei test di screenshot/benchmark è un SubViewport a dimensione fissa).
var host_node: Node = self


func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	Net.game_start.connect(_on_net_game_start)
	Net.host_lost.connect(_on_host_lost)
	if Game.has_arg("--sim-smoke"):
		_sim_smoke()
		return
	if AutoTest.wants_autotest():
		var at := AutoTest.new()
		at.main = self
		add_child(at)
		return
	show_menu()


# --- Menu ---------------------------------------------------------------------------

func show_menu(status: String = "") -> void:
	_clear()
	Game.mode = Game.Mode.NONE
	menu_bg = Node3D.new()
	menu_bg.name = "MenuBackground"
	host_node.add_child(menu_bg)
	MapBuilder.build(menu_bg, mini(int(Game.settings.quality), 1))
	# edifici delle due basi per dare vita allo sfondo
	for t in [0, 1]:
		var subs := {"t1": MapData.T1, "t2": MapData.T2, "ancient": MapData.ANCIENT, "fountain": MapData.FOUNTAIN}
		for sub in subs:
			var v := UnitView.new()
			menu_bg.add_child(v)
			var k := Game.Kind.TOWER
			if sub == "ancient": k = Game.Kind.ANCIENT
			elif sub == "fountain": k = Game.Kind.FOUNTAIN
			v.setup(0, k, t, sub, 1)
			v.position = MapData.to3(subs[sub][t])
	var cam := CameraRig.new()
	cam.orbit = true
	menu_bg.add_child(cam)
	var layer := CanvasLayer.new()
	menu_bg.add_child(layer)
	menu = MainMenu.new()
	layer.add_child(menu)
	menu.start_training.connect(start_training)
	menu.quit_game.connect(func(): Game.quit())
	if status != "":
		menu.set_status(status)


func _clear() -> void:
	get_tree().paused = false
	Engine.time_scale = Game.base_time_scale
	if end_screen:
		end_screen.queue_free()
		end_screen = null
	if world:
		Net.world = null
		world.queue_free()
		world = null
	if menu_bg:
		menu_bg.queue_free()
		menu_bg = null
		menu = null
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null)


# --- Partita ----------------------------------------------------------------------------

func start_training() -> World:
	_clear()
	Game.mode = Game.Mode.TRAINING
	Game.cheats.invulnerable = false
	return _start_world(Game.Mode.TRAINING, 1)


func _start_world(m: int, peer: int) -> World:
	world = World.new()
	world.name = "World"
	world.setup(m, peer)
	host_node.add_child(world)
	world.finished.connect(_on_finished)
	world.leave_requested.connect(_leave_game)
	Net.world = world
	return world


func _on_net_game_start() -> void:
	_clear()
	if Net.is_host:
		Game.mode = Game.Mode.HOST
		_start_world(Game.Mode.HOST, 1)
	else:
		Game.mode = Game.Mode.CLIENT
		_start_world(Game.Mode.CLIENT, multiplayer.get_unique_id())
		await get_tree().process_frame
		Net.client_loaded()


func _on_host_lost(reason: String) -> void:
	if world:
		show_menu(reason)


func _on_finished(result: Dictionary) -> void:
	if end_screen:
		return
	end_screen = EndScreen.new()
	end_screen.result = result
	var layer := CanvasLayer.new()
	layer.layer = 5
	world.add_child(layer)
	layer.add_child(end_screen)
	end_screen.replay.connect(func(): start_training())
	end_screen.to_menu.connect(_leave_game)


func _leave_game() -> void:
	if Game.mode == Game.Mode.HOST or Game.mode == Game.Mode.CLIENT:
		Net.leave()
	show_menu()


func _exit_tree() -> void:
	# libera le cache statiche (materiali, mesh, tema): niente risorse "ancora in uso" all'uscita
	_clear()
	VfxLib._cache.clear()
	MapBuilder._mesh_cache.clear()
	MapBuilder._foliage_mats.clear()
	MapBuilder._noise = null
	MapBuilder._shader_cache.clear()
	Terrain._mesh = null
	Terrain._noise = null
	UnitView._ring_mats.clear()
	UnitView._tint_cache.clear()
	UnitView._anim_configured.clear()
	UnitView._flash_mat = null
	UnitView._ring_mesh = null
	UiKit._theme = null
	UiPanel._white = null
	UiPanel._shader = null
	IconRect._shader = null
	Minimap._bg_cache = null
	Scenery._meshes.clear()
	Scenery._grass_mat = null
	Scenery._bush_mat = null


# --- Test rapido della simulazione (senza grafica) ---------------------------------------

func _sim_smoke() -> void:
	var sim := Sim.new(true)
	var hd := sim.add_hero(1, Game.Team.RADIANT, "Test")
	var t0 := Time.get_ticks_msec()
	var max_us := 0
	for i in 30 * 240:
		if i == 30 * 10:
			sim.queue_command(1, ["amove", 0.0, 0.0])
		sim.tick()
		sim.events.clear()
		max_us = maxi(max_us, sim.last_tick_usec)
		if i % (30 * 30) == 0:
			var u := sim.hero_unit(1)
			print("t=%.0f units=%d hero=%s hp=%.0f gold=%d lvl=%d xp=%d lh=%d proj=%d tick_us=%d" % [sim.time, sim.unit_list.size(), u.pos, u.hp, hd.gold, hd.level, hd.xp, hd.last_hits, sim.projectiles.size(), sim.last_tick_usec])
	print("ms totali: ", Time.get_ticks_msec() - t0, " tick max us: ", max_us)
	print("snapshot full bytes=", sim.build_snapshot(true).size(), " delta=", sim.build_snapshot(false).size())
	get_tree().quit()
