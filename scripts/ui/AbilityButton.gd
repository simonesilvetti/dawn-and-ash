class_name AbilityButton
extends Control
## Icona di abilità o oggetto: icona procedurale (IconRect) dentro un alloggiamento di metallo (slot.gdshader:
## cornice smussata, incasso, ricarica a spicchio, riflesso, lampo). Testi e tacche dei livelli, tasto e "+"
## per imparare sono disegnati dal figlio _Over.

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
var _frame: ColorRect
var _over: _Over
static var _slot_shader: Shader
const FRAME_MARGIN := 5.0
var _pulse := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered = true; _redraw())
	mouse_exited.connect(func(): hovered = false; _redraw())
	_icon = IconRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 2
	_icon.offset_top = 2
	_icon.offset_right = -2
	_icon.offset_bottom = -2
	_icon.symbol = symbol
	add_child(_icon)
	if _slot_shader == null:
		_slot_shader = load("res://scripts/ui/slot.gdshader")
	_frame = ColorRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = -FRAME_MARGIN
	_frame.offset_top = -FRAME_MARGIN
	_frame.offset_right = FRAME_MARGIN
	_frame.offset_bottom = FRAME_MARGIN
	var m := ShaderMaterial.new()
	m.shader = _slot_shader
	m.set_shader_parameter("margin", FRAME_MARGIN)
	m.set_shader_parameter("bevel", 2.5 if is_item else 3.5)
	m.set_shader_parameter("radius", 3.0 if is_item else 5.0)
	_frame.material = m
	_frame.resized.connect(func(): m.set_shader_parameter("size", _frame.size))
	add_child(_frame)
	_over = _Over.new()
	_over.btn = self
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	_redraw.call_deferred()


func _redraw() -> void:
	queue_redraw()
	if _over:
		_over.queue_redraw()
	if _frame:
		var m := _frame.material as ShaderMaterial
		var learned := level > 0 or is_item
		m.set_shader_parameter("cooldown", clampf(cooldown / cooldown_max, 0.0, 1.0) if cooldown > 0.0 else 0.0)
		m.set_shader_parameter("hovered", 1.0 if hovered else 0.0)
		m.set_shader_parameter("learned", 1.0 if learned else 0.0)
		m.set_shader_parameter("no_mana", 1.0 if (no_mana and learned and not is_item) else 0.0)
		m.set_shader_parameter("flash", clampf(_ready_flash / 0.5, 0.0, 1.0))
		m.set_shader_parameter("can_learn", 1.0 if can_learn else 0.0)
		m.set_shader_parameter("empty", 1.0 if (is_item and symbol == "") else 0.0)


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
	# fondo scuro dietro l'icona (la cornice è nello shader dell'alloggiamento)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.02))


class _Over extends Control:
	var btn: AbilityButton

	func _draw() -> void:
		var b := btn
		var sz := size
		var learned := b.level > 0 or b.is_item
		var f := b.font
		if b.is_item and b.symbol == "":
			# casella vuota: numero del tasto inciso
			draw_string(f, Vector2(0, sz.y * 0.5 + 6), b.key_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 15, Color(1, 1, 1, 0.13))
			return
		if b.cooldown > 0.0:
			var txt := str(ceili(b.cooldown)) if b.cooldown >= 1.0 else "%.1f" % b.cooldown
			var fs := 24 if not b.is_item else 17
			draw_string_outline(f, Vector2(0, sz.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, 6, Color(0, 0, 0, 0.9))
			draw_string(f, Vector2(0, sz.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, Color(1, 0.97, 0.9))
		var gold := Color(1.0, 0.84, 0.45) if learned else Color(0.6, 0.6, 0.62)
		# tasto: targhetta scura con filo dorato nell'angolo in alto a sinistra
		if b.key_text != "":
			var ks := 16.0 if not b.is_item else 13.0
			var kr := Rect2(-1, -1, ks, ks)
			draw_rect(kr, Color(0.03, 0.025, 0.03, 0.92))
			draw_line(kr.position + Vector2(0, kr.size.y), kr.end, gold.darkened(0.25), 1.0)
			draw_line(Vector2(kr.end.x, kr.position.y), kr.end, gold.darkened(0.25), 1.0)
			draw_string(f, Vector2(kr.position.x, kr.end.y - 3), b.key_text, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 13 if not b.is_item else 10, Color(1, 0.95, 0.85))
		if b.is_item:
			return
		# costo in mana: gemma blu in basso a destra
		if b.mana_cost > 0 and learned:
			var mc := str(b.mana_cost)
			var w := 7.0 * mc.length() + 8.0
			var mr := Rect2(sz.x - w + 1, sz.y - 15, w, 16)
			var pts := PackedVector2Array([mr.position + Vector2(4, 0), Vector2(mr.end.x, mr.position.y), mr.end, Vector2(mr.position.x, mr.end.y)])
			draw_colored_polygon(pts, Color(0.04, 0.09, 0.28, 0.94))
			draw_polyline(PackedVector2Array([pts[3], pts[0], pts[1]]), Color(0.45, 0.65, 1.0, 0.8), 1.0)
			draw_string(f, Vector2(mr.position.x + 2, mr.end.y - 3), mc, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x - 2, 12, Color(0.78, 0.9, 1.0) if not b.no_mana else Color(1.0, 0.55, 0.5))
		# tacche del livello: barrette smussate sotto l'alloggiamento (accese = oro, spente = incassate)
		var gapx := 3.0
		var bw := (sz.x - gapx * (b.max_level - 1)) / b.max_level
		for i in b.max_level:
			var r := Rect2(i * (bw + gapx), sz.y + 7.0, bw, 5.0)
			if i < b.level:
				draw_rect(r, Color(0.55, 0.36, 0.1))
				draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(1.0, 0.9, 0.55))
				draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 1.5)), Color(1.0, 0.76, 0.3))
			else:
				draw_rect(r, Color(0.05, 0.04, 0.04))
				draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1.0)), Color(0.32, 0.26, 0.18))
			draw_rect(r.grow(0.5), Color(0, 0, 0, 0.75), false, 1.0)
		# "+" per imparare, con una leggera pulsazione
		if b.can_learn:
			var pc := Vector2(sz.x * 0.5, -14)
			var pr := 9.0 + sin(b._pulse * 6.0) * 1.2
			draw_circle(pc, pr + 2.5, Color(0, 0, 0, 0.7))
			draw_circle(pc, pr, Color(0.2, 0.55, 0.16))
			draw_circle(pc - Vector2(0, pr * 0.35), pr * 0.6, Color(0.45, 0.85, 0.35, 0.5))
			draw_arc(pc, pr, 0, TAU, 24, UiKit.GOLD_BRIGHT, 1.5, true)
			draw_line(pc - Vector2(4.5, 0), pc + Vector2(4.5, 0), Color.WHITE, 2.5)
			draw_line(pc - Vector2(0, 4.5), pc + Vector2(0, 4.5), Color.WHITE, 2.5)

	func _process(_d: float) -> void:
		if btn.can_learn:
			queue_redraw()
