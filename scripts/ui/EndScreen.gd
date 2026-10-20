class_name EndScreen
extends Control
## Schermata di fine partita con statistiche.

signal replay
signal to_menu

var result: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.02, 0.05, 0.7)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -260
	panel.offset_bottom = 260
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var victory: bool = result.get("victory", false)
	var title := UiKit.label("VITTORIA" if victory else "SCONFITTA", 64, UiKit.GOLD_BRIGHT if victory else Color(0.9, 0.35, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)
	var sub := "La Lega dell'Alba trionfa!" if (victory == (Game.local_team == 0)) else "Il Culto della Cenere trionfa!"
	if result.get("forfeit", false):
		sub = "L'avversario si è disconnesso: vittoria a tavolino."
	v.add_child(UiKit.label(sub, 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var t := int(result.get("time", 0.0))
	var lines := [
		["Durata", "%02d:%02d" % [t / 60, t % 60]],
		["Livello raggiunto", str(result.get("lv", 1))],
		["Uccisioni / Morti", "%d / %d" % [result.get("k", 0), result.get("d", 0)]],
		["Last hit", str(result.get("lh", 0))],
		["Deny", str(result.get("dn", 0))],
		["Oro totale", str(result.get("gt", 0))],
		["Danni agli eroi", str(result.get("dh", 0))],
		["Danni agli edifici", str(result.get("db", 0))],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for l in lines:
		grid.add_child(UiKit.label(l[0], 18, UiKit.TEXT_DIM))
		grid.add_child(UiKit.label(l[1], 18, UiKit.TEXT))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	if Game.mode == Game.Mode.TRAINING:
		h.add_child(UiKit.button("Rigioca", func(): replay.emit(), 200))
	h.add_child(UiKit.button("Menu principale", func(): to_menu.emit(), 200))
