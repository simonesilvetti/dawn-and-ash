class_name AbilityButton
extends Control
## Icona di abilità o oggetto con ricarica a spicchio, costo, livello e tasto.

signal activated(index: int)
signal learn_pressed(index: int)

var index: int = 0
var is_item := false
var symbol := ""
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


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())


func set_state(lvl: int, cd: float, cd_max: float, nomana: bool, learnable: bool, cost: int) -> void:
	var on_cd := cd > 0.0
	if _was_on_cd and not on_cd:
		_ready_flash = 0.5          # lampeggia quando l'abilità torna disponibile
	_was_on_cd = on_cd
	level = lvl
	cooldown = cd
	cooldown_max = maxf(cd_max, 0.01)
	no_mana = nomana
	can_learn = learnable
	mana_cost = cost
	queue_redraw()


func _process(delta: float) -> void:
	if _ready_flash > 0.0:
		_ready_flash -= delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_learn and event.position.y < 0:
			learn_pressed.emit(index)
		else:
			activated.emit(index)
		accept_event()


func _has_point(point: Vector2) -> bool:
	# include la zona del "+" sopra l'icona
	return Rect2(Vector2(0, -22 if can_learn else 0), size + Vector2(0, 22 if can_learn else 0)).has_point(point)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var learned := level > 0 or is_item
	var bg := Color(0.12, 0.09, 0.08) if learned else Color(0.08, 0.08, 0.09)
	draw_rect(r, bg)
	if symbol != "":
		var col := Color(1.0, 0.5, 0.15)
		if not learned:
			col = Color(0.35, 0.33, 0.32)
		UiKit.draw_symbol(self, symbol, size * 0.5, size.x * 0.5, col)
	if not learned:
		draw_rect(r, Color(0, 0, 0, 0.45))
	if no_mana and learned and not is_item:
		draw_rect(r, Color(0.1, 0.2, 0.6, 0.45))
	if cooldown > 0.0:
		var frac := clampf(cooldown / cooldown_max, 0.0, 1.0)
		var pts := PackedVector2Array([size * 0.5])
		var steps := 24
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * frac * float(i) / steps
			pts.append(size * 0.5 + Vector2(cos(a), sin(a)) * size.x)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
		draw_rect(r, Color(0, 0, 0, 0.0))
		var txt := str(ceili(cooldown))
		draw_string_outline(font, Vector2(size.x * 0.5 - 6 * txt.length(), size.y * 0.5 + 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color.BLACK)
		draw_string(font, Vector2(size.x * 0.5 - 6 * txt.length(), size.y * 0.5 + 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if _ready_flash > 0.0:
		draw_rect(r, Color(1, 0.9, 0.6, _ready_flash * 0.8))
	var border := UiKit.GOLD_BRIGHT if hovered else UiKit.GOLD
	if not learned:
		border = Color(0.35, 0.32, 0.3)
	draw_rect(r, border, false, 2.0)
	if key_text != "":
		draw_rect(Rect2(2, 2, 16, 16), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(5, 15), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
	if not is_item:
		# pallini del livello
		var w := size.x / max_level
		for i in max_level:
			var c := Color(1.0, 0.8, 0.3) if i < level else Color(0.25, 0.22, 0.2)
			draw_rect(Rect2(i * w + 3, size.y + 3, w - 6, 4), c)
		if mana_cost > 0 and learned:
			var mc := str(mana_cost)
			draw_string_outline(font, Vector2(size.x - 8 * mc.length() - 2, size.y - 4), mc, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
			draw_string(font, Vector2(size.x - 8 * mc.length() - 2, size.y - 4), mc, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.75, 1.0))
		if can_learn:
			var pr := Rect2(size.x * 0.5 - 10, -20, 20, 18)
			draw_rect(pr, Color(0.2, 0.5, 0.15, 0.95))
			draw_rect(pr, UiKit.GOLD_BRIGHT, false, 1.5)
			draw_string(font, Vector2(size.x * 0.5 - 5, -6), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
