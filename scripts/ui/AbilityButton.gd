class_name AbilityButton
extends Control
## Icona di abilità o oggetto: icona procedurale (IconRect), ricarica a spicchio, costo in mana, tacche dei livelli,
## tasto e pulsante "+" per imparare. Le parti sopra l'icona sono disegnate dal figlio _Over.

signal activated(index: int)
signal learn_pressed(index: int)

var index: int = 0
var is_item := false
var symbol := "":
	set(v):
		symbol = v
		if _icon:
			_icon.symbol = v
var key_text := ""
var level: int = 0
var max_level: int = 4
var cooldown: float = 0.0
var cooldown_max: float = 1.0
var no_mana := false
var can_learn := false
var mana_cost: int = 0
var _ready_flash: float = 0.0
var _was_on_cd := false
var font: Font
var hovered := false
var _icon: IconRect
var _over: _Over
var _pulse := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered = true; _redraw())
	mouse_exited.connect(func(): hovered = false; _redraw())
	_icon = IconRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 3
	_icon.offset_top = 3
	_icon.offset_right = -3
	_icon.offset_bottom = -3
	_icon.symbol = symbol
	add_child(_icon)
	_over = _Over.new()
	_over.btn = self
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)


func _redraw() -> void:
	queue_redraw()
	if _over:
		_over.queue_redraw()


func set_state(lvl: int, cd: float, cd_max: float, nomana: bool, learnable: bool, cost: int) -> void:
	var on_cd := cd > 0.0
	if _was_on_cd and not on_cd:
		_ready_flash = 0.5          # lampeggia quando l'abilità torna disponibile
	_was_on_cd = on_cd
	var changed := lvl != level or absf(cd - cooldown) > 0.01 or nomana != no_mana or learnable != can_learn or cost != mana_cost
	level = lvl
	cooldown = cd
	cooldown_max = maxf(cd_max, 0.01)
	no_mana = nomana
	can_learn = learnable
	mana_cost = cost
	if _icon:
		_icon.dim = 0.0 if (level > 0 or is_item) else 0.75
	if changed or can_learn:
		_redraw()


## Aggiorna l'oggetto mostrato in una casella dell'inventario.
func set_item(id: String) -> void:
	if id == symbol:
		return
	symbol = id
	level = 1 if id != "" else 0
	_redraw()


func _process(delta: float) -> void:
	if _ready_flash > 0.0:
		_ready_flash -= delta
		_redraw()
	if can_learn:
		_pulse += delta


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_learn and event.position.y < 0:
			learn_pressed.emit(index)
		else:
			activated.emit(index)
		accept_event()


func _has_point(point: Vector2) -> bool:
	# include la zona del "+" sopra l'icona
	return Rect2(Vector2(0, -24 if can_learn else 0), size + Vector2(0, 24 if can_learn else 0)).has_point(point)


func _draw() -> void:
	# cornice incassata dietro l'icona
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.02, 0.015, 0.02))
	draw_rect(r.grow(-1), Color(0.18, 0.14, 0.1), false, 1.0)


class _Over extends Control:
	var btn: AbilityButton

	func _draw() -> void:
		var b := btn
		var sz := size
		var r := Rect2(Vector2.ZERO, sz)
		var inner := r.grow(-3)
		var learned := b.level > 0 or b.is_item
		var f := b.font
		if b.is_item and b.symbol == "":
			# casella vuota: numero del tasto in trasparenza
			draw_rect(inner, Color(0.06, 0.05, 0.06))
			draw_string(f, Vector2(0, sz.y * 0.5 + 6), b.key_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 15, Color(1, 1, 1, 0.12))
			draw_rect(r, Color(0.32, 0.26, 0.18), false, 1.5)
			return
		if b.no_mana and learned and not b.is_item:
			draw_rect(inner, Color(0.1, 0.25, 0.8, 0.35))
		if b.cooldown > 0.0:
			var frac := clampf(b.cooldown / b.cooldown_max, 0.0, 1.0)
			var c := sz * 0.5
			var pts := PackedVector2Array([c])
			var steps := 28
			for i in steps + 1:
				var a := -PI * 0.5 + TAU * frac * float(i) / steps
				pts.append(c + Vector2(cos(a), sin(a)) * sz.x)
			var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)])
			for poly in Geometry2D.intersect_polygons(pts, box):
				draw_colored_polygon(poly, Color(0, 0, 0, 0.62))
			var txt := str(ceili(b.cooldown))
			draw_string_outline(f, Vector2(0, sz.y * 0.5 + 9), txt, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 26, 5, Color.BLACK)
			draw_string(f, Vector2(0, sz.y * 0.5 + 9), txt, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 26, Color.WHITE)
		if b._ready_flash > 0.0:
			draw_rect(inner, Color(1, 0.9, 0.6, b._ready_flash * 0.8))
		# cornice: dorata, più chiara al passaggio del mouse, grigia se non imparata
		var border := UiKit.GOLD_BRIGHT if b.hovered else UiKit.GOLD
		if not learned:
			border = Color(0.38, 0.34, 0.3)
		draw_rect(r, border, false, 2.0)
		draw_rect(r.grow(-2), Color(0, 0, 0, 0.6), false, 1.0)
		if b.hovered:
			draw_rect(r.grow(2), Color(1.0, 0.85, 0.45, 0.35), false, 2.0)
		# tasto in alto a sinistra
		if b.key_text != "":
			var kr := Rect2(1, 1, 17 if not b.is_item else 14, 17 if not b.is_item else 14)
			draw_rect(kr, Color(0.02, 0.02, 0.03, 0.85))
			draw_rect(kr, border.darkened(0.2), false, 1.0)
			draw_string(f, Vector2(kr.position.x, kr.end.y - 3), b.key_text, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 14 if not b.is_item else 11, Color(1, 0.95, 0.85))
		if b.is_item:
			return
		# costo in mana in basso a destra
		if b.mana_cost > 0 and learned:
			var mc := str(b.mana_cost)
			var w := 8.0 * mc.length() + 6.0
			var mr := Rect2(sz.x - w - 2, sz.y - 17, w, 15)
			draw_rect(mr, Color(0.05, 0.12, 0.35, 0.9))
			draw_string(f, Vector2(mr.position.x, mr.end.y - 3), mc, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 12, Color(0.75, 0.88, 1.0))
		# tacche del livello (rombi) sotto l'icona
		var step := sz.x / b.max_level
		for i in b.max_level:
			var cx := step * (i + 0.5)
			var cy := sz.y + 8.0
			var d := PackedVector2Array([Vector2(cx, cy - 5), Vector2(cx + 6, cy), Vector2(cx, cy + 5), Vector2(cx - 6, cy)])
			draw_colored_polygon(d, Color(1.0, 0.82, 0.35) if i < b.level else Color(0.2, 0.18, 0.16))
			draw_polyline(d + PackedVector2Array([d[0]]), Color(0, 0, 0, 0.8), 1.0)
		# "+" per imparare, con una leggera pulsazione
		if b.can_learn:
			var pc := Vector2(sz.x * 0.5, -12)
			var pr := 9.0 + sin(b._pulse * 6.0) * 1.2
			draw_circle(pc, pr + 2, Color(0, 0, 0, 0.7))
			draw_circle(pc, pr, Color(0.25, 0.65, 0.2))
			draw_arc(pc, pr, 0, TAU, 20, UiKit.GOLD_BRIGHT, 1.5)
			draw_line(pc - Vector2(4.5, 0), pc + Vector2(4.5, 0), Color.WHITE, 2.5)
			draw_line(pc - Vector2(0, 4.5), pc + Vector2(0, 4.5), Color.WHITE, 2.5)

	func _process(_d: float) -> void:
		if btn.can_learn:
			queue_redraw()
