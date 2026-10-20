class_name CameraRig
extends Node3D
## Telecamera in stile Dota: prospettica inclinata, scorrimento ai bordi/frecce, zoom, blocco sull'eroe.

const PITCH_DEFAULT := deg_to_rad(50.0)
const ZOOM_MIN := 16.0
const ZOOM_MAX := 42.0
const EDGE := 10
const LIMIT := 105.0

var camera: Camera3D
var focus := Vector3.ZERO
var target_focus := Vector3.ZERO
var zoom := 28.0
var target_zoom := 28.0
var locked := false
var follow_target: Callable           # restituisce la posizione dell'eroe
var vfx: Vfx
var orbit := false                    # menu principale: orbita lenta
var _orbit_angle := 0.0
var input_enabled := true
var pitch: float = PITCH_DEFAULT


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.5
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	_apply()


func center_on(p: Vector3, instant: bool = false) -> void:
	target_focus = Vector3(clampf(p.x, -LIMIT, LIMIT), 0.0, clampf(p.z, -LIMIT, LIMIT))
	if instant:
		focus = target_focus


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or orbit:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - 2.5, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + 2.5, ZOOM_MIN, ZOOM_MAX)
	elif event.is_action_pressed("lock_camera"):
		locked = not locked


func _process(delta: float) -> void:
	if orbit:
		_orbit_angle += delta * 0.05
		focus = Vector3(cos(_orbit_angle) * 20.0, 0, sin(_orbit_angle) * 20.0)
		zoom = 75.0
		var off := Vector3(sin(_orbit_angle * 2.0), 0, cos(_orbit_angle * 2.0)) * 60.0
		camera.position = focus + off + Vector3(0, 45, 0)
		camera.look_at(focus, Vector3.UP)
		return
	if input_enabled:
		var move := Vector2.ZERO
		if Input.is_action_pressed("cam_left"): move.x -= 1
		if Input.is_action_pressed("cam_right"): move.x += 1
		if Input.is_action_pressed("cam_up"): move.y -= 1
		if Input.is_action_pressed("cam_down"): move.y += 1
		var vp := get_viewport()
		if Game.settings.edge_scroll and vp and DisplayServer.window_is_focused():
			var mp := vp.get_mouse_position()
			var size := vp.get_visible_rect().size
			if mp.x >= 0 and mp.y >= 0 and mp.x <= size.x and mp.y <= size.y:
				if mp.x < EDGE: move.x -= 1
				elif mp.x > size.x - EDGE: move.x += 1
				if mp.y < EDGE: move.y -= 1
				elif mp.y > size.y - EDGE: move.y += 1
		if move != Vector2.ZERO:
			locked = false
			var speed := 45.0 * float(Game.settings.scroll_speed) * (zoom / 32.0)
			target_focus += Vector3(move.x, 0, move.y).normalized() * speed * delta
			target_focus.x = clampf(target_focus.x, -LIMIT, LIMIT)
			target_focus.z = clampf(target_focus.z, -LIMIT, LIMIT)
		if (locked or Input.is_action_pressed("center_hero")) and follow_target.is_valid():
			center_on(follow_target.call())
	focus = focus.lerp(target_focus, minf(1.0, delta * 10.0))
	zoom = lerpf(zoom, target_zoom, minf(1.0, delta * 8.0))
	_apply()


func _apply() -> void:
	if camera == null:
		return
	var off := Vector3(0, sin(pitch) * zoom, cos(pitch) * zoom)
	var sh := Vector3.ZERO
	if vfx and vfx.shake > 0.0:
		var s := vfx.shake * vfx.shake * 0.8
		var t := Time.get_ticks_msec() * 0.05
		sh = Vector3(sin(t * 1.7), sin(t * 2.3) * 0.5, cos(t * 1.9)) * s
	camera.position = focus + off + sh
	camera.rotation = Vector3(-pitch, 0, 0)


## Punto del terreno (y=0) sotto una posizione dello schermo.
func ground_point(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t
