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
var _stats_label: Label
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


func set_attack_cursor(on: bool) -> void:
	var targeting := world != null and (world.targeting_slot >= 0 or world.attack_move_mode)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if (on or targeting) else Input.CURSOR_ARROW)


# --- Costruzione -------------------------------------------------------------

func _bar(col: Color, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.04, 0.95)
	bg.set_corner_radius_all(3)
	bg.border_color = Color(0, 0, 0)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_bottom_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -430
	panel.offset_right = 430
	panel.offset_top = -170
	panel.offset_bottom = -8
	add_child(panel)
	_ui_blockers.append(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Ritratto
	var portrait := VBoxContainer.new()
	portrait.custom_minimum_size = Vector2(130, 0)
	row.add_child(portrait)
	var face := _PortraitFace.new()
	face.custom_minimum_size = Vector2(130, 92)
	face.hud = self
	portrait.add_child(face)
	_portrait_name = UiKit.label("Kael", 15, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	portrait.add_child(_portrait_name)
	_xp_bar = _bar(Color(0.75, 0.55, 0.95), 8)
	portrait.add_child(_xp_bar)
	_portrait_level = UiKit.label("Livello 1", 13, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	portrait.add_child(_portrait_level)

	# Abilità + barre
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(360, 0)
	center.add_theme_constant_override("separation", 6)
	row.add_child(center)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	center.add_child(spacer)
	var abil := HBoxContainer.new()
	abil.alignment = BoxContainer.ALIGNMENT_CENTER
	abil.add_theme_constant_override("separation", 14)
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
	spacer2.custom_minimum_size = Vector2(0, 6)
	center.add_child(spacer2)
	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size = Vector2(0, 20)
	center.add_child(hp_wrap)
	_hp_bar = _bar(Color(0.25, 0.75, 0.25), 20)
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_wrap.add_child(_hp_bar)
	_hp_text = UiKit.label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_wrap.add_child(_hp_text)
	var mana_wrap := Control.new()
	mana_wrap.custom_minimum_size = Vector2(0, 16)
	center.add_child(mana_wrap)
	_mana_bar = _bar(Color(0.25, 0.45, 0.95), 16)
	_mana_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	mana_wrap.add_child(_mana_bar)
	_mana_text = UiKit.label("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_mana_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	mana_wrap.add_child(_mana_text)

	# Oggetti + oro + statistiche
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)
	for i in 6:
		var b := AbilityButton.new()
		b.index = i
		b.is_item = true
		b.key_text = str(i + 1)
		b.custom_minimum_size = Vector2(48, 40)
		b.activated.connect(func(idx): _item_clicked(idx))
		b.mouse_entered.connect(func(): _show_item_tooltip(i, b))
		b.mouse_exited.connect(func(): _tooltip.visible = false)
		grid.add_child(b)
		_items.append(b)
	_gold_label = UiKit.label("0", 20, Color(1.0, 0.84, 0.25))
	right.add_child(_gold_label)
	_stats_label = UiKit.label("", 12, UiKit.TEXT_DIM)
	right.add_child(_stats_label)


class _PortraitFace extends Control:
	var hud: Hud
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.12, 0.07, 0.06))
		var team: int = Game.local_team
		var cape := Color(0.95, 0.35, 0.18) if team == 0 else Color(0.45, 0.2, 0.65)
		# busto stilizzato di Kael: mantello, cappuccio, fiamma
		var c := size * 0.5 + Vector2(0, 14)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-46, 40), c + Vector2(-26, -14), c + Vector2(26, -14), c + Vector2(46, 40)]), cape.darkened(0.2))
		draw_circle(c + Vector2(0, -24), 18, Color(0.95, 0.8, 0.65))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -24), c + Vector2(0, -62), c + Vector2(24, -24)]), cape)
		draw_circle(c + Vector2(-6, -24), 2.5, Color(0.1, 0.1, 0.1))
		draw_circle(c + Vector2(6, -24), 2.5, Color(0.1, 0.1, 0.1))
		var t := Time.get_ticks_msec() * 0.006
		draw_line(c + Vector2(40, 40), c + Vector2(44, -26), Color(0.45, 0.3, 0.18), 4)
		draw_circle(c + Vector2(44, -32 + sin(t) * 1.5), 8 + sin(t * 1.7) * 1.5, Color(1.0, 0.55, 0.15) if team == 0 else Color(0.75, 0.35, 1.0))
		draw_circle(c + Vector2(44, -32), 4, Color(1, 0.95, 0.7))
		var u := hud.world.local_hero_unit() if hud.world else null
		if u and not u.alive:
			draw_rect(r, Color(0, 0, 0, 0.6))
		draw_rect(r, UiKit.GOLD, false, 2.0)


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
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
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	frame.offset_left = 8
	frame.offset_right = 8 + 236
	frame.offset_top = -244
	frame.offset_bottom = -8
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
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.05, 0.04, 0.06, 0.96), UiKit.GOLD, 6, 1))
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
	_shop = PanelContainer.new()
	_shop.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_shop.offset_left = -380
	_shop.offset_right = -12
	_shop.offset_top = -260
	_shop.offset_bottom = 200
	_shop.visible = false
	add_child(_shop)
	_ui_blockers.append(_shop)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_shop.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiKit.label("Negozio", 24, UiKit.GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UiKit.button("✕", func(): toggle_shop(), 0)
	close.custom_minimum_size = Vector2(40, 36)
	head.add_child(close)
	_shop_hint = UiKit.label("", 14, Color(1, 0.6, 0.5))
	v.add_child(_shop_hint)
	for id in Game.SHOP_ORDER:
		var d: Dictionary = Game.ITEMS[id]
		if d.get("phase2", false) and not Game.ENABLE_PHASE2_ITEMS:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 48)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "      %s  —  %d oro\n      %s" % [d.name, d.cost, d.desc]
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		var icon := _ShopIcon.new()
		icon.symbol = id
		icon.position = Vector2(6, 8)
		icon.size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		b.pressed.connect(func(): world.send_command(["buy", id]))
		v.add_child(b)
		_shop_buttons[id] = b
	v.add_child(UiKit.label("Click per comprare. Click destro su un oggetto\nnell'inventario per venderlo (50%).", 12, UiKit.TEXT_DIM))


class _ShopIcon extends Control:
	var symbol := ""
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.08, 0.07))
		UiKit.draw_symbol(self, symbol, size * 0.5, size.x * 0.5, Color(1, 0.5, 0.15))
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.GOLD, false, 1.0)


func toggle_shop() -> void:
	_shop.visible = not _shop.visible
	Audio.play_ui("ui_open" if _shop.visible else "ui_close")


# --- Pausa ---------------------------------------------------------------------

func _build_pause() -> void:
	_pause = PanelContainer.new()
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
	_score = PanelContainer.new()
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
	_portrait_level.text = "Livello %d%s" % [hd.level, ("  (+%d punti)" % hd.ability_points) if hd.ability_points > 0 else ""]
	_xp_bar.max_value = Game.xp_to_next(hd.level)
	_xp_bar.value = hd.xp
	_hp_bar.max_value = u.max_hp
	_hp_bar.value = u.hp
	_hp_text.text = "%d / %d   +%.1f" % [int(u.hp), int(u.max_hp), u.hp_regen if world.is_server else Game.HERO.hp_regen + Game.HERO.hp_regen_per_lvl * (hd.level - 1)]
	_mana_bar.max_value = maxf(1.0, u.max_mana)
	_mana_bar.value = u.mana
	_mana_text.text = "%d / %d" % [int(u.mana), int(u.max_mana)]
	_gold_label.text = "● %d oro" % int(hd.gold)
	var dmg := Game.HERO.damage + Game.HERO.damage_per_lvl * (hd.level - 1)
	var arm := Game.HERO.armor + Game.HERO.armor_per_lvl * (hd.level - 1)
	var spd := Game.HERO.move_speed
	for it in hd.items:
		if it != "":
			dmg += Game.ITEMS[it].get("damage", 0.0)
			arm += Game.ITEMS[it].get("armor", 0.0)
			spd += Game.ITEMS[it].get("move_speed", 0.0)
	_stats_label.text = "Danno %d · Armatura %.1f\nVelocità %.1f" % [int(dmg), arm, spd]
	for i in 4:
		var ab: Dictionary = Game.ABILITIES[i]
		var lvl: int = hd.ability_levels[i]
		var cd_max: float = ab.cooldown[maxi(0, lvl - 1)]
		var learnable: bool = hd.ability_points > 0 and lvl < ab.max_level and hd.level >= Sim.required_level(i, lvl + 1) and (i != 3 or Game.ENABLE_ULTIMATE)
		var cost: int = int(ab.mana[maxi(0, lvl - 1)])
		_abilities[i].set_state(lvl, hd.cooldowns[i], cd_max, u.mana < cost, learnable, cost)
	for i in 6:
		var it: String = hd.items[i]
		_items[i].symbol = it
		_items[i].level = 1 if it != "" else 0
		_items[i].queue_redraw()
	# negozio: disponibile solo vicino alla fontana
	if _shop.visible:
		var near := u.pos.distance_to(MapData.FOUNTAIN[u.team]) <= Game.SHOP_RANGE
		_shop_hint.text = "" if near else "Avvicinati alla fontana per comprare"
		for id in _shop_buttons:
			var b: Button = _shop_buttons[id]
			b.disabled = not near or hd.gold < Game.ITEMS[id].cost or hd.item_count() >= 6
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
