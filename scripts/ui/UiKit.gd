class_name UiKit
extends RefCounted
## Stili condivisi dell'interfaccia: pannelli scuri semitrasparenti con bordi dorati.

const GOLD := Color(0.85, 0.68, 0.32)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.45)
const PANEL_BG := Color(0.07, 0.06, 0.09, 0.86)
const TEXT := Color(0.93, 0.9, 0.84)
const TEXT_DIM := Color(0.65, 0.62, 0.58)

static var _theme: Theme


static func panel_style(bg: Color = PANEL_BG, border: Color = GOLD, radius: int = 10, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var btn := panel_style(Color(0.16, 0.12, 0.10, 0.95), GOLD, 8, 2)
	btn.content_margin_left = 18
	btn.content_margin_right = 18
	var hover := panel_style(Color(0.30, 0.20, 0.12, 0.98), GOLD_BRIGHT, 8, 2)
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	var pressed := panel_style(Color(0.45, 0.28, 0.12, 1.0), GOLD_BRIGHT, 8, 2)
	pressed.content_margin_left = 18
	pressed.content_margin_right = 18
	var disabled := panel_style(Color(0.12, 0.11, 0.12, 0.8), Color(0.4, 0.35, 0.3), 8, 2)
	disabled.content_margin_left = 18
	disabled.content_margin_right = 18
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Label", TEXT)
	var le := panel_style(Color(0.04, 0.035, 0.05, 0.95), Color(0.5, 0.42, 0.3), 6, 1)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", panel_style(Color(0.04, 0.035, 0.05, 0.95), GOLD_BRIGHT, 6, 1))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("slider", "HSlider", panel_style(Color(0.2, 0.18, 0.16), Color(0.4, 0.35, 0.3), 3, 1))
	var grab := panel_style(GOLD, GOLD_BRIGHT, 3, 1)
	grab.content_margin_top = 2
	grab.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	t.set_stylebox("panel", "TooltipPanel", panel_style(Color(0.05, 0.04, 0.06, 0.95), GOLD, 6, 1))
	_theme = t
	return t


static func label(text: String, size: int = 16, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4 if size >= 20 else 3)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(func():
		Audio.play_ui("ui_click")
		cb.call())
	b.mouse_entered.connect(func(): Audio.play_ui("ui_hover", -14.0))
	return b


## Simboli procedurali per abilità e oggetti (niente texture esterne).
static func draw_symbol(c: CanvasItem, kind: String, center: Vector2, r: float, col: Color) -> void:
	match kind:
		"fireball":
			c.draw_circle(center + Vector2(r * 0.15, r * 0.15), r * 0.42, col)
			c.draw_circle(center + Vector2(r * 0.15, r * 0.15), r * 0.24, Color(1, 0.95, 0.7))
			for i in 3:
				var o := Vector2(-r * (0.35 + i * 0.2), -r * (0.35 + i * 0.2))
				c.draw_circle(center + o, r * (0.2 - i * 0.05), Color(col, 0.8 - i * 0.2))
		"blink":
			for i in 3:
				c.draw_arc(center, r * (0.25 + i * 0.22), i * 1.3, i * 1.3 + 4.2, 16, Color(col, 1.0 - i * 0.25), r * 0.12)
			c.draw_circle(center, r * 0.14, Color(1, 0.95, 0.8))
		"shockwave":
			c.draw_circle(center, r * 0.18, Color(1, 0.9, 0.7))
			c.draw_arc(center, r * 0.42, 0, TAU, 24, Color(0.45, 0.75, 1.0), r * 0.12)
			c.draw_arc(center, r * 0.72, 0, TAU, 24, Color(col, 0.8), r * 0.08)
		"meteor":
			c.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.05, r * 0.05), Color(col, 0.6), r * 0.3)
			c.draw_circle(center + Vector2(r * 0.15, r * 0.15), r * 0.36, col)
			c.draw_circle(center + Vector2(r * 0.15, r * 0.15), r * 0.18, Color(1, 0.95, 0.7))
		"sword":
			c.draw_line(center + Vector2(-r * 0.55, r * 0.55), center + Vector2(r * 0.55, -r * 0.55), Color(0.85, 0.88, 0.95), r * 0.18)
			c.draw_line(center + Vector2(-r * 0.5, r * 0.15), center + Vector2(-r * 0.15, r * 0.5), GOLD, r * 0.16)
		"armor":
			var pts := PackedVector2Array([center + Vector2(-r * 0.5, -r * 0.5), center + Vector2(r * 0.5, -r * 0.5),
				center + Vector2(r * 0.45, r * 0.1), center + Vector2(0, r * 0.6), center + Vector2(-r * 0.45, r * 0.1)])
			c.draw_colored_polygon(pts, Color(0.6, 0.42, 0.25))
			c.draw_polyline(pts + PackedVector2Array([pts[0]]), GOLD, 2.0)
		"boots":
			c.draw_rect(Rect2(center + Vector2(-r * 0.3, -r * 0.6), Vector2(r * 0.4, r * 0.9)), Color(0.55, 0.35, 0.2))
			c.draw_rect(Rect2(center + Vector2(-r * 0.3, r * 0.15), Vector2(r * 0.85, r * 0.35)), Color(0.55, 0.35, 0.2))
			c.draw_line(center + Vector2(-r * 0.6, -r * 0.2), center + Vector2(-r * 0.35, -r * 0.2), Color(0.6, 0.9, 1.0), 2.0)
		"vitality":
			var pts := PackedVector2Array([center + Vector2(0, -r * 0.6), center + Vector2(r * 0.45, 0), center + Vector2(0, r * 0.6), center + Vector2(-r * 0.45, 0)])
			c.draw_colored_polygon(pts, Color(0.95, 0.3, 0.35))
			c.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], center]), Color(1, 0.6, 0.6))
		"potion", "mana_potion":
			var pc := Color(0.95, 0.25, 0.3) if kind == "potion" else Color(0.3, 0.5, 1.0)
			c.draw_circle(center + Vector2(0, r * 0.15), r * 0.42, pc)
			c.draw_rect(Rect2(center + Vector2(-r * 0.13, -r * 0.6), Vector2(r * 0.26, r * 0.4)), Color(0.8, 0.85, 0.9))
		"crystal":
			var pts := PackedVector2Array([center + Vector2(0, -r * 0.65), center + Vector2(r * 0.35, 0), center + Vector2(0, r * 0.65), center + Vector2(-r * 0.35, 0)])
			c.draw_colored_polygon(pts, Color(0.4, 0.6, 1.0))
		"ring":
			c.draw_arc(center, r * 0.4, 0, TAU, 20, GOLD, r * 0.14)
			c.draw_circle(center + Vector2(0, -r * 0.4), r * 0.14, Color(0.4, 1.0, 0.5))
		"vampire":
			c.draw_line(center + Vector2(-r * 0.55, r * 0.55), center + Vector2(r * 0.55, -r * 0.55), Color(0.75, 0.1, 0.15), r * 0.2)
			c.draw_circle(center + Vector2(-r * 0.4, r * 0.4), r * 0.15, Color(0.3, 0.05, 0.08))
