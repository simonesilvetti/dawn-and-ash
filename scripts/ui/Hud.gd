class_name Hud
extends Control
## Interfaccia in partita in stile Dota: pannello inferiore (ritratto, barre, abilità, oggetti),
## minimappa, orologio e punteggio, notifiche, negozio, menu di pausa, tabella punteggio, rinascita.

var world: World
var _ui_blockers: Array[Control] = []

var _portrait_level: Label
var _portrait_name: Label
var _xp_bar: ProgressBar
var _hp_bar: ProgressBar
var _hp_text: Label
var _mana_bar: ProgressBar
var _mana_text: Label
var _abilities: Array[AbilityButton] = []
var _items: Array[AbilityButton] = []
var _gold_label: Label
var _stat_labels: Dictionary = {}
var _portrait: _Portrait3D
var _portrait_over: _PortraitOver
var _clock_label: Label
var _score_label: Label
var _wave_label: Label
var _net_label: Label
var _notify_box: VBoxContainer
var _tooltip: PanelContainer
var _tooltip_label: RichTextLabel
var _shop: PanelContainer
var _shop_hint: Label
var _shop_buttons: Dictionary = {}
var _shop_gold: Label
var _pause: PanelContainer
var _score: PanelContainer
var _score_text: RichTextLabel
var _death_overlay: ColorRect
var _death_label: Label
var _countdown_label: Label
var _minimap: Minimap
var _fps_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_death_overlay()
	_build_bottom_panel()
	_build_top_bar()
	_build_minimap()
	_build_notifications()
	_build_shop()
	_build_pause()
	_build_scoreboard()
	_build_tooltip()
	_countdown_label = UiKit.label("", 96, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.position = Vector2(-150, -120)
	_countdown_label.size = Vector2(300, 140)
	add_child(_countdown_label)


func mouse_over_ui() -> bool:
	var mp := get_viewport().get_mouse_position()
	for c in _ui_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(mp):
			return true
	return false


static var _cursor_sword: ImageTexture
static var _cursor_aim: ImageTexture
var _cursor_state := ""


func set_attack_cursor(on: bool) -> void:
	var targeting := world != null and (world.targeting_slot >= 0 or world.attack_move_mode)
	var state := "aim" if (targeting and not on) else ("sword" if on else "normal")
	if state == _cursor_state:
		return
	_cursor_state = state
	if DisplayServer.get_name() == "headless":
		return
	if _cursor_sword == null:
		_cursor_sword = _make_cursor(true)
		_cursor_aim = _make_cursor(false)
	match state:
		"sword": Input.set_custom_mouse_cursor(_cursor_sword, Input.CURSOR_ARROW, Vector2(2, 2))
		"aim": Input.set_custom_mouse_cursor(_cursor_aim, Input.CURSOR_ARROW, Vector2(16, 16))
		_: Input.set_custom_mouse_cursor(null)


## Cursori disegnati via codice: spada rossa (attacco) e mirino arancio (mira delle abilità).
static func _make_cursor(sword: bool) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if sword:
		for i in range(2, 24):
			for w in range(-2, 3):
				var c := Color(0.95, 0.2, 0.15) if absi(w) < 2 else Color(0.25, 0.02, 0.02)
				if i < 4: c = Color(1, 0.6, 0.55)
				img.set_pixel(clampi(i + w, 0, 31), clampi(i - w, 0, 31), c)
		for k in range(-5, 6):
			for t in 2:
				img.set_pixel(clampi(22 + k + t, 0, 31), clampi(22 - k + t, 0, 31), Color(0.85, 0.68, 0.3))
		for i in range(24, 30):
			img.set_pixel(i, i, Color(0.4, 0.25, 0.12))
			img.set_pixel(i, i + 1 if i < 31 else i, Color(0.3, 0.18, 0.08))
	else:
		var c := Vector2(16, 16)
		for y in 32:
			for x in 32:
				var d := Vector2(x, y).distance_to(c)
				if absf(d - 11.0) < 1.2:
					img.set_pixel(x, y, Color(1.0, 0.6, 0.2))
				elif (absi(x - 16) < 1 or absi(y - 16) < 1) and d > 4.0 and d < 15.0:
					img.set_pixel(x, y, Color(1.0, 0.85, 0.5))
		img.set_pixel(16, 16, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


# --- Costruzione -------------------------------------------------------------

func _bar(col: Color, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.03, 0.95)
	bg.set_corner_radius_all(3)
	bg.border_color = Color(0.3, 0.24, 0.15)
	bg.set_border_width_all(1)
	var fg := StyleBoxTexture.new()
	fg.texture = _bar_texture(col)
	fg.texture_margin_left = 2
	fg.texture_margin_right = 2
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Riempimento delle barre con un gradiente verticale (riflesso in alto, ombra in basso).
static func _bar_texture(col: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	g.colors = PackedColorArray([col.lightened(0.45), col.lightened(0.1), col, col.darkened(0.45)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 32
	return t


func _build_bottom_panel() -> void:
	var panel := UiPanel.new(10)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -372
	panel.offset_right = 372
	panel.offset_top = -152
	panel.offset_bottom = -6
	add_child(panel)
	_ui_blockers.append(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# Ritratto 3D del vero modello dell'eroe, con livello e barra dell'esperienza
	var portrait := VBoxContainer.new()
	portrait.add_theme_constant_override("separation", 3)
	row.add_child(portrait)
	var pwrap := Control.new()
	pwrap.custom_minimum_size = Vector2(104, 98)
	pwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(pwrap)
	_portrait = _Portrait3D.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pwrap.add_child(_portrait)
	_portrait_over = _PortraitOver.new()
	_portrait_over.hud = self
	_portrait_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pwrap.add_child(_portrait_over)
	_xp_bar = _bar(Color(0.68, 0.45, 0.95), 7)
	portrait.add_child(_xp_bar)
	_portrait_name = UiKit.label("Kael", 12, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	portrait.add_child(_portrait_name)

	# Abilità + barre
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(296, 0)
	center.add_theme_constant_override("separation", 4)
	row.add_child(center)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer)
	var abil := HBoxContainer.new()
	abil.alignment = BoxContainer.ALIGNMENT_CENTER
	abil.add_theme_constant_override("separation", 12)
	center.add_child(abil)
	for i in 4:
		var ab: Dictionary = Game.ABILITIES[i]
		var b := AbilityButton.new()
		b.index = i
		b.symbol = ab.id
		b.key_text = ab.key
		b.max_level = ab.max_level
		b.custom_minimum_size = Vector2(62, 62)
		b.activated.connect(func(idx): world.try_ability(idx))
		b.learn_pressed.connect(func(idx): world.send_command(["learn", idx]))
		b.mouse_entered.connect(func(): _show_ability_tooltip(i, b))
		b.mouse_exited.connect(func(): _tooltip.visible = false)
		abil.add_child(b)
		_abilities.append(b)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 14)
	center.add_child(spacer2)
	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, 19)
	center.add_child(hp_wrap)
	_hp_bar = _bar(Color(0.22, 0.72, 0.22), 19)
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_wrap.add_child(_hp_bar)
	_hp_text = UiKit.label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_wrap.add_child(_hp_text)
	var mana_wrap := Control.new()
	mana_wrap.custom_minimum_size = Vector2(0, 15)
	center.add_child(mana_wrap)
	_mana_bar = _bar(Color(0.22, 0.42, 0.95), 15)
	_mana_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	mana_wrap.add_child(_mana_bar)
	_mana_text = UiKit.label("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_mana_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mana_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_wrap.add_child(_mana_text)

	# Oggetti + oro
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	row.add_child(right)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	right.add_child(grid)
	for i in 6:
		var b := AbilityButton.new()
		b.index = i
		b.is_item = true
		b.key_text = str(i + 1)
		b.custom_minimum_size = Vector2(50, 38)
		b.activated.connect(func(idx): _item_clicked(idx))
		b.mouse_entered.connect(func(): _show_item_tooltip(i, b))
		b.mouse_exited.connect(func(): _tooltip.visible = false)
		grid.add_child(b)
		_items.append(b)
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 6)
	right.add_child(gold_row)
	var coin := _StatIcon.new()
	coin.kind = "gold"
	coin.custom_minimum_size = Vector2(18, 22)
	gold_row.add_child(coin)
	_gold_label = UiKit.label("0", 19, Color(1.0, 0.84, 0.25))
	gold_row.add_child(_gold_label)

	# Statistiche con icone
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 2)
	stats.custom_minimum_size = Vector2(92, 0)
	row.add_child(stats)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	stats.add_child(sp)
	for k in ["damage", "armor", "speed"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		stats.add_child(h)
		var ic := _StatIcon.new()
		ic.kind = k
		ic.custom_minimum_size = Vector2(18, 22)
		h.add_child(ic)
		var l := UiKit.label("", 15, UiKit.TEXT)
		h.add_child(l)
		_stat_labels[k] = l
	var lvl := UiKit.label("", 13, UiKit.TEXT_DIM)
	stats.add_child(lvl)
	_portrait_level = lvl


## Piccole icone delle statistiche e dell'oro.
class _StatIcon extends Control:
	var kind := ""
	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"damage":
				draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), Color(0.85, 0.88, 0.95), 3.0)
				draw_line(c + Vector2(-6, 1), c + Vector2(-1, 6), UiKit.GOLD, 2.5)
			"armor":
				var pts := PackedVector2Array([c + Vector2(-6, -6), c + Vector2(6, -6), c + Vector2(5, 2), c + Vector2(0, 8), c + Vector2(-5, 2)])
				draw_colored_polygon(pts, Color(0.55, 0.4, 0.25))
				draw_polyline(pts + PackedVector2Array([pts[0]]), UiKit.GOLD, 1.5)
			"speed":
				draw_rect(Rect2(c + Vector2(-4, -7), Vector2(5, 10)), Color(0.6, 0.4, 0.22))
				draw_rect(Rect2(c + Vector2(-4, 2), Vector2(10, 5)), Color(0.6, 0.4, 0.22))
				draw_line(c + Vector2(-9, -3), c + Vector2(-5, -3), Color(0.6, 0.9, 1.0), 1.5)
				draw_line(c + Vector2(-9, 1), c + Vector2(-5, 1), Color(0.6, 0.9, 1.0), 1.5)
			"gold":
				draw_circle(c, 8, Color(0.55, 0.38, 0.05))
				draw_circle(c, 6.5, Color(1.0, 0.82, 0.25))
				draw_circle(c - Vector2(2, 2), 2.2, Color(1, 0.97, 0.75))


## Ritratto: il modello vero dell'eroe (UnitView) in un piccolo mondo 3D separato, con l'animazione di riposo.
class _Portrait3D extends SubViewportContainer:
	var _vp: SubViewport
	var _view: UnitView
	var _frame := 0

	func _ready() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = false
		_vp.msaa_3d = Viewport.MSAA_2X
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.16, 0.09, 0.07) if Game.local_team == 0 else Color(0.11, 0.06, 0.14)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.7, 0.8)
		env.ambient_light_energy = 0.6
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new()
		we.environment = env
		_vp.add_child(we)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-30, -35, 0)
		key.light_energy = 1.3
		key.light_color = Color(1.0, 0.92, 0.82)
		_vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-10, 150, 0)
		rim.light_energy = 1.4
		rim.light_color = Game.TEAM_COLORS[Game.local_team].lightened(0.3)
		_vp.add_child(rim)
		_view = UnitView.new()
		_vp.add_child(_view)
		_view.setup(0, Game.Kind.HERO, Game.local_team, "", 1)
		if _view.ring:
			_view.ring.visible = false
		_view.rotation.y = 0.45
		var cam := Camera3D.new()
		cam.fov = 30.0
		cam.position = Vector3(0.0, 1.55, 3.1)
		_vp.add_child(cam)
		cam.look_at(Vector3(0.0, 1.2, 0.0))

	func _process(_d: float) -> void:
		# basta aggiornarlo a 30 Hz
		_frame += 1
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE if _frame % 2 == 0 else SubViewport.UPDATE_DISABLED


## Cornice, vignettatura e distintivo del livello sopra il ritratto.
class _PortraitOver extends Control:
	var hud: Hud
	var level := 1
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# vignettatura sui bordi
		for i in 6:
			draw_rect(r.grow(-i * 2.0), Color(0, 0, 0, 0.12), false, 2.0)
		var u := hud.world.local_hero_unit() if hud.world else null
		if u and not u.alive:
			draw_rect(r, Color(0.05, 0.03, 0.03, 0.65))
		draw_rect(r, UiKit.GOLD, false, 2.0)
		# distintivo del livello in basso a destra
		var c := Vector2(size.x - 13, size.y - 13)
		draw_circle(c, 13, Color(0, 0, 0, 0.75))
		draw_circle(c, 11, Color(0.18, 0.12, 0.08))
		draw_arc(c, 11, 0, TAU, 24, UiKit.GOLD_BRIGHT, 2.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(c.x - 13, c.y + 6), str(level), HORIZONTAL_ALIGNMENT_CENTER, 26, 16, Color(1, 0.92, 0.7))


func _build_top_bar() -> void:
	var panel := UiPanel.new(10)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -170
	panel.offset_right = 170
	panel.offset_top = 6
	panel.offset_bottom = 74
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	var l_r := UiKit.label("Alba", 14, Game.TEAM_COLORS[0])
	h.add_child(l_r)
	_score_label = UiKit.label("0  ", 22, UiKit.TEXT)
	h.add_child(_score_label)
	_clock_label = UiKit.label("00:00", 24, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	h.add_child(_clock_label)
	var l_d := UiKit.label("Cenere", 14, Game.TEAM_COLORS[1])
	h.add_child(l_d)
	h.move_child(l_d, 3)
	_wave_label = UiKit.label("", 13, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_wave_label)
	_net_label = UiKit.label("", 13, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_net_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_net_label.offset_left = -260
	_net_label.offset_right = -12
	_net_label.offset_top = 8
	_net_label.offset_bottom = 30
	add_child(_net_label)
	var menu_btn := UiKit.button("Menu", func(): toggle_pause(), 0)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.position = Vector2(12, 8)
	menu_btn.custom_minimum_size = Vector2(90, 36)
	add_child(menu_btn)
	_ui_blockers.append(menu_btn)


func _build_minimap() -> void:
	var frame := UiPanel.new(10, false, 8.0)
	frame.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	frame.offset_left = 8
	frame.offset_right = 8 + 236
	frame.offset_top = -242
	frame.offset_bottom = -6
	add_child(frame)
	_ui_blockers.append(frame)
	_minimap = Minimap.new()
	_minimap.world = world
	_minimap.custom_minimum_size = Vector2(216, 216)
	frame.add_child(_minimap)


func _build_notifications() -> void:
	_notify_box = VBoxContainer.new()
	_notify_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notify_box.offset_left = -400
	_notify_box.offset_right = 400
	_notify_box.offset_top = 120
	_notify_box.offset_bottom = 300
	_notify_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notify_box)


## Monete che volano dal punto del last hit al contatore dell'oro.
func fly_coins(from: Vector2, count: int) -> void:
	if _gold_label == null:
		return
	var to := _gold_label.get_global_rect().position + Vector2(10, 12)
	for i in count:
		var c := _Coin.new()
		c.position = from + Vector2(randf_range(-14, 14), randf_range(-10, 10))
		c.size = Vector2(14, 14)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		var mid := c.position.lerp(to, 0.5) + Vector2(randf_range(-80, 80), -120)
		var tw := c.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_method(func(k: float):
			var a := c.position.lerp(mid, k)
			c.position = a.lerp(mid.lerp(to, k), k), 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)


class _Coin extends Control:
	func _draw() -> void:
		draw_circle(size * 0.5, 7, Color(0.55, 0.38, 0.05))
		draw_circle(size * 0.5, 5.5, Color(1.0, 0.82, 0.25))
		draw_circle(size * 0.5 - Vector2(1.5, 1.5), 2, Color(1, 0.97, 0.75))


func notify(text: String, col: Color = UiKit.TEXT) -> void:
	if _notify_box == null:
		return
	var l := UiKit.label(text, 24, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.modulate.a = 0.0
	_notify_box.add_child(l)
	while _notify_box.get_child_count() > 4:
		_notify_box.get_child(0).queue_free()
		_notify_box.remove_child(_notify_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _build_death_overlay() -> void:
	_death_overlay = ColorRect.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.color = Color(0.15, 0.15, 0.18, 0.45)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.visible = false
	add_child(_death_overlay)
	_death_label = UiKit.label("", 34, Color(1, 0.85, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.offset_left = -300
	_death_label.offset_right = 300
	_death_label.offset_top = -160
	_death_label.offset_bottom = -100
	_death_overlay.add_child(_death_label)


func _build_tooltip() -> void:
	_tooltip = UiPanel.new(10, false, 6.0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip.z_index = 10
	add_child(_tooltip)
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(320, 0)
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.scroll_active = false
	_tooltip.add_child(_tooltip_label)


func _place_tooltip(anchor: Control) -> void:
	_tooltip.visible = true
	_tooltip.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(anchor):
		return
	var r := anchor.get_global_rect()
	_tooltip.position = Vector2(clampf(r.position.x + r.size.x * 0.5 - _tooltip.size.x * 0.5, 8, get_viewport_rect().size.x - _tooltip.size.x - 8), r.position.y - _tooltip.size.y - 30)


func _show_ability_tooltip(i: int, anchor: Control) -> void:
	var ab: Dictionary = Game.ABILITIES[i]
	var hd := world.local_hero_data()
	var lvl: int = hd.ability_levels[i] if hd else 0
	var t := "[b][color=#ffd27a]%s (%s)[/color][/b]\n%s\n" % [ab.name, ab.key, ab.desc]
	var dmg: Array = ab.damage
	if dmg[0] > 0.0:
		t += "\n[color=#ffb070]Danno:[/color] %s" % " / ".join(dmg.map(func(d): return str(int(d))))
	t += "\n[color=#80a8ff]Mana:[/color] %s" % " / ".join((ab.mana as Array).map(func(d): return str(int(d))))
	t += "\n[color=#cccccc]Ricarica:[/color] %s s" % " / ".join((ab.cooldown as Array).map(func(d): return str(int(d))))
	if ab.range > 0.0:
		t += "\n[color=#cccccc]Gittata:[/color] %d" % int(ab.range)
	if i == 3 and not Game.ENABLE_ULTIMATE:
		t += "\n\n[color=#ff8080]Disponibile in un prossimo aggiornamento[/color]"
	elif lvl == 0:
		t += "\n\n[color=#a0ffa0]Impara con Ctrl+%s o con il pulsante +[/color]" % ab.key
	_tooltip_label.text = t
	_place_tooltip(anchor)


func _show_item_tooltip(i: int, anchor: Control) -> void:
	var hd := world.local_hero_data()
	if hd == null or hd.items[i] == "":
		return
	var d: Dictionary = Game.ITEMS[hd.items[i]]
	_tooltip_label.text = "[b][color=#ffd27a]%s[/color][/b]\n%s\n\n[color=#cccccc]Vendita: %d oro (vicino alla fontana, click destro)[/color]" % [d.name, d.desc, d.cost / 2]
	_place_tooltip(anchor)


func _item_clicked(i: int) -> void:
	world.send_command(["use", i])


# --- Negozio ------------------------------------------------------------------

func _build_shop() -> void:
	_shop = UiPanel.new(14)
	_shop.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_shop.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_shop.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# sopra il pannello dei comandi, senza sovrapporsi
	_shop.offset_left = -404
	_shop.offset_right = -10
	_shop.offset_bottom = -164
	_shop.offset_top = -164 - 650
	_shop.visible = false
	add_child(_shop)
	_ui_blockers.append(_shop)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_shop.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiKit.label("Negozio", 24, UiKit.GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var coin := _StatIcon.new()
	coin.kind = "gold"
	coin.custom_minimum_size = Vector2(18, 30)
	head.add_child(coin)
	_shop_gold = UiKit.label("0", 18, Color(1.0, 0.84, 0.25))
	_shop_gold.custom_minimum_size = Vector2(60, 0)
	head.add_child(_shop_gold)
	var close := UiKit.button("✕", func(): toggle_shop(), 0)
	close.custom_minimum_size = Vector2(36, 32)
	head.add_child(close)
	_shop_hint = UiKit.label("", 13, Color(1, 0.6, 0.5))
	v.add_child(_shop_hint)
	var groups := [["Consumabili", ["potion", "mana_potion"]], ["Attributi", ["armor", "boots", "vitality", "crystal", "ring"]], ["Armi", ["sword", "vampire"]]]
	for g in groups:
		var ids: Array = (g[1] as Array).filter(func(id): return Game.ITEMS.has(id) and (not Game.ITEMS[id].get("phase2", false) or Game.ENABLE_PHASE2_ITEMS))
		if ids.is_empty():
			continue
		var gh := UiKit.label(g[0], 13, UiKit.GOLD)
		v.add_child(gh)
		for id in ids:
			var card := _ShopCard.new(id)
			card.pressed.connect(func(): world.send_command(["buy", id]))
			v.add_child(card)
			_shop_buttons[id] = card
	v.add_child(UiKit.label("Click per comprare · click destro su un oggetto\ndell'inventario per venderlo (50%).", 12, UiKit.TEXT_DIM))


## Scheda di un oggetto del negozio: icona, nome, descrizione, prezzo (rosso se non basta l'oro).
class _ShopCard extends Button:
	var id := ""
	var _cost: Label
	var _icon: IconRect
	func _init(item_id: String) -> void:
		id = item_id
		var d: Dictionary = Game.ITEMS[id]
		custom_minimum_size = Vector2(0, 50)
		tooltip_text = "%s — %s" % [d.name, d.desc]
		var n := UiKit.panel_style(Color(0.09, 0.07, 0.08, 0.92), Color(0.36, 0.28, 0.18), 6, 1)
		var hv := UiKit.panel_style(Color(0.2, 0.14, 0.09, 0.95), UiKit.GOLD_BRIGHT, 6, 1)
		var ds := UiKit.panel_style(Color(0.07, 0.06, 0.07, 0.8), Color(0.25, 0.22, 0.2), 6, 1)
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", hv)
		add_theme_stylebox_override("disabled", ds)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 6
		h.offset_right = -8
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_icon = IconRect.new()
		_icon.symbol = id
		_icon.custom_minimum_size = Vector2(40, 40)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(_icon)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tv)
		tv.add_child(UiKit.label(d.name, 15, UiKit.TEXT))
		var desc := UiKit.label(d.desc, 12, UiKit.TEXT_DIM)
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		desc.clip_text = true
		desc.custom_minimum_size = Vector2(230, 0)
		tv.add_child(desc)
		_cost = UiKit.label(str(d.cost), 16, Color(1.0, 0.84, 0.25), HORIZONTAL_ALIGNMENT_RIGHT)
		_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_cost.custom_minimum_size = Vector2(46, 0)
		h.add_child(_cost)

	func refresh(can_afford: bool, can_buy: bool) -> void:
		disabled = not can_buy
		_cost.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25) if can_afford else Color(1.0, 0.35, 0.3))
		_icon.dim = 0.0 if can_buy else 0.5
		modulate.a = 1.0 if can_buy else 0.75


func toggle_shop() -> void:
	_shop.visible = not _shop.visible
	Audio.play_ui("ui_open" if _shop.visible else "ui_close")


# --- Pausa ---------------------------------------------------------------------

func _build_pause() -> void:
	_pause = UiPanel.new(18)
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	_pause.offset_left = -200
	_pause.offset_right = 200
	_pause.offset_top = -250
	_pause.offset_bottom = 250
	_pause.visible = false
	add_child(_pause)
	_ui_blockers.append(_pause)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_pause.add_child(v)
	v.add_child(UiKit.label("Pausa", 30, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Riprendi", func(): toggle_pause()))
	var training := Game.mode == Game.Mode.TRAINING
	if training:
		v.add_child(UiKit.label("Opzioni di allenamento", 15, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UiKit.button("Oro +1000", func(): world.cheat("gold")))
		v.add_child(UiKit.button("Livello +1", func(): world.cheat("level")))
		v.add_child(UiKit.button("Azzera ricariche e mana", func(): world.cheat("cooldowns")))
		var inv := UiKit.button("Invulnerabilità: NO", func(): pass)
		inv.pressed.connect(func():
			world.cheat("invulnerable")
			await get_tree().create_timer(0.1, true, false, true).timeout
			inv.text = "Invulnerabilità: %s" % ("SÌ" if Game.cheats.invulnerable else "NO"))
		v.add_child(inv)
		var spd := UiKit.button("Velocità di gioco: ×1", func(): pass)
		spd.pressed.connect(func():
			Game.base_time_scale = 2.0 if Game.base_time_scale < 1.5 else 1.0
			spd.text = "Velocità di gioco: ×%d" % int(Game.base_time_scale))
		v.add_child(spd)
	else:
		v.add_child(UiKit.label("(in rete il gioco non si ferma)", 13, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var music := UiKit.button("Musica: sì / no (M)", func(): Audio.toggle_music_mute())
	v.add_child(music)
	v.add_child(UiKit.button("Esci al menu principale", func():
		get_tree().paused = false
		world.leave_requested.emit()))


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	if Game.mode == Game.Mode.TRAINING:
		get_tree().paused = _pause.visible
		Engine.time_scale = 1.0 if _pause.visible else Game.base_time_scale
	Audio.play_ui("ui_open" if _pause.visible else "ui_close")


# --- Tabella punteggio ------------------------------------------------------------

func _build_scoreboard() -> void:
	_score = UiPanel.new(16)
	_score.set_anchors_preset(Control.PRESET_CENTER)
	_score.offset_left = -330
	_score.offset_right = 330
	_score.offset_top = -150
	_score.offset_bottom = 100
	_score.visible = false
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score)
	_score_text = RichTextLabel.new()
	_score_text.bbcode_enabled = true
	_score_text.fit_content = true
	_score_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score.add_child(_score_text)


func _update_scoreboard() -> void:
	var t := "[center][b][color=#ffd27a]Tabella punteggio[/color][/b][/center]\n\n"
	t += "[table=7][cell][b]Giocatore[/b]   [/cell][cell][b]Liv.[/b]  [/cell][cell][b]U/M[/b]  [/cell][cell][b]Last hit[/b]  [/cell][cell][b]Oro[/b]  [/cell][cell][b]Danni eroi[/b]  [/cell][cell][b]Danni edifici[/b][/cell]"
	for hd in world.hero_data.values():
		var col := "#60e0c0" if hd.team == 0 else "#e06080"
		t += "[cell][color=%s]%s[/color]   [/cell][cell]%d[/cell][cell]%d/%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell]" % [col, hd.player_name, hd.level, hd.kills, hd.deaths, hd.last_hits, int(hd.gold_total), int(hd.dmg_heroes), int(hd.dmg_buildings)]
	t += "[/table]"
	_score_text.text = t


# --- Aggiornamento per frame ----------------------------------------------------

func _process(delta: float) -> void:
	if world == null:
		return
	var _pt := Time.get_ticks_usec()
	_hud_update(delta)
	if Game.prof_enabled:
		Game.prof_add("hud", Time.get_ticks_usec() - _pt)


func _hud_update(delta: float) -> void:
	_score.visible = Input.is_action_pressed("scoreboard")
	if _score.visible:
		_update_scoreboard()
	var hd := world.local_hero_data()
	var u := world.local_hero_unit()
	# orologio, punteggio, prossima ondata
	var gt := maxi(0, int(world.game_time))
	_clock_label.text = "%02d:%02d" % [gt / 60, gt % 60]
	_score_label.text = "%d  –  %d" % [world.team_kills[0], world.team_kills[1]]
	_wave_label.text = "Prossima ondata tra %d s" % ceili(world.wave_in)
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		var s := "FPS %d" % Engine.get_frames_per_second()
		if Game.mode == Game.Mode.CLIENT or Game.mode == Game.Mode.HOST:
			var ping := int(Net.rtt * 1000.0)
			var col := "verde" if ping < 80 else ("giallo" if ping < 150 else "rosso")
			s = "Ping %d ms (%s) · perdita %.0f%% · %s" % [ping, col, Net.loss * 100.0, s]
			_net_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if ping < 80 else (Color(1, 0.9, 0.4) if ping < 150 else Color(1, 0.4, 0.4)))
		_net_label.text = s
	# conto alla rovescia di inizio partita
	if world.countdown > 0.0:
		_countdown_label.text = str(ceili(world.countdown))
	elif world.countdown < 0.0 and not world.running and world.is_server:
		_countdown_label.text = ""
	else:
		_countdown_label.text = ""
	if hd == null or u == null:
		return
	_portrait_name.text = "%s · %s" % [Game.HERO.name, hd.player_name]
	_portrait_level.text = ("+%d punti abilità" % hd.ability_points) if hd.ability_points > 0 else ""
	if _portrait_over.level != hd.level:
		_portrait_over.level = hd.level
		_portrait_over.queue_redraw()
	if _portrait_over.has_meta("alive") and bool(_portrait_over.get_meta("alive")) != u.alive:
		_portrait_over.queue_redraw()
	_portrait_over.set_meta("alive", u.alive)
	_xp_bar.max_value = Game.xp_to_next(hd.level)
	_xp_bar.value = hd.xp
	_hp_bar.max_value = u.max_hp
	_hp_bar.value = u.hp
	_hp_text.text = "%d / %d   +%.1f" % [int(u.hp), int(u.max_hp), u.hp_regen if world.is_server else Game.HERO.hp_regen + Game.HERO.hp_regen_per_lvl * (hd.level - 1)]
	_mana_bar.max_value = maxf(1.0, u.max_mana)
	_mana_bar.value = u.mana
	_mana_text.text = "%d / %d" % [int(u.mana), int(u.max_mana)]
	_gold_label.text = "%d" % int(hd.gold)
	var dmg := Game.HERO.damage + Game.HERO.damage_per_lvl * (hd.level - 1)
	var arm := Game.HERO.armor + Game.HERO.armor_per_lvl * (hd.level - 1)
	var spd := Game.HERO.move_speed
	for it in hd.items:
		if it != "":
			dmg += Game.ITEMS[it].get("damage", 0.0)
			arm += Game.ITEMS[it].get("armor", 0.0)
			spd += Game.ITEMS[it].get("move_speed", 0.0)
	_stat_labels.damage.text = str(int(dmg))
	_stat_labels.armor.text = "%.1f" % arm
	_stat_labels.speed.text = "%.1f" % spd
	for i in 4:
		var ab: Dictionary = Game.ABILITIES[i]
		var lvl: int = hd.ability_levels[i]
		var cd_max: float = ab.cooldown[maxi(0, lvl - 1)]
		var learnable: bool = hd.ability_points > 0 and lvl < ab.max_level and hd.level >= Sim.required_level(i, lvl + 1) and (i != 3 or Game.ENABLE_ULTIMATE)
		var cost: int = int(ab.mana[maxi(0, lvl - 1)])
		_abilities[i].set_state(lvl, hd.cooldowns[i], cd_max, u.mana < cost, learnable, cost)
	for i in 6:
		_items[i].set_item(hd.items[i])
	# negozio: disponibile solo vicino alla fontana
	if _shop.visible:
		var near := u.pos.distance_to(MapData.FOUNTAIN[u.team]) <= Game.SHOP_RANGE
		_shop_hint.text = "" if near else "Avvicinati alla fontana per comprare"
		_shop_gold.text = str(int(hd.gold))
		for id in _shop_buttons:
			var afford: bool = hd.gold >= Game.ITEMS[id].cost
			(_shop_buttons[id] as _ShopCard).refresh(afford, near and afford and hd.item_count() < 6)
	# schermata di morte
	_death_overlay.visible = not u.alive
	if not u.alive:
		_death_label.text = "Rinascita tra %d s\nTorno dalle ceneri..." % ceili(hd.respawn_timer)


func _input(event: InputEvent) -> void:
	# click destro su un oggetto = vendi
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and world:
		for i in 6:
			if _items[i].is_visible_in_tree() and _items[i].get_global_rect().has_point(event.position):
				world.send_command(["sell", i])
				get_viewport().set_input_as_handled()
				return
