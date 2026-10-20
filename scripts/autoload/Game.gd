extends Node
## Stato globale: costanti di gioco e bilanciamento, impostazioni utente, input map.
## Tutti i numeri di bilanciamento stanno qui (vedi wiki/concepts/bilanciamento.md).

const VERSION := "0.1.0"

# --- Simulazione -------------------------------------------------------------
const TICK_RATE := 30                      # tick del server al secondo
const TICK := 1.0 / TICK_RATE
const SNAPSHOT_FULL_EVERY := 15            # snapshot completo ogni N tick (0.5 s)
const INTERP_DELAY := 0.1                  # ritardo di interpolazione sul client (s)
const MAX_UNITS := 90                      # salvaguardia contro accumuli
const AI_INTERVAL := 0.2                   # ricerca bersagli di creep/torri (s)
const GRID_CELL := 8.0                     # cella della griglia spaziale (m)

enum Team { RADIANT = 0, DIRE = 1, NEUTRAL = 2 }
enum Kind { HERO, CREEP_MELEE, CREEP_RANGED, CREEP_SIEGE, TOWER, ANCIENT, FOUNTAIN }

const TEAM_NAMES := ["la Lega dell'Alba", "il Culto della Cenere"]
const TEAM_SHORT := ["Lega dell'Alba", "Culto della Cenere"]
const TEAM_COLORS := [Color(0.25, 0.85, 0.75), Color(0.85, 0.22, 0.45)]
const TEAM_ACCENT := [Color(1.0, 0.82, 0.35), Color(0.55, 0.25, 0.75)]

# --- Mappa (coordinate logiche Vector2 = x,z del mondo) -----------------------
const LANE_A := Vector2(-72, 72)           # base Lega dell'Alba (in basso a sinistra)
const LANE_B := Vector2(72, -72)           # base Culto della Cenere (in alto a destra)
const LANE_HALF_WIDTH := 15.0
const BASE_RADIUS := 26.0
const MAP_HALF := 130.0

# --- Eroe: Kael, il Piromante -------------------------------------------------
const HERO := {
	"name": "Kael",
	"title": "il Piromante",
	"hp": 600.0, "hp_per_lvl": 80.0,
	"hp_regen": 2.0, "hp_regen_per_lvl": 0.2,
	"mana": 300.0, "mana_per_lvl": 40.0,
	"mana_regen": 1.5, "mana_regen_per_lvl": 0.15,
	"damage": 45.0, "damage_per_lvl": 4.0,
	"attack_interval": 1.3, "attack_interval_per_lvl": -0.03, "attack_interval_min": 0.7,
	"attack_range": 6.0, "attack_point": 0.3,
	"projectile_speed": 22.0,
	"move_speed": 7.0,
	"armor": 2.0, "armor_per_lvl": 0.3,
	"magic_resist": 0.25,
	"radius": 0.7,
	"max_level": 10,
}
const XP_RANGE := 12.0
const XP_CREEP := 40
const XP_TOWER := 150
const XP_HERO_BASE := 200
const XP_HERO_PER_LVL := 20
const GOLD_PER_SEC := 1.0
const GOLD_START := 600
const GOLD_LAST_HIT := Vector2i(35, 45)
const GOLD_TOWER := 200
const GOLD_HERO_KILL := 250
const RESPAWN_BASE := 4.0
const RESPAWN_PER_LVL := 2.0

static func xp_to_next(level: int) -> int:
	return 100 * level

static func armor_multiplier(armor: float) -> float:
	return 1.0 - (0.06 * armor) / (1.0 + 0.06 * absf(armor))

# --- Abilità -----------------------------------------------------------------
# target: "dir" (direzione), "point" (punto), "none" (attorno all'eroe)
const ABILITIES := [
	{
		"key": "Q", "id": "fireball", "name": "Palla di fuoco",
		"desc": "Kael scaglia una sfera infuocata in linea retta. Esplode sul primo nemico colpito infliggendo danno magico ad area.",
		"target": "dir", "range": 14.0, "speed": 25.0, "aoe": 3.0,
		"damage": [90.0, 150.0, 210.0, 270.0], "mana": [80.0, 80.0, 80.0, 80.0], "cooldown": [6.0, 6.0, 6.0, 6.0],
		"max_level": 4, "req_level": 1, "cast_point": 0.25,
	},
	{
		"key": "W", "id": "blink", "name": "Scatto",
		"desc": "Kael svanisce in uno sbuffo di braci e riappare in un vortice di fiamme nel punto indicato.",
		"target": "point", "range": 10.0,
		"damage": [0.0, 0.0, 0.0, 0.0], "mana": [60.0, 60.0, 60.0, 60.0], "cooldown": [14.0, 12.0, 10.0, 8.0],
		"max_level": 4, "req_level": 1, "cast_point": 0.1,
	},
	{
		"key": "E", "id": "shockwave", "name": "Onda d'urto",
		"desc": "Kael pianta il bastone a terra: un anello di fuoco arcano danneggia e rallenta del 40% i nemici vicini per 2 secondi.",
		"target": "none", "range": 0.0, "aoe": 5.0, "slow": 0.4, "slow_time": 2.0,
		"damage": [60.0, 100.0, 140.0, 180.0], "mana": [100.0, 100.0, 100.0, 100.0], "cooldown": [10.0, 10.0, 10.0, 10.0],
		"max_level": 4, "req_level": 1, "cast_point": 0.3,
	},
	{
		"key": "R", "id": "meteor", "name": "Meteora",
		"desc": "Kael evoca un frammento di cristallo infuocato dal cielo: dopo 1 secondo colpisce l'area, infliggendo danno enorme e stordendo.",
		"target": "point", "range": 16.0, "aoe": 6.0, "delay": 1.0, "stun": 1.5,
		"damage": [300.0, 450.0, 600.0], "mana": [200.0, 200.0, 200.0], "cooldown": [60.0, 50.0, 40.0],
		"max_level": 3, "req_level": 6, "cast_point": 0.4,
	},
]

# --- Creep -------------------------------------------------------------------
const WAVE_INTERVAL := 30.0
const FIRST_WAVE := 5.0
const CREEPS := {
	Kind.CREEP_MELEE: {"hp": 550.0, "damage": 20.0, "attack_interval": 1.0, "attack_range": 1.4, "attack_point": 0.4,
		"move_speed": 5.0, "armor": 2.0, "radius": 0.6, "gold": 0, "ranged": false},
	Kind.CREEP_RANGED: {"hp": 300.0, "damage": 24.0, "attack_interval": 1.0, "attack_range": 5.0, "attack_point": 0.4,
		"move_speed": 5.0, "armor": 0.0, "radius": 0.55, "ranged": true, "projectile_speed": 18.0},
	Kind.CREEP_SIEGE: {"hp": 900.0, "damage": 40.0, "attack_interval": 2.5, "attack_range": 7.0, "attack_point": 0.6,
		"move_speed": 3.5, "armor": 0.0, "radius": 0.9, "ranged": true, "projectile_speed": 12.0, "building_mult": 2.5},
}
const CREEP_AGGRO := 8.0
const CREEP_LEASH := 12.0
const WAVE_MELEE := 3
const WAVE_RANGED := 1
const SIEGE_EVERY := 5                     # Fase 2
const CREEP_SCALING_EVERY := 300.0         # Fase 2: +10% ogni 5 min
const CREEP_SCALING := 0.10
const ENABLE_SIEGE := false                # Fase 2
const ENABLE_ULTIMATE := false             # Fase 2: abilità R (Meteora)
const ENABLE_CREEP_SCALING := false        # Fase 2

# --- Edifici -----------------------------------------------------------------
const BUILDINGS := {
	"t1": {"hp": 1800.0, "armor": 10.0, "damage": 110.0, "attack_interval": 1.0, "attack_range": 8.0, "radius": 2.0},
	"t2": {"hp": 2200.0, "armor": 12.0, "damage": 140.0, "attack_interval": 1.0, "attack_range": 8.0, "radius": 2.0},
	"ancient": {"hp": 4000.0, "armor": 15.0, "damage": 0.0, "attack_interval": 1.0, "attack_range": 0.0, "radius": 4.0},
	"fountain": {"hp": 1.0, "armor": 0.0, "damage": 300.0, "attack_interval": 0.3, "attack_range": 10.0, "radius": 2.5},
}
const TOWER_PROJECTILE_SPEED := 26.0
const FOUNTAIN_REGEN := 0.05               # frazione di vita/mana max al secondo
const FOUNTAIN_AURA := 12.0
const SHOP_RANGE := 18.0

# --- Oggetti -----------------------------------------------------------------
const ITEMS := {
	"sword": {"name": "Spada lunga", "cost": 400, "damage": 15.0, "desc": "+15 danno"},
	"armor": {"name": "Armatura di cuoio", "cost": 350, "armor": 4.0, "desc": "+4 armatura"},
	"boots": {"name": "Stivali della velocità", "cost": 450, "move_speed": 1.5, "desc": "+1.5 velocità di movimento"},
	"vitality": {"name": "Gemma della vitalità", "cost": 500, "hp": 250.0, "desc": "+250 vita"},
	"potion": {"name": "Pozione di cura", "cost": 100, "consumable": true, "heal": 400.0, "duration": 8.0,
		"desc": "Consumabile: ripristina 400 vita in 8 s (interrotta dai danni di un eroe)"},
	# Fase 2
	"crystal": {"name": "Cristallo arcano", "cost": 500, "mana": 200.0, "mana_regen": 1.0, "desc": "+200 mana, +1 rigenerazione mana", "phase2": true},
	"ring": {"name": "Anello di rigenerazione", "cost": 300, "hp_regen": 4.0, "desc": "+4 rigenerazione vita", "phase2": true},
	"mana_potion": {"name": "Pozione di mana", "cost": 100, "consumable": true, "restore_mana": 250.0, "duration": 8.0,
		"desc": "Consumabile: ripristina 250 mana in 8 s", "phase2": true},
	"vampire": {"name": "Lama del vampiro", "cost": 1200, "damage": 20.0, "lifesteal": 0.15, "desc": "+20 danno, 15% rubavita", "phase2": true},
}
const SHOP_ORDER := ["sword", "armor", "boots", "vitality", "potion", "crystal", "ring", "mana_potion", "vampire"]
const ENABLE_PHASE2_ITEMS := false
const ENABLE_MUSIC_CROSSFADE := false      # Fase 2: musica di combattimento automatica

# --- Stato della sessione -----------------------------------------------------
enum Mode { NONE, TRAINING, HOST, CLIENT }
var mode: int = Mode.NONE
var local_team: int = Team.RADIANT
var player_name := "Giocatore"
var opponent_name := "Avversario"
var cheats := {"invulnerable": false}
var base_time_scale: float = 1.0           # velocità di gioco (allenamento ×2, test accelerati)

# --- Impostazioni (user://settings.cfg) --------------------------------------
const SETTINGS_PATH := "user://settings.cfg"
var settings := {
	"quality": 1,             # 0 bassa, 1 media, 2 alta
	"fullscreen": false,
	"vsync": true,
	"fps_limit": 0,           # 0 = illimitato
	"vol_master": 0.8,
	"vol_music": 0.6,
	"vol_sfx": 0.8,
	"vol_ui": 0.7,
	"quick_cast": false,
	"edge_scroll": true,
	"scroll_speed": 1.0,
	"last_ip": "127.0.0.1",
	"last_port": 7777,
	"player_name": "Giocatore",
}

signal settings_changed

var user_args: PackedStringArray = PackedStringArray()


func _ready() -> void:
	user_args = OS.get_cmdline_user_args()
	_setup_input()
	load_settings()
	apply_settings()


func has_arg(name: String) -> bool:
	return user_args.has(name)


func arg_value(name: String, default: String = "") -> String:
	var i := user_args.find(name)
	if i >= 0 and i + 1 < user_args.size():
		return user_args[i + 1]
	return default


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cfg.get_value("settings", k, settings[k])
	player_name = str(settings.player_name)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.fps_limit)
	settings_changed.emit()


func _setup_input() -> void:
	var keys := {
		"ability_q": KEY_Q, "ability_w": KEY_W, "ability_e": KEY_E, "ability_r": KEY_R,
		"attack_move": KEY_A, "stop": KEY_S, "shop": KEY_B, "center_hero": KEY_SPACE,
		"lock_camera": KEY_Y, "scoreboard": KEY_TAB, "pause": KEY_ESCAPE, "pause_alt": KEY_F10,
		"screenshot": KEY_F12, "mute_music": KEY_M,
		"cam_left": KEY_LEFT, "cam_right": KEY_RIGHT, "cam_up": KEY_UP, "cam_down": KEY_DOWN,
		"item_1": KEY_1, "item_2": KEY_2, "item_3": KEY_3, "item_4": KEY_4, "item_5": KEY_5, "item_6": KEY_6,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)
