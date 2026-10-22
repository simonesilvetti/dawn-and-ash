class_name HeroData
extends RefCounted
## Stato "privato" di un eroe: progressione, abilità, oggetti, statistiche.
## Sul server è autoritativo; ai client arriva serializzato con to_dict().

var unit_id: int = 0
var peer: int = 0
var team: int = Game.Team.RADIANT
var player_name := ""
var hero := "kael"                    # id in Game.HEROES

var level: int = 1
var xp: int = 0
var gold: float = Game.GOLD_START
var ability_points: int = 0
var ability_levels := [1, 0, 0, 0]       # Q parte al livello 1
var cooldowns := [0.0, 0.0, 0.0, 0.0]
var items: Array = ["", "", "", "", "", ""]
var respawn_timer: float = 0.0

# Effetti attivi delle pozioni: [{kind, per_sec, time}]
var regen_effects: Array = []

# Statistiche
var kills: int = 0
var deaths: int = 0
var last_hits: int = 0
var denies: int = 0
var gold_total: float = 0.0
var dmg_heroes: float = 0.0
var dmg_buildings: float = 0.0


func add_gold(amount: float) -> void:
	gold += amount
	gold_total += amount


func item_count() -> int:
	var n := 0
	for it in items:
		if it != "":
			n += 1
	return n


func abilities() -> Array:
	return Game.hero_abilities(hero)


## Applica livello e oggetti alle statistiche dell'unità.
func apply_stats(u: Unit) -> void:
	var h: Dictionary = Game.hero_def(hero)
	var l := level - 1
	var hp_ratio := u.hp / u.max_hp if u.max_hp > 0.0 else 1.0
	var mana_ratio := u.mana / u.max_mana if u.max_mana > 0.0 else 1.0
	u.max_hp = h.hp + h.hp_per_lvl * l
	u.max_mana = h.mana + h.mana_per_lvl * l
	u.hp_regen = h.hp_regen + h.hp_regen_per_lvl * l
	u.mana_regen = h.mana_regen + h.mana_regen_per_lvl * l
	u.damage = h.damage + h.damage_per_lvl * l
	u.attack_interval = maxf(h.attack_interval_min, h.attack_interval + h.attack_interval_per_lvl * l)
	u.armor = h.armor + h.armor_per_lvl * l
	u.move_speed = h.move_speed
	u.lifesteal = 0.0
	for it in items:
		if it == "":
			continue
		var d: Dictionary = Game.ITEMS[it]
		u.damage += d.get("damage", 0.0)
		u.armor += d.get("armor", 0.0)
		u.move_speed += d.get("move_speed", 0.0)
		u.max_hp += d.get("hp", 0.0)
		u.max_mana += d.get("mana", 0.0)
		u.hp_regen += d.get("hp_regen", 0.0)
		u.mana_regen += d.get("mana_regen", 0.0)
		u.lifesteal += d.get("lifesteal", 0.0)
	u.hp = clampf(hp_ratio * u.max_hp, 0.0, u.max_hp) if u.alive else u.hp
	u.mana = clampf(mana_ratio * u.max_mana, 0.0, u.max_mana)


func to_dict() -> Dictionary:
	return {
		"u": unit_id, "p": peer, "t": team, "n": player_name, "h": hero,
		"lv": level, "xp": xp, "g": int(gold), "ap": ability_points,
		"al": ability_levels, "cd": cooldowns, "it": items, "rt": respawn_timer,
		"k": kills, "d": deaths, "lh": last_hits, "dn": denies,
		"gt": int(gold_total), "dh": int(dmg_heroes), "db": int(dmg_buildings),
	}


func from_dict(d: Dictionary) -> void:
	unit_id = int(d.get("u", unit_id))
	peer = int(d.get("p", peer))
	team = int(d.get("t", team))
	player_name = str(d.get("n", player_name))
	hero = str(d.get("h", hero))
	level = int(d.get("lv", level))
	xp = int(d.get("xp", xp))
	gold = float(d.get("g", gold))
	ability_points = int(d.get("ap", ability_points))
	ability_levels = d.get("al", ability_levels)
	cooldowns = d.get("cd", cooldowns)
	items = d.get("it", items)
	respawn_timer = float(d.get("rt", respawn_timer))
	kills = int(d.get("k", kills))
	deaths = int(d.get("d", deaths))
	last_hits = int(d.get("lh", last_hits))
	denies = int(d.get("dn", denies))
	gold_total = float(d.get("gt", gold_total))
	dmg_heroes = float(d.get("dh", dmg_heroes))
	dmg_buildings = float(d.get("db", dmg_buildings))
