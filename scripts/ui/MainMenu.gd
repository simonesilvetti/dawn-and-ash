class_name MainMenu
extends Control
## Menu principale: allenamento, ospita, unisciti, impostazioni. Lobby per il 1 contro 1.

signal start_training
signal quit_game

var _main_panel: VBoxContainer
var _host_panel: VBoxContainer
var _join_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _lobby_label: RichTextLabel
var _status: Label
var _name_edit: LineEdit
var _host_port: LineEdit
var _join_ip: LineEdit
var _join_port: LineEdit
var _ready_btn_host: Button
var _ready_btn_join: Button
var _host_info: Label
var _is_ready := false
var _card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	# velo scuro a sinistra per leggibilità
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 620
	shade.color = Color(0.04, 0.03, 0.06, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := UiKit.label("ANCIENTS CLASH", 64, UiKit.GOLD_BRIGHT)
	title.position = Vector2(60, 50)
	title.add_theme_constant_override("outline_size", 10)
	add_child(title)
	var sub := UiKit.label("Le Terre di Aethra", 26, Color(1.0, 0.7, 0.45))
	sub.position = Vector2(66, 130)
	add_child(sub)
	_card = PanelContainer.new()
	_card.position = Vector2(60, 200)
	_card.custom_minimum_size = Vector2(440, 0)
	add_child(_card)
	var stack := VBoxContainer.new()
	_card.add_child(stack)
	_build_main(stack)
	_build_host(stack)
	_build_join(stack)
	_build_settings(stack)
	_status = UiKit.label("", 16, Color(1, 0.75, 0.5))
	_status.position = Vector2(60, 860)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_top = -60
	_status.offset_left = 60
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(700, 0)
	add_child(_status)
	var ver := UiKit.label("v%s · Kael, il Piromante" % Game.VERSION, 13, UiKit.TEXT_DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -260
	ver.offset_top = -30
	add_child(ver)
	Net.lobby_changed.connect(_refresh_lobby)
	Net.connection_failed.connect(func(r): _show(_join_panel); _set_status(r))
	Net.connected.connect(func(): _set_status("Connesso! Premi \"Pronto\" quando vuoi iniziare."))
	Net.host_lost.connect(func(r): _show(_main_panel); _set_status(r))
	_show(_main_panel)
	Audio.play_music("menu")


func set_status(t: String) -> void:
	_set_status(t)


func _set_status(t: String) -> void:
	if _status:
		_status.text = t


func _show(p: Control) -> void:
	for c in [_main_panel, _host_panel, _join_panel, _settings_panel]:
		c.visible = c == p
	_card.reset_size()


func _build_main(stack: Control) -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 12)
	stack.add_child(_main_panel)
	_main_panel.add_child(UiKit.label("Nome del giocatore", 14, UiKit.TEXT_DIM))
	_name_edit = LineEdit.new()
	_name_edit.text = Game.player_name
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 40)
	_name_edit.text_changed.connect(func(t):
		Game.player_name = t if t.strip_edges() != "" else "Giocatore"
		Game.settings.player_name = Game.player_name
		Game.save_settings())
	_main_panel.add_child(_name_edit)
	_main_panel.add_child(UiKit.button("Allenamento", func(): start_training.emit(), 380))
	_main_panel.add_child(UiKit.button("Ospita partita (1 contro 1)", func(): _show(_host_panel), 380))
	_main_panel.add_child(UiKit.button("Unisciti a una partita", func(): _show(_join_panel), 380))
	_main_panel.add_child(UiKit.button("Impostazioni", func(): _show(_settings_panel), 380))
	_main_panel.add_child(UiKit.button("Esci", func(): quit_game.emit(), 380))


func _build_host(stack: Control) -> void:
	_host_panel = VBoxContainer.new()
	_host_panel.add_theme_constant_override("separation", 10)
	stack.add_child(_host_panel)
	_host_panel.add_child(UiKit.label("Ospita una partita", 26, UiKit.GOLD_BRIGHT))
	_host_panel.add_child(UiKit.label("Porta (UDP)", 14, UiKit.TEXT_DIM))
	_host_port = LineEdit.new()
	_host_port.text = str(Game.settings.last_port)
	_host_panel.add_child(_host_port)
	_host_panel.add_child(UiKit.button("Avvia il server", _do_host))
	_host_info = UiKit.label("", 15, UiKit.TEXT)
	_host_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_host_panel.add_child(_host_info)
	_ready_btn_host = UiKit.button("Pronto", func(): _toggle_ready())
	_ready_btn_host.visible = false
	_host_panel.add_child(_ready_btn_host)
	_host_panel.add_child(UiKit.button("Indietro", func():
		Net.leave()
		_is_ready = false
		_host_info.text = ""
		_ready_btn_host.visible = false
		_show(_main_panel)))


func _build_join(stack: Control) -> void:
	_join_panel = VBoxContainer.new()
	_join_panel.add_theme_constant_override("separation", 10)
	stack.add_child(_join_panel)
	_join_panel.add_child(UiKit.label("Unisciti a una partita", 26, UiKit.GOLD_BRIGHT))
	_join_panel.add_child(UiKit.label("Indirizzo IP dell'host", 14, UiKit.TEXT_DIM))
	_join_ip = LineEdit.new()
	_join_ip.text = str(Game.settings.last_ip)
	_join_panel.add_child(_join_ip)
	_join_panel.add_child(UiKit.label("Porta", 14, UiKit.TEXT_DIM))
	_join_port = LineEdit.new()
	_join_port.text = str(Game.settings.last_port)
	_join_panel.add_child(_join_port)
	_join_panel.add_child(UiKit.button("Connetti", _do_join))
	_lobby_label = RichTextLabel.new()
	_lobby_label.bbcode_enabled = true
	_lobby_label.fit_content = true
	_lobby_label.custom_minimum_size = Vector2(380, 0)
	_join_panel.add_child(_lobby_label)
	_ready_btn_join = UiKit.button("Pronto", func(): _toggle_ready())
	_ready_btn_join.visible = false
	_join_panel.add_child(_ready_btn_join)
	_join_panel.add_child(UiKit.button("Indietro", func():
		Net.leave()
		_is_ready = false
		_lobby_label.text = ""
		_ready_btn_join.visible = false
		_show(_main_panel)))


func _do_host() -> void:
	var port := int(_host_port.text)
	if port <= 0 or port > 65535:
		_set_status("Porta non valida.")
		return
	var err := Net.host(port)
	if err != OK:
		_set_status("Impossibile avviare il server sulla porta %d (già in uso?)." % port)
		return
	Game.settings.last_port = port
	Game.save_settings()
	var ips := Net.local_ips()
	_host_info.text = "Server avviato sulla porta %d.\nComunica al tuo amico uno di questi indirizzi:\n  %s\n\nIn attesa dell'avversario..." % [port, "\n  ".join(ips) if ips.size() > 0 else "127.0.0.1"]
	_ready_btn_host.visible = true
	_set_status("")
	_refresh_lobby()


func _do_join() -> void:
	var ip := _join_ip.text.strip_edges()
	var port := int(_join_port.text)
	if ip == "" or port <= 0:
		_set_status("Inserisci IP e porta.")
		return
	Game.settings.last_ip = ip
	Game.settings.last_port = port
	Game.save_settings()
	var err := Net.join(ip, port)
	if err != OK:
		_set_status("Errore di connessione (%d)." % err)
		return
	_set_status("Connessione a %s:%d in corso..." % [ip, port])
	_ready_btn_join.visible = true


func _toggle_ready() -> void:
	_is_ready = not _is_ready
	Net.set_ready(_is_ready)
	for b in [_ready_btn_host, _ready_btn_join]:
		b.text = "Non pronto" if _is_ready else "Pronto"


func _refresh_lobby() -> void:
	var t := "[b]Giocatori[/b]\n"
	for id in Net.lobby:
		var e: Dictionary = Net.lobby[id]
		t += "%s %s %s\n" % ["[color=#60e0c0]●[/color]" if id == 1 else "[color=#e06080]●[/color]", e.name, "[color=#80ff80](pronto)[/color]" if e.ready else "[color=#aaaaaa](non pronto)[/color]"]
	if _lobby_label:
		_lobby_label.text = t
	if Net.is_host and _host_info:
		var base := _host_info.text.split("\n\n")[0]
		_host_info.text = base + "\n\n" + t.replace("[b]", "").replace("[/b]", "").replace("[color=#60e0c0]", "").replace("[color=#e06080]", "").replace("[color=#80ff80]", "").replace("[color=#aaaaaa]", "").replace("[/color]", "")
		if Net.lobby.size() < 2:
			_host_info.text += "In attesa dell'avversario..."


func _build_settings(stack: Control) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 8)
	stack.add_child(_settings_panel)
	_settings_panel.add_child(UiKit.label("Impostazioni", 26, UiKit.GOLD_BRIGHT))
	var q := OptionButton.new()
	for n in ["Qualità: Bassa", "Qualità: Media", "Qualità: Alta"]:
		q.add_item(n)
	q.selected = int(Game.settings.quality)
	q.item_selected.connect(func(i): Game.settings.quality = i)
	_settings_panel.add_child(q)
	var fps := OptionButton.new()
	var limits := [0, 60, 120, 144]
	for l in limits:
		fps.add_item("Limite FPS: %s" % ("illimitato" if l == 0 else str(l)))
	fps.selected = maxi(0, limits.find(int(Game.settings.fps_limit)))
	fps.item_selected.connect(func(i): Game.settings.fps_limit = limits[i])
	_settings_panel.add_child(fps)
	for opt in [["fullscreen", "Schermo intero"], ["vsync", "VSync"], ["quick_cast", "Lancio rapido delle abilità"], ["edge_scroll", "Scorrimento ai bordi dello schermo"]]:
		var cb := CheckBox.new()
		cb.text = opt[1]
		cb.button_pressed = bool(Game.settings[opt[0]])
		var key: String = opt[0]
		cb.toggled.connect(func(v): Game.settings[key] = v)
		_settings_panel.add_child(cb)
	for opt in [["vol_master", "Volume generale"], ["vol_music", "Musica"], ["vol_sfx", "Effetti"], ["vol_ui", "Interfaccia"], ["scroll_speed", "Velocità telecamera"]]:
		_settings_panel.add_child(UiKit.label(opt[1], 13, UiKit.TEXT_DIM))
		var s := HSlider.new()
		s.min_value = 0.0 if opt[0] != "scroll_speed" else 0.3
		s.max_value = 1.0 if opt[0] != "scroll_speed" else 2.5
		s.step = 0.05
		s.value = float(Game.settings[opt[0]])
		var key: String = opt[0]
		s.value_changed.connect(func(v):
			Game.settings[key] = v
			Audio.apply_volumes())
		_settings_panel.add_child(s)
	_settings_panel.add_child(UiKit.label("La qualità si applica dalla prossima partita.", 12, UiKit.TEXT_DIM))
	_settings_panel.add_child(UiKit.button("Salva e torna indietro", func():
		Game.save_settings()
		Game.apply_settings()
		_show(_main_panel)))
