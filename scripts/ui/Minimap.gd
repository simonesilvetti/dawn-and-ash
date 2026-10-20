class_name Minimap
extends Control
## Minimappa stilizzata: corsia, fiume, basi, unità, rettangolo della telecamera.
## Click sinistro = sposta la telecamera; click destro = muovi l'eroe.

var world: World
var _bg: ImageTexture
const WORLD_HALF := 130.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = _make_background(160)


func _to_map(p: Vector2) -> Vector2:
	return (p / (WORLD_HALF * 2.0) + Vector2(0.5, 0.5)) * size


func _to_world(m: Vector2) -> Vector2:
	return (m / size - Vector2(0.5, 0.5)) * WORLD_HALF * 2.0


func _make_background(res: int) -> ImageTexture:
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	var ld := MapData.lane_dir()
	var rn := MapData.lane_normal()
	for y in res:
		for x in res:
			var p := (Vector2(x + 0.5, y + 0.5) / res - Vector2(0.5, 0.5)) * WORLD_HALF * 2.0
			var along := p.dot(ld)
			var c := Color(0.22, 0.38, 0.16).lerp(Color(0.28, 0.22, 0.2), clampf((along - 10.0) / 50.0, 0.0, 1.0))
			if MapData.is_walkable(p, 0.0):
				c = Color(0.55, 0.45, 0.32)
			for t in 2:
				if p.distance_to(MapData.BASE_CENTER[t]) < Game.BASE_RADIUS - 4.0:
					c = Color(0.62, 0.6, 0.55) if t == 0 else Color(0.32, 0.27, 0.3)
			var rpos := p.dot(rn)
			if absf(along + sin(rpos * 0.045) * 6.0 + sin(rpos * 0.13) * 1.5) < 4.0:
				c = Color(0.2, 0.5, 0.65)
			if maxf(absf(p.x), absf(p.y)) > WORLD_HALF - 8.0:
				c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


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
