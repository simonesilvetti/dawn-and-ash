class_name Minimap
extends Control
## Minimappa stilizzata: corsia, fiume, basi, unità, rettangolo della telecamera.
## Click sinistro = sposta la telecamera; click destro = muovi l'eroe.

var world: World
var _bg: ImageTexture
static var _bg_cache: ImageTexture
const WORLD_HALF := 130.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = _make_background(216)


func _to_map(p: Vector2) -> Vector2:
	return (p / (WORLD_HALF * 2.0) + Vector2(0.5, 0.5)) * size


func _to_world(m: Vector2) -> Vector2:
	return (m / size - Vector2(0.5, 0.5)) * WORLD_HALF * 2.0


## Sfondo dipinto a partire dal terreno vero (Terrain): colori delle zone, rilievo ombreggiato, boschi, fiume, mura.
static func _make_background(res: int) -> ImageTexture:
	if _bg_cache:
		return _bg_cache
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	var ld := MapData.lane_dir()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	var px := WORLD_HALF * 2.0 / res
	for y in res:
		for x in res:
			var p := (Vector2(x + 0.5, y + 0.5) / res - Vector2(0.5, 0.5)) * WORLD_HALF * 2.0
			var along := p.dot(ld)
			var ash := clampf((along - 10.0) / 50.0, 0.0, 1.0)
			var c := Color(0.25, 0.42, 0.17).lerp(Color(0.3, 0.23, 0.2), ash)
			var out := Terrain.walk_out(p)
			# boschi: macchie più scure fuori dall'area percorribile
			if out > 5.0 and not Scenery.in_village(p) and fn.get_noise_2dv(p) > -0.25:
				c = c.darkened(0.35 + fn.get_noise_2dv(p * 2.0) * 0.1)
			if MapData.is_walkable(p, 0.0):
				c = Color(0.62, 0.5, 0.34).lerp(Color(0.42, 0.33, 0.3), ash * 0.6)
			for t in 2:
				var bd := p.distance_to(MapData.BASE_CENTER[t])
				if bd < Game.BASE_RADIUS - 4.0:
					c = Color(0.7, 0.68, 0.6) if t == 0 else Color(0.36, 0.3, 0.34)
				if absf(bd - (Game.BASE_RADIUS + 2.5)) < 1.2 and out > 0.0:
					c = Color(0.35, 0.33, 0.3) if t == 0 else Color(0.2, 0.17, 0.19)
			var rd := Terrain.river_dist(p)
			if rd < Terrain.RIVER_W:
				c = Color(0.16, 0.45, 0.6).lerp(Color(0.3, 0.62, 0.7), 1.0 - rd / Terrain.RIVER_W)
			elif rd < Terrain.RIVER_W + 1.5:
				c = c.lerp(Color(0.55, 0.52, 0.45), 0.5)
			# rilievo ombreggiato (luce da nord-ovest)
			var h := Terrain.height(p)
			var hx := Terrain.height(p + Vector2(px, 0))
			var hy := Terrain.height(p + Vector2(0, px))
			var shade := clampf(1.0 + ((h - hx) + (h - hy)) * 0.45, 0.65, 1.3)
			c = Color(c.r * shade, c.g * shade, c.b * shade)
			if maxf(absf(p.x), absf(p.y)) > WORLD_HALF - 8.0:
				c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	_bg_cache = ImageTexture.create_from_image(img)
	return _bg_cache


var _redraw_t := 0.0

func _process(delta: float) -> void:
	# 10 aggiornamenti al secondo bastano per la minimappa
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.1
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if world == null:
		return
	var move_cam := false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			move_cam = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var wp := _to_world(event.position)
			world.send_command(["move", wp.x, wp.y])
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		move_cam = true
	if move_cam:
		var wp := _to_world(event.position)
		world.cam.locked = false
		world.cam.center_on(Vector3(wp.x, 0, wp.y), true)
		accept_event()


func _draw() -> void:
	draw_texture_rect(_bg, Rect2(Vector2.ZERO, size), false)
	var _pt := Time.get_ticks_usec()
	if world == null:
		return
	var local_hd := world.local_hero_data()
	for id in world.views:
		var v: UnitView = world.views[id]
		var u: Unit = world.units.get(id)
		if u == null or (not u.alive and not u.is_building()):
			continue
		var mp := _to_map(Vector2(v.vis_pos.x, v.vis_pos.z))
		var ally := u.team == Game.local_team
		var c := Color(0.3, 0.95, 0.4) if ally else Color(1.0, 0.25, 0.2)
		if u.is_building():
			if not u.alive:
				c = Color(0.3, 0.3, 0.3)
			var s := 5.0 if u.kind == Game.Kind.TOWER else 8.0
			if u.kind == Game.Kind.FOUNTAIN:
				continue
			draw_rect(Rect2(mp - Vector2(s, s) * 0.5, Vector2(s, s)), c)
			draw_rect(Rect2(mp - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0, 0, 0, 0.7), false, 1.0)
		elif u.is_hero():
			var me: bool = local_hd != null and id == local_hd.unit_id
			draw_circle(mp, 5.5, Color(0, 0, 0, 0.8))
			draw_circle(mp, 4.5, Color(1.0, 0.85, 0.3) if me else c)
		else:
			draw_circle(mp, 1.8, c)
	# rettangolo della telecamera
	var cam := world.cam
	var vs := get_viewport().get_visible_rect().size
	var corners := [Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]
	var pts := PackedVector2Array()
	for c in corners:
		var gp := cam.ground_point(c)
		if gp == Vector3.INF:
			return
		pts.append(_to_map(Vector2(gp.x, gp.z)))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.85), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.GOLD, false, 2.0)
	if Game.prof_enabled:
		Game.prof_add("minimap", Time.get_ticks_usec() - _pt)
