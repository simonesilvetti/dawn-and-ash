class_name Overlay
extends Control
## Barre della vita e numeri fluttuanti, disegnati tutti in un'unica _draw() (molto più veloce di un nodo per unità).

var world: World
var numbers: Array = []          # {pos: Vector3, text, color, t, scale, drift}
var _trail: Dictionary = {}      # id -> frazione di vita "in ritardo" (scia della barra)
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func add_number(p: Vector3, text: String, c: Color, s: float = 1.0) -> void:
	if numbers.size() > 60:
		numbers.pop_front()
	numbers.append({"pos": p, "text": text, "color": c, "t": 0.0, "scale": s, "drift": randf_range(-0.6, 0.6)})


func _process(delta: float) -> void:
	var i := 0
	while i < numbers.size():
		var n: Dictionary = numbers[i]
		n.t += delta
		if n.t > 1.1:
			numbers.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	if world == null or world.cam == null:
		return
	var _pt := Time.get_ticks_usec()
	var cam := world.cam.camera
	var rect := get_viewport_rect()
	var zf := clampf(32.0 / world.cam.zoom, 0.7, 1.4)
	var local_hd := world.local_hero_data()
	var dt := get_process_delta_time()
	for id in world.views:
		var v: UnitView = world.views[id]
		var u: Unit = world.units.get(id)
		if u == null or v.dead or not u.alive or v.bar_width <= 0.0:
			continue
		var wp := v.vis_pos + Vector3(0, v.height, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		if sp.x < -100 or sp.y < -50 or sp.x > rect.size.x + 100 or sp.y > rect.size.y + 50:
			continue
		var w := v.bar_width * zf
		var h := (7.0 if u.is_hero() else (6.0 if u.is_building() else 4.0)) * zf
		var frac := clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0)
		var tr: float = _trail.get(id, frac)
		tr = frac if frac > tr else move_toward(tr, frac, dt * 0.6)
		_trail[id] = tr
		var ally := u.team == Game.local_team
		var col := Color(0.35, 0.85, 0.25) if ally else Color(0.9, 0.22, 0.18)
		if local_hd and id == local_hd.unit_id:
			col = Color(0.3, 0.95, 0.35)
		var pos := sp - Vector2(w * 0.5, 0)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(pos, Vector2(w * tr, h)), Color(1.0, 0.85, 0.55, 0.9))
		draw_rect(Rect2(pos, Vector2(w * frac, h)), col)
		if u.is_hero() or u.is_building():
			# tacche ogni 250 punti vita (come in Dota)
			var step := 250.0 if u.is_hero() else 500.0
			var k := step
			while k < u.max_hp:
				var x := pos.x + w * (k / u.max_hp)
				draw_line(Vector2(x, pos.y), Vector2(x, pos.y + h), Color(0, 0, 0, 0.5), 1.0)
				k += step
		if u.is_hero():
			var mfrac := clampf(u.mana / maxf(1.0, u.max_mana), 0.0, 1.0)
			var mpos := pos + Vector2(0, h + 2)
			draw_rect(Rect2(mpos - Vector2(1, 1), Vector2(w + 2, 4 * zf + 2)), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(mpos, Vector2(w * mfrac, 4 * zf)), Color(0.3, 0.55, 1.0))
			var hd := world.hero_of_unit(id)
			if hd:
				var lv := str(hd.level)
				var lp := pos + Vector2(-20 * zf, h + 1)
				draw_circle(lp + Vector2(8 * zf, -3 * zf), 9 * zf, Color(0.1, 0.08, 0.12, 0.9))
				draw_string(font, lp + Vector2(8 * zf - 4 * zf * lv.length(), 1 * zf), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * zf), Color(1, 0.85, 0.4))
				draw_string_outline(font, pos + Vector2(0, -6 * zf), hd.player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * zf), 3, Color(0, 0, 0, 0.8))
				draw_string(font, pos + Vector2(0, -6 * zf), hd.player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * zf), Color(1, 1, 1, 0.95) if ally else Color(1, 0.6, 0.55))
		if u.invulnerable and u.is_building():
			draw_string_outline(font, pos + Vector2(w * 0.5 - 36, -6), "INVULNERABILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
			draw_string(font, pos + Vector2(w * 0.5 - 36, -6), "INVULNERABILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.85, 1.0))
	# Numeri fluttuanti
	for n in numbers:
		var wp: Vector3 = n.pos + Vector3(n.drift * n.t, n.t * 2.2, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var k: float = n.t / 1.1
		var a := 1.0 - k * k
		var sz := int(18.0 * n.scale * zf * (1.0 + 0.3 * maxf(0.0, 0.15 - n.t) / 0.15))
		var c: Color = n.color
		c.a = a
		var txt: String = n.text
		var off := Vector2(-sz * 0.28 * txt.length(), 0)
		draw_string_outline(font, sp + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, a * 0.85))
		draw_string(font, sp + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
	if Game.prof_enabled:
		Game.prof_add("overlay", Time.get_ticks_usec() - _pt)
