class_name Unit
extends RefCounted
## Dati di una unità della simulazione (eroe, creep, edificio).
## Nessun nodo di scena: la grafica è in UnitView, che legge questi dati.
## Sul server i campi sono autoritativi; sul client sono riempiti dagli snapshot.

enum State { IDLE, MOVING, ATTACKING, CASTING, DEAD }

# Flag di stato trasmessi negli snapshot (u16)
const F_MOVING := 1
const F_ATTACKING := 2
const F_CASTING := 4
const F_STUNNED := 8
const F_DEAD := 16
const F_INVULN := 32
const F_SLOWED := 64
const F_SHIELDED := 128             # Scudo di ferro di Peppino
const F_EMPOWERED := 256            # Totem del sisma di Gorm carico (prossimo attacco potenziato)

var id: int = 0
var kind: int = Game.Kind.CREEP_MELEE
var team: int = Game.Team.RADIANT
var subtype: String = ""            # "t1"/"t2"/"ancient"/"fountain" per gli edifici
var owner_peer: int = 0             # per gli eroi: peer id del giocatore

var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO        # per l'interpolazione tra tick sul server
var facing: float = 0.0             # radianti, 0 = +x
var radius: float = 0.6

var hp: float = 100.0
var max_hp: float = 100.0
var mana: float = 0.0
var max_mana: float = 0.0
var hp_regen: float = 0.0
var mana_regen: float = 0.0
var armor: float = 0.0
var magic_resist: float = 0.0
var damage: float = 10.0
var attack_interval: float = 1.0
var attack_range: float = 1.5
var attack_point: float = 0.3
var projectile_speed: float = 0.0   # 0 = corpo a corpo
var move_speed: float = 5.0
var building_mult: float = 1.0
var lifesteal: float = 0.0

var state: int = State.IDLE
var flags: int = 0                  # usato dal client (da snapshot)
var alive := true
var invulnerable := false

# Ordini / IA
var move_goal := Vector2.ZERO
var has_move_goal := false
var target_id: int = 0
var attack_move := false            # attacco-movimento
var forced_target := false          # bersaglio scelto dal giocatore
var attack_cd: float = 0.0
var windup: float = 0.0             # >0 durante il "punto d'impatto" dell'attacco
var ai_timer: float = 0.0
var leash_origin := Vector2.ZERO
var lane_offset: float = 0.0        # offset laterale nella corsia (creep)

# Stati alterati
var slow_time: float = 0.0
var slow_pct: float = 0.0
var stun_time: float = 0.0
var shield_time: float = 0.0        # riduzione dei danni attiva (Scudo di ferro)
var shield_pct: float = 0.0
var dash_time: float = 0.0          # carica in corso (Peppino): l'unità scivola verso dash_goal
var dash_goal := Vector2.ZERO
var dash_speed: float = 0.0
var dash_slot: int = -1
var dash_leap := false              # balzo (Totem di Gorm): passa sopra i muri della Fenditura
var empower_time: float = 0.0       # Totem del sisma: prossimo attacco potenziato entro questo tempo
var empower_mult: float = 1.0
var empower_range: float = 0.0

# Cast in corso
var cast_slot: int = -1
var cast_time: float = 0.0
var cast_point := Vector2.ZERO
var pending_cast_slot: int = -1     # cammina fino a gittata poi lancia
var pending_cast_point := Vector2.ZERO

# Aggro delle torri (regola Dota): ultimo momento in cui questo eroe ha attaccato un eroe
var last_hero_attack_time: float = -100.0
var last_damaged_time: float = -100.0
var last_damaged_by_hero_time: float = -100.0

# Morte
var death_time: float = 0.0
var remove_after: float = 0.0


func is_hero() -> bool:
	return kind == Game.Kind.HERO


func is_creep() -> bool:
	return kind == Game.Kind.CREEP_MELEE or kind == Game.Kind.CREEP_RANGED or kind == Game.Kind.CREEP_SIEGE


func is_building() -> bool:
	return kind == Game.Kind.TOWER or kind == Game.Kind.ANCIENT or kind == Game.Kind.FOUNTAIN


func is_ranged() -> bool:
	return projectile_speed > 0.0


func is_stunned() -> bool:
	return stun_time > 0.0


func current_move_speed() -> float:
	var s := move_speed
	if slow_time > 0.0:
		s *= (1.0 - slow_pct)
	return s


func targetable() -> bool:
	return alive and kind != Game.Kind.FOUNTAIN


func compute_flags() -> int:
	var f := 0
	if state == State.MOVING: f |= F_MOVING
	if state == State.ATTACKING or windup > 0.0: f |= F_ATTACKING
	if state == State.CASTING: f |= F_CASTING
	if stun_time > 0.0: f |= F_STUNNED
	if not alive: f |= F_DEAD
	if invulnerable: f |= F_INVULN
	if slow_time > 0.0: f |= F_SLOWED
	if shield_time > 0.0: f |= F_SHIELDED
	if empower_time > 0.0: f |= F_EMPOWERED
	return f


func pos3(y: float = 0.0) -> Vector3:
	return Vector3(pos.x, y, pos.y)


func init_creep(k: int, t: int) -> void:
	kind = k
	team = t
	var d: Dictionary = Game.CREEPS[k]
	max_hp = d.hp
	hp = max_hp
	damage = d.damage
	attack_interval = d.attack_interval
	attack_range = d.attack_range
	attack_point = d.attack_point
	move_speed = d.move_speed
	armor = d.armor
	radius = d.radius
	projectile_speed = d.get("projectile_speed", 0.0)
	building_mult = d.get("building_mult", 1.0)


func init_building(sub: String, t: int) -> void:
	subtype = sub
	team = t
	match sub:
		"ancient": kind = Game.Kind.ANCIENT
		"fountain": kind = Game.Kind.FOUNTAIN
		_: kind = Game.Kind.TOWER
	var d: Dictionary = Game.BUILDINGS[sub]
	max_hp = d.hp
	hp = max_hp
	armor = d.armor
	damage = d.damage
	attack_interval = d.attack_interval
	attack_range = d.attack_range
	radius = d.radius
	attack_point = 0.0
	projectile_speed = Game.TOWER_PROJECTILE_SPEED if d.damage > 0.0 else 0.0
	move_speed = 0.0
	if sub == "fountain":
		invulnerable = true
