class_name Sim
extends RefCounted
## Simulazione autoritativa (gira solo sul server / in allenamento), a tick fisso.
## Non tocca la scena: produce `events` (array compatti) consumati da World e inviati ai client.
## Vedi wiki/systems/simulazione.md.

var time: float = 0.0
var tick_n: int = 0
var units: Dictionary = {}               # id -> Unit
var unit_list: Array[Unit] = []
var heroes: Dictionary = {}              # peer -> HeroData
var projectiles: Array = []              # Dictionary
var delayed: Array = []                  # effetti ritardati (meteora)
var events: Array = []                   # eventi del tick corrente
var buildings: Array = [{}, {}]          # team -> {subtype: id}
var game_over := false
var winner: int = -1
var training := true

var _next_id: int = 1
var _next_proj: int = 1
var _wave_timer: float = Game.FIRST_WAVE
var _wave_n: int = 0
var _grid: Dictionary = {}               # Vector2i -> Array[Unit]
var _cmd_queue: Array = []               # [peer, cmd, seq]
var last_seq: Dictionary = {}            # peer -> ultimo numero di sequenza eseguito
var last_seq_tick: Dictionary = {}       # peer -> tick in cui è stato eseguito
var _last_sent: Dictionary = {}          # id -> PackedInt32Array per la delta compression
var _rng := RandomNumberGenerator.new()

# Statistiche di prestazione
var last_tick_usec: int = 0


func _init(is_training: bool) -> void:
	training = is_training
	_rng.seed = 12345
	_spawn_buildings()


# ============================================================================
# Creazione
# ============================================================================

func _add_unit(u: Unit) -> Unit:
	u.id = _next_id
	_next_id += 1
	u.prev_pos = u.pos
	u.ai_timer = _rng.randf() * Game.AI_INTERVAL     # sfasa l'IA tra le unità
	units[u.id] = u
	unit_list.append(u)
	events.append(["spawn", u.id, u.kind, u.team, u.subtype, u.pos.x, u.pos.y, u.facing, u.owner_peer, u.max_hp])
	return u


func _spawn_buildings() -> void:
	for t in [Game.Team.RADIANT, Game.Team.DIRE]:
		for sub in ["t1", "t2", "ancient", "fountain"]:
			var u := Unit.new()
			u.init_building(sub, t)
			match sub:
				"t1": u.pos = MapData.T1[t]
				"t2": u.pos = MapData.T2[t]
				"ancient": u.pos = MapData.ANCIENT[t]
				"fountain": u.pos = MapData.FOUNTAIN[t]
			u.facing = MapData.team_dir(t).angle()
			_add_unit(u)
			buildings[t][sub] = u.id
	_update_invulnerability()


func add_hero(peer: int, team: int, pname: String) -> HeroData:
	var u := Unit.new()
	u.kind = Game.Kind.HERO
	u.team = team
	u.owner_peer = peer
	u.radius = Game.HERO.radius
	u.attack_range = Game.HERO.attack_range
	u.attack_point = Game.HERO.attack_point
	u.projectile_speed = Game.HERO.projectile_speed
	u.magic_resist = Game.HERO.magic_resist
	u.pos = _fountain_spawn(team)
	u.facing = MapData.team_dir(team).angle()
	var hd := HeroData.new()
	hd.peer = peer
	hd.team = team
	hd.player_name = pname
	hd.ability_points = 1
	u.max_hp = 1.0
	u.hp = 1.0
	hd.apply_stats(u)
	u.hp = u.max_hp
	u.mana = u.max_mana
	_add_unit(u)
	hd.unit_id = u.id
	heroes[peer] = hd
	return hd


func _fountain_spawn(team: int) -> Vector2:
	return MapData.FOUNTAIN[team] + MapData.team_dir(team) * 6.0


func _spawn_wave() -> void:
	_wave_n += 1
	for t in [Game.Team.RADIANT, Game.Team.DIRE]:
		var kinds: Array = []
		for i in Game.WAVE_MELEE:
			kinds.append(Game.Kind.CREEP_MELEE)
		for i in Game.WAVE_RANGED:
			kinds.append(Game.Kind.CREEP_RANGED)
		if Game.ENABLE_SIEGE and _wave_n % Game.SIEGE_EVERY == 0:
			kinds.append(Game.Kind.CREEP_SIEGE)
		var dir := MapData.team_dir(t)
		var nrm := MapData.lane_normal()
		for i in kinds.size():
			if unit_list.size() >= Game.MAX_UNITS:
				return
			var u := Unit.new()
			u.init_creep(kinds[i], t)
			if Game.ENABLE_CREEP_SCALING:
				var mult := 1.0 + Game.CREEP_SCALING * floorf(time / Game.CREEP_SCALING_EVERY)
				u.max_hp *= mult
				u.hp = u.max_hp
				u.damage *= mult
			var row := i / 3
			var col := (i % 3) - 1
			u.lane_offset = col * 1.8
			u.pos = MapData.CREEP_SPAWN[t] - dir * (row * 2.2) + nrm * u.lane_offset
			u.facing = dir.angle()
			_add_unit(u)
	events.append(["wave", _wave_n])


# ============================================================================
# Comandi
# ============================================================================

func queue_command(peer: int, cmd: Array, seq: int = -1) -> void:
	_cmd_queue.append([peer, cmd, seq])


func _process_commands() -> void:
	for entry in _cmd_queue:
		_handle_command(entry[0], entry[1])
		if entry[2] >= 0:
			last_seq[entry[0]] = entry[2]
			last_seq_tick[entry[0]] = tick_n
	_cmd_queue.clear()


func _handle_command(peer: int, cmd: Array) -> void:
	if cmd.is_empty() or not (cmd[0] is String):
		return
	var hd: HeroData = heroes.get(peer)
	if hd == null:
		return
	var u: Unit = units.get(hd.unit_id)
	if u == null:
		return
	match cmd[0]:
		"move":
			if cmd.size() < 3 or not u.alive: return
			_cancel_windup(u)
			u.target_id = 0
			u.attack_move = false
			u.pending_cast_slot = -1
			u.move_goal = MapData.clamp_walkable(Vector2(float(cmd[1]), float(cmd[2])), u.radius)
			u.has_move_goal = true
		"amove":
			if cmd.size() < 3 or not u.alive: return
			_cancel_windup(u)
			u.target_id = 0
			u.attack_move = true
			u.pending_cast_slot = -1
			u.move_goal = MapData.clamp_walkable(Vector2(float(cmd[1]), float(cmd[2])), u.radius)
			u.has_move_goal = true
		"attack":
			if cmd.size() < 2 or not u.alive: return
			var t: Unit = units.get(int(cmd[1]))
			if t == null or not t.targetable() or t == u:
				return
			# niente attacco agli alleati (deny = Fase 2)
			if t.team == u.team:
				return
			if u.target_id != t.id:
				_cancel_windup(u)
			u.target_id = t.id
			u.forced_target = true
			u.attack_move = false
			u.has_move_goal = false
			u.pending_cast_slot = -1
		"stop":
			_cancel_windup(u)
			u.target_id = 0
			u.has_move_goal = false
			u.attack_move = false
			u.pending_cast_slot = -1
			if u.state != Unit.State.CASTING:
				u.state = Unit.State.IDLE
		"cast":
			if cmd.size() < 4: return
			_try_cast(u, hd, int(cmd[1]), Vector2(float(cmd[2]), float(cmd[3])))
		"learn":
			if cmd.size() < 2: return
			_learn(u, hd, int(cmd[1]))
		"buy":
			if cmd.size() < 2: return
			_buy(u, hd, str(cmd[1]))
		"sell":
			if cmd.size() < 2: return
			_sell(u, hd, int(cmd[1]))
		"use":
			if cmd.size() < 2: return
			_use_item(u, hd, int(cmd[1]))
		"cheat":
			if training and cmd.size() >= 2:
				_cheat(u, hd, str(cmd[1]))


func _cancel_windup(u: Unit) -> void:
	if u.windup > 0.0:
		u.windup = 0.0
		u.attack_cd = 0.0


func _try_cast(u: Unit, hd: HeroData, slot: int, point: Vector2) -> void:
	if slot < 0 or slot > 3 or not u.alive or u.is_stunned() or u.state == Unit.State.CASTING:
		return
	var lvl: int = hd.ability_levels[slot]
	if lvl <= 0 or hd.cooldowns[slot] > 0.0:
		return
	var ab: Dictionary = Game.ABILITIES[slot]
	if u.mana < ab.mana[lvl - 1]:
		return
	_cancel_windup(u)
	if ab.target == "point" and ab.id == "meteor" and u.pos.distance_to(point) > ab.range:
		# cammina fino a gittata, poi lancia
		u.pending_cast_slot = slot
		u.pending_cast_point = point
		u.target_id = 0
		u.has_move_goal = false
		return
	_begin_cast(u, slot, point)


func _begin_cast(u: Unit, slot: int, point: Vector2) -> void:
	var ab: Dictionary = Game.ABILITIES[slot]
	u.state = Unit.State.CASTING
	u.cast_slot = slot
	u.cast_time = ab.cast_point
	u.cast_point = point
	u.pending_cast_slot = -1
	if point.distance_to(u.pos) > 0.1:
		u.facing = (point - u.pos).angle()
	events.append(["cast", u.id, slot])


func _execute_cast(u: Unit) -> void:
	var hd := _hero_of(u)
	if hd == null:
		return
	var slot := u.cast_slot
	var ab: Dictionary = Game.ABILITIES[slot]
	var lvl: int = hd.ability_levels[slot]
	var cost: float = ab.mana[lvl - 1]
	if u.mana < cost:
		return
	u.mana -= cost
	hd.cooldowns[slot] = ab.cooldown[lvl - 1]
	var dmg: float = ab.damage[lvl - 1]
	match ab.id:
		"fireball":
			var dir := (u.cast_point - u.pos)
			dir = Vector2.from_angle(u.facing) if dir.length() < 0.1 else dir.normalized()
			_spawn_projectile("fireball", u, 0, u.pos + dir * 1.0, dir, ab.speed, dmg, ab.range, ab.aoe)
		"blink":
			var dest := u.cast_point
			if dest.distance_to(u.pos) > ab.range:
				dest = u.pos + (dest - u.pos).normalized() * ab.range
			dest = MapData.clamp_walkable(dest, u.radius)
			events.append(["fx", "blink_out", u.pos.x, u.pos.y, u.id])
			u.pos = dest
			u.prev_pos = dest
			u.has_move_goal = false
			events.append(["fx", "blink_in", dest.x, dest.y, u.id])
		"shockwave":
			events.append(["fx", "shockwave", u.pos.x, u.pos.y, u.id])
			for t in _query(u.pos, ab.aoe + 1.0):
				if t.team != u.team and t.alive and not t.is_building() and t.pos.distance_to(u.pos) <= ab.aoe + t.radius:
					_damage(u, t, dmg, true, false)
					if t.alive:
						t.slow_time = ab.slow_time
						t.slow_pct = ab.slow
		"meteor":
			var p := u.cast_point
			events.append(["fx", "meteor_warn", p.x, p.y, u.id])
			delayed.append({"time": time + ab.delay, "type": "meteor", "pos": p, "src": u.id, "team": u.team,
				"dmg": dmg, "aoe": ab.aoe, "stun": ab.stun})


func _learn(u: Unit, hd: HeroData, slot: int) -> void:
	if slot < 0 or slot > 3 or hd.ability_points <= 0:
		return
	var ab: Dictionary = Game.ABILITIES[slot]
	var cur: int = hd.ability_levels[slot]
	if cur >= ab.max_level:
		return
	if slot == 3 and not Game.ENABLE_ULTIMATE:
		return
	if hd.level < required_level(slot, cur + 1):
		return
	hd.ability_levels[slot] = cur + 1
	hd.ability_points -= 1
	events.append(["fx", "learn", u.pos.x, u.pos.y, u.id])


static func required_level(slot: int, new_level: int) -> int:
	if slot == 3:
		return [6, 8, 10][clampi(new_level - 1, 0, 2)]
	return 2 * new_level - 1


func _buy(u: Unit, hd: HeroData, item: String) -> void:
	if not Game.ITEMS.has(item):
		return
	var d: Dictionary = Game.ITEMS[item]
	if d.get("phase2", false) and not Game.ENABLE_PHASE2_ITEMS:
		return
	if u.pos.distance_to(MapData.FOUNTAIN[u.team]) > Game.SHOP_RANGE:
		return
	if hd.gold < d.cost:
		return
	var slot := hd.items.find("")
	if slot < 0:
		return
	hd.gold -= d.cost
	hd.items[slot] = item
	hd.apply_stats(u)
	events.append(["fx", "buy", u.pos.x, u.pos.y, u.id])


func _sell(u: Unit, hd: HeroData, slot: int) -> void:
	if slot < 0 or slot > 5 or hd.items[slot] == "":
		return
	if u.pos.distance_to(MapData.FOUNTAIN[u.team]) > Game.SHOP_RANGE:
		return
	var d: Dictionary = Game.ITEMS[hd.items[slot]]
	hd.gold += d.cost / 2
	hd.items[slot] = ""
	hd.apply_stats(u)


func _use_item(u: Unit, hd: HeroData, slot: int) -> void:
	if slot < 0 or slot > 5 or not u.alive:
		return
	var item: String = hd.items[slot]
	if item == "":
		return
	var d: Dictionary = Game.ITEMS[item]
	if not d.get("consumable", false):
		return
	hd.items[slot] = ""
	if d.has("heal"):
		hd.regen_effects.append({"kind": "hp", "per_sec": d.heal / d.duration, "time": d.duration, "interruptible": true})
	if d.has("restore_mana"):
		hd.regen_effects.append({"kind": "mana", "per_sec": d.restore_mana / d.duration, "time": d.duration, "interruptible": false})
	events.append(["fx", "potion", u.pos.x, u.pos.y, u.id])


func _cheat(u: Unit, hd: HeroData, what: String) -> void:
	match what:
		"gold":
			hd.add_gold(1000)
		"level":
			if hd.level < Game.HERO.max_level:
				_add_xp(hd, Game.xp_to_next(hd.level) - hd.xp)
		"cooldowns":
			for i in 4:
				hd.cooldowns[i] = 0.0
			u.mana = u.max_mana
		"invulnerable":
			Game.cheats.invulnerable = not Game.cheats.invulnerable
		"kill_ancient":  # solo test automatici
			var a: Unit = units.get(buildings[1 - u.team].ancient)
			for sub in ["t1", "t2"]:
				var t: Unit = units.get(buildings[1 - u.team][sub])
				if t.alive:
					_kill(t, u)
			_update_invulnerability()
			if a.alive:
				_damage(u, a, a.hp + 99999.0, false, false, true)


# ============================================================================
# Tick
# ============================================================================

func tick() -> void:
	var t0 := Time.get_ticks_usec()
	var dt := Game.TICK
	time += dt
	tick_n += 1
	_process_commands()
	if game_over:
		last_tick_usec = Time.get_ticks_usec() - t0
		return

	_wave_timer -= dt
	if _wave_timer <= 0.0:
		_wave_timer += Game.WAVE_INTERVAL
		_spawn_wave()

	for u in unit_list:
		u.prev_pos = u.pos
	_rebuild_grid()
	var p0 := Time.get_ticks_usec()
	for u in unit_list:
		if u.alive:
			_update_unit(u, dt)
	var p1 := Time.get_ticks_usec()
	_update_projectiles(dt)
	_update_delayed()
	var p2 := Time.get_ticks_usec()
	_separate()
	var p3 := Time.get_ticks_usec()
	_update_regen(dt)
	_update_heroes(dt)
	_cleanup()
	last_tick_usec = Time.get_ticks_usec() - t0
	if Game.prof_enabled:
		Game.prof_add("t_griglia", p0 - t0)
		Game.prof_add("t_unita", p1 - p0)
		Game.prof_add("t_proiettili", p2 - p1)
		Game.prof_add("t_separazione", p3 - p2)
		Game.prof_add("t_resto", Time.get_ticks_usec() - p3)


func next_wave_in() -> float:
	return _wave_timer


func wave_number() -> int:
	return _wave_n


func _update_unit(u: Unit, dt: float) -> void:
	if u.slow_time > 0.0:
		u.slow_time -= dt
	if u.attack_cd > 0.0:
		u.attack_cd -= dt
	if u.stun_time > 0.0:
		u.stun_time -= dt
		u.windup = 0.0
		if u.state == Unit.State.CASTING:
			u.cast_slot = -1
		u.state = Unit.State.IDLE
		return

	if u.state == Unit.State.CASTING:
		u.cast_time -= dt
		if u.cast_time <= 0.0:
			_execute_cast(u)
			u.state = Unit.State.IDLE
			u.cast_slot = -1
		return

	if u.windup > 0.0:
		u.windup -= dt
		if u.windup <= 0.0:
			_attack_hit(u)
		return

	if u.is_building():
		_building_ai(u, dt)
		return
	if u.is_creep():
		_creep_ai(u, dt)
	elif u.is_hero():
		_hero_ai(u, dt)

	# Esecuzione: bersaglio > movimento
	var t: Unit = units.get(u.target_id) if u.target_id != 0 else null
	if t != null and (not t.targetable()):
		u.target_id = 0
		t = null
		if u.is_hero() and not u.attack_move:
			u.state = Unit.State.IDLE
	if t != null:
		var reach := u.attack_range + u.radius + t.radius
		if u.pos.distance_to(t.pos) <= reach:
			u.facing = (t.pos - u.pos).angle()
			if u.attack_cd <= 0.0:
				u.windup = maxf(u.attack_point, 0.01)
				u.attack_cd = u.attack_interval
				u.state = Unit.State.ATTACKING
				events.append(["attack", u.id, t.id])
			elif u.state == Unit.State.MOVING:
				u.state = Unit.State.ATTACKING
		else:
			_move_towards(u, t.pos, dt)
		return
	if u.has_move_goal:
		if _move_towards(u, u.move_goal, dt):
			u.has_move_goal = false
			u.attack_move = false
			u.state = Unit.State.IDLE
		return
	if u.is_creep():
		var goal := MapData.closest_on_lane(u.pos) + MapData.team_dir(u.team) * 8.0 + MapData.lane_normal() * u.lane_offset
		_move_towards(u, goal, dt)
		return
	u.state = Unit.State.IDLE


func _move_towards(u: Unit, goal: Vector2, dt: float) -> bool:
	var to := goal - u.pos
	var dist := to.length()
	var step := u.current_move_speed() * dt
	u.state = Unit.State.MOVING
	if dist < 0.001:
		return true
	u.facing = to.angle()
	var reached := dist <= step
	var np := goal if reached else u.pos + to / dist * step
	np = _push_out_of_buildings(np, u.radius, to / dist)
	u.pos = MapData.clamp_walkable(np, u.radius)
	return reached


func _push_out_of_buildings(p: Vector2, r: float, dir: Vector2) -> Vector2:
	for side in buildings:
		for sub in side:
			var b: Unit = units[side[sub]]
			if not b.alive and b.kind != Game.Kind.ANCIENT:
				continue
			var d := p - b.pos
			var min_d := b.radius + r
			var l := d.length()
			if l < min_d:
				var n := d / l if l > 0.001 else Vector2.RIGHT
				# scivola lungo il bordo verso il lato della direzione di marcia
				var tangent := Vector2(-n.y, n.x)
				if tangent.dot(dir) < 0.0:
					tangent = -tangent
				p = b.pos + n * min_d + tangent * 0.05
	return p


# --- IA ----------------------------------------------------------------------

func _target_valid(u: Unit, t: Unit, max_range: float) -> bool:
	return t != null and t.targetable() and t.team != u.team and u.pos.distance_to(t.pos) <= max_range + t.radius


func _creep_ai(u: Unit, dt: float) -> void:
	u.ai_timer -= dt
	if u.ai_timer > 0.0:
		return
	u.ai_timer += Game.AI_INTERVAL
	var cur: Unit = units.get(u.target_id) if u.target_id != 0 else null
	var keep := _target_valid(u, cur, Game.CREEP_AGGRO + 2.0) and u.pos.distance_to(u.leash_origin) <= Game.CREEP_LEASH
	# Priorità 1: eroe nemico che ha appena attaccato un nostro eroe
	var best: Unit = null
	var best_score := INF
	for t in _query(u.pos, Game.CREEP_AGGRO):
		if t.team == u.team or not t.targetable():
			continue
		var d := u.pos.distance_to(t.pos)
		if d > Game.CREEP_AGGRO + t.radius:
			continue
		var prio := 3.0
		if t.is_hero() and time - t.last_hero_attack_time < 2.0:
			prio = 0.0
		elif t.is_creep():
			prio = 1.0
		elif t.is_building():
			prio = 2.0
		var score := prio * 1000.0 + d
		if score < best_score:
			best_score = score
			best = t
	if keep and not (best != null and best_score < 1000.0 and best != cur):
		return
	if best != null:
		if u.target_id == 0:
			u.leash_origin = u.pos
		u.target_id = best.id
	else:
		u.target_id = 0


func _hero_ai(u: Unit, _dt: float) -> void:
	# Lancio in attesa di gittata
	if u.pending_cast_slot >= 0:
		var ab: Dictionary = Game.ABILITIES[u.pending_cast_slot]
		if u.pos.distance_to(u.pending_cast_point) <= ab.range:
			_begin_cast(u, u.pending_cast_slot, u.pending_cast_point)
		else:
			_move_towards(u, u.pending_cast_point, Game.TICK)
			u.target_id = 0
			u.has_move_goal = false
		return
	# Attacco-movimento: cerca il nemico più vicino entro l'aggro.
	# Da fermo (come in Dota) attacca da solo i nemici entro la propria gittata.
	var idle := u.target_id == 0 and not u.has_move_goal and u.state == Unit.State.IDLE
	if (u.attack_move and u.target_id == 0) or idle:
		var search := Game.CREEP_AGGRO if u.attack_move else u.attack_range + 1.0
		var best: Unit = null
		var bd := INF
		for t in _query(u.pos, search):
			if t.team != u.team and t.targetable() and not t.invulnerable:
				var d: float = u.pos.distance_to(t.pos) - t.radius
				if d < bd and d <= search:
					bd = d
					best = t
		if best != null:
			u.target_id = best.id
			u.forced_target = false


func _building_ai(u: Unit, dt: float) -> void:
	if u.damage <= 0.0:
		return
	u.ai_timer -= dt
	var cur: Unit = units.get(u.target_id) if u.target_id != 0 else null
	if u.ai_timer <= 0.0:
		u.ai_timer += Game.AI_INTERVAL
		var rng := u.attack_range
		# Regola Dota: un eroe nemico che attacca un nostro eroe nel raggio diventa il bersaglio
		var aggro: Unit = null
		var best: Unit = null
		var best_score := INF
		for t in _query(u.pos, rng + 1.0):
			if t.team == u.team or not t.targetable() or t.is_building():
				continue
			var d := u.pos.distance_to(t.pos)
			if d > rng + t.radius:
				continue
			if t.is_hero() and time - t.last_hero_attack_time < 1.0:
				aggro = t
			var score := d + (100.0 if t.is_hero() else 0.0)
			if score < best_score:
				best_score = score
				best = t
		if aggro != null:
			cur = aggro
		elif not _target_valid(u, cur, rng):
			cur = best
		u.target_id = cur.id if cur != null else 0
	if cur == null or not _target_valid(u, cur, u.attack_range):
		u.target_id = 0
		u.state = Unit.State.IDLE
		return
	if u.attack_cd <= 0.0:
		u.attack_cd = u.attack_interval
		u.state = Unit.State.ATTACKING
		events.append(["attack", u.id, cur.id])
		_attack_hit(u)


# --- Combattimento -----------------------------------------------------------

func _attack_hit(u: Unit) -> void:
	var t: Unit = units.get(u.target_id) if u.target_id != 0 else null
	if t == null or not t.targetable():
		return
	if u.is_ranged():
		var ptype := "bolt"
		if u.is_building():
			ptype = "fountain" if u.kind == Game.Kind.FOUNTAIN else "tower"
		elif u.kind == Game.Kind.CREEP_RANGED:
			ptype = "creep_bolt"
		elif u.kind == Game.Kind.CREEP_SIEGE:
			ptype = "siege"
		var start := u.pos + Vector2.from_angle(u.facing) * (u.radius + 0.3)
		_spawn_projectile(ptype, u, t.id, start, Vector2.ZERO, u.projectile_speed, u.damage, 0.0, 0.0)
	else:
		_damage(u, t, u.damage, false, true)


func _spawn_projectile(ptype: String, src: Unit, target_id: int, start: Vector2, dir: Vector2,
		speed: float, dmg: float, max_dist: float, aoe: float) -> void:
	var p := {"id": _next_proj, "type": ptype, "src": src.id, "team": src.team, "target": target_id,
		"pos": start, "dir": dir, "speed": speed, "dmg": dmg, "dist": 0.0, "max_dist": max_dist, "aoe": aoe,
		"building_mult": src.building_mult}
	_next_proj += 1
	projectiles.append(p)
	events.append(["proj", p.id, ptype, src.id, target_id, start.x, start.y, dir.x, dir.y, speed])


func _update_projectiles(dt: float) -> void:
	var i := 0
	while i < projectiles.size():
		var p: Dictionary = projectiles[i]
		var done := false
		var step: float = p.speed * dt
		if p.target != 0:
			var t: Unit = units.get(p.target)
			if t == null or not t.alive:
				done = true
				events.append(["proj_end", p.id, p.pos.x, p.pos.y, 0])
			else:
				var to: Vector2 = t.pos - p.pos
				if to.length() <= step + t.radius * 0.5:
					done = true
					var src: Unit = units.get(p.src)
					_damage(src, t, p.dmg, false, true, false, p.building_mult)
					events.append(["proj_end", p.id, t.pos.x, t.pos.y, 1])
				else:
					p.pos += to.normalized() * step
		else:
			p.pos += p.dir * step
			p.dist += step
			var hit: Unit = null
			for t in _query(p.pos, 2.0):
				if t.team != p.team and t.alive and not t.is_building() and t.pos.distance_to(p.pos) <= t.radius + 0.6:
					hit = t
					break
			if hit != null or p.dist >= p.max_dist:
				done = true
				_explode(p)
		if done:
			projectiles.remove_at(i)
		else:
			i += 1


func _explode(p: Dictionary) -> void:
	var src: Unit = units.get(p.src)
	events.append(["proj_end", p.id, p.pos.x, p.pos.y, 1])
	events.append(["fx", "explosion", p.pos.x, p.pos.y, p.src])
	for t in _query(p.pos, p.aoe + 1.0):
		if t.team != p.team and t.alive and not t.is_building() and t.pos.distance_to(p.pos) <= p.aoe + t.radius:
			_damage(src, t, p.dmg, true, false)


func _update_delayed() -> void:
	var i := 0
	while i < delayed.size():
		var e: Dictionary = delayed[i]
		if time >= e.time:
			delayed.remove_at(i)
			var src: Unit = units.get(e.src)
			events.append(["fx", "meteor_hit", e.pos.x, e.pos.y, e.src])
			for t in _query(e.pos, e.aoe + 1.0):
				if t.team != e.team and t.alive and not t.is_building() and t.pos.distance_to(e.pos) <= e.aoe + t.radius:
					_damage(src, t, e.dmg, true, false)
					if t.alive:
						t.stun_time = maxf(t.stun_time, e.stun)
		else:
			i += 1


## Applica danno. magic = danno magico (resistenza magica), altrimenti fisico (armatura).
func _damage(src: Unit, t: Unit, amount: float, magic: bool, is_attack: bool, force: bool = false, bmult: float = -1.0) -> void:
	if not t.alive:
		return
	if t.invulnerable and not force:
		return
	if training and t.is_hero() and Game.cheats.invulnerable:
		return
	var mult := (1.0 - t.magic_resist) if magic else Game.armor_multiplier(t.armor)
	if t.is_building():
		var bm := bmult if bmult > 0.0 else (src.building_mult if src != null else 1.0)
		amount *= bm
	var dmg := amount * mult
	t.hp -= dmg
	t.last_damaged_time = time
	var src_hero := src != null and src.is_hero()
	if src_hero:
		var hd := _hero_of(src)
		if force:
			pass   # danni forzati (trucchi/test): non contano nelle statistiche
		elif t.is_hero():
			src.last_hero_attack_time = time
			t.last_damaged_by_hero_time = time
			if hd: hd.dmg_heroes += dmg
			var vhd := _hero_of(t)
			if vhd:
				vhd.regen_effects = vhd.regen_effects.filter(func(e): return not e.interruptible)
		elif t.is_building() and hd:
			hd.dmg_buildings += dmg
		if is_attack and src.lifesteal > 0.0 and src.alive:
			src.hp = minf(src.max_hp, src.hp + dmg * src.lifesteal)
	if src_hero or t.is_hero():
		events.append(["dmg", t.id, int(round(dmg)), 1 if (magic and not is_attack) else 0, src.id if src else 0])
	if t.hp <= 0.0:
		_kill(t, src)


func _kill(u: Unit, killer: Unit) -> void:
	u.alive = false
	u.hp = 0.0
	u.state = Unit.State.DEAD
	u.target_id = 0
	u.windup = 0.0
	u.has_move_goal = false
	u.death_time = time
	events.append(["death", u.id, killer.id if killer else 0])
	var killer_hd: HeroData = _hero_of(killer) if killer != null else null
	var enemy_team := 1 - u.team
	if u.is_creep():
		u.remove_after = time + 2.5
		if killer_hd != null and killer.team != u.team:
			var g := _rng.randi_range(Game.GOLD_LAST_HIT.x, Game.GOLD_LAST_HIT.y)
			killer_hd.add_gold(g)
			killer_hd.last_hits += 1
			events.append(["gold", killer.id, g, u.pos.x, u.pos.y])
		_share_xp(u.pos, enemy_team, Game.XP_CREEP)
	elif u.kind == Game.Kind.TOWER:
		for hd in heroes.values():
			if hd.team == enemy_team:
				hd.add_gold(Game.GOLD_TOWER)
				var hu: Unit = units.get(hd.unit_id)
				if hu: events.append(["gold", hu.id, Game.GOLD_TOWER, hu.pos.x, hu.pos.y])
		_share_xp(u.pos, enemy_team, Game.XP_TOWER)
		events.append(["fx", "tower_destroyed", u.pos.x, u.pos.y, u.id])
		events.append(["notify", "tower", u.team])
		_update_invulnerability()
	elif u.kind == Game.Kind.ANCIENT:
		events.append(["fx", "ancient_destroyed", u.pos.x, u.pos.y, u.id])
		game_over = true
		winner = enemy_team
		events.append(["game_over", winner])
	elif u.is_hero():
		var hd := _hero_of(u)
		if hd:
			hd.deaths += 1
			hd.respawn_timer = Game.RESPAWN_BASE + Game.RESPAWN_PER_LVL * hd.level
			hd.regen_effects.clear()
			if killer_hd != null and killer_hd != hd:
				killer_hd.kills += 1
				killer_hd.add_gold(Game.GOLD_HERO_KILL)
				events.append(["gold", killer.id, Game.GOLD_HERO_KILL, u.pos.x, u.pos.y])
			_share_xp(u.pos, enemy_team, Game.XP_HERO_BASE + Game.XP_HERO_PER_LVL * hd.level)
			events.append(["notify", "hero_kill", u.team])


func _share_xp(at: Vector2, team: int, amount: int) -> void:
	var receivers: Array = []
	for hd in heroes.values():
		if hd.team != team:
			continue
		var hu: Unit = units.get(hd.unit_id)
		if hu and hu.alive and hu.pos.distance_to(at) <= Game.XP_RANGE:
			receivers.append(hd)
	for hd in receivers:
		_add_xp(hd, amount / receivers.size())


func _add_xp(hd: HeroData, amount: int) -> void:
	if hd.level >= Game.HERO.max_level:
		return
	hd.xp += amount
	var u: Unit = units.get(hd.unit_id)
	while hd.level < Game.HERO.max_level and hd.xp >= Game.xp_to_next(hd.level):
		hd.xp -= Game.xp_to_next(hd.level)
		hd.level += 1
		hd.ability_points += 1
		if u:
			hd.apply_stats(u)
			events.append(["fx", "levelup", u.pos.x, u.pos.y, u.id])
	if hd.level >= Game.HERO.max_level:
		hd.xp = 0


func _update_invulnerability() -> void:
	for t in [0, 1]:
		var t1: Unit = units.get(buildings[t].get("t1", 0))
		var t2: Unit = units.get(buildings[t].get("t2", 0))
		var anc: Unit = units.get(buildings[t].get("ancient", 0))
		if t2: t2.invulnerable = t1 != null and t1.alive
		if anc: anc.invulnerable = t2 != null and t2.alive


# --- Rigenerazione, eroi, pulizia -------------------------------------------

func _update_regen(dt: float) -> void:
	for u in unit_list:
		if not u.alive:
			continue
		if u.is_hero():
			u.hp = minf(u.max_hp, u.hp + u.hp_regen * dt)
			u.mana = minf(u.max_mana, u.mana + u.mana_regen * dt)
	# Fontane: rigenerazione rapida degli alleati vicini
	for t in [0, 1]:
		var f: Unit = units[buildings[t].fountain]
		for u in _query(f.pos, Game.FOUNTAIN_AURA):
			if u.team == t and u.alive and (u.is_hero() or u.is_creep()) and u.pos.distance_to(f.pos) <= Game.FOUNTAIN_AURA:
				u.hp = minf(u.max_hp, u.hp + u.max_hp * Game.FOUNTAIN_REGEN * dt)
				u.mana = minf(u.max_mana, u.mana + u.max_mana * Game.FOUNTAIN_REGEN * dt)


func _update_heroes(dt: float) -> void:
	for hd in heroes.values():
		var u: Unit = units.get(hd.unit_id)
		if u == null:
			continue
		hd.add_gold(Game.GOLD_PER_SEC * dt)
		for i in 4:
			if hd.cooldowns[i] > 0.0:
				hd.cooldowns[i] = maxf(0.0, hd.cooldowns[i] - dt)
		var j := 0
		while j < hd.regen_effects.size():
			var e: Dictionary = hd.regen_effects[j]
			if e.kind == "hp":
				u.hp = minf(u.max_hp, u.hp + e.per_sec * dt)
			else:
				u.mana = minf(u.max_mana, u.mana + e.per_sec * dt)
			e.time -= dt
			if e.time <= 0.0:
				hd.regen_effects.remove_at(j)
			else:
				j += 1
		if not u.alive:
			hd.respawn_timer -= dt
			if hd.respawn_timer <= 0.0:
				hd.respawn_timer = 0.0
				u.alive = true
				u.hp = u.max_hp
				u.mana = u.max_mana
				u.state = Unit.State.IDLE
				u.stun_time = 0.0
				u.slow_time = 0.0
				u.pos = _fountain_spawn(u.team)
				u.prev_pos = u.pos
				u.target_id = 0
				u.has_move_goal = false
				events.append(["respawn", u.id, u.pos.x, u.pos.y])


func _cleanup() -> void:
	var i := 0
	while i < unit_list.size():
		var u := unit_list[i]
		if not u.alive and u.is_creep() and time >= u.remove_after:
			unit_list.remove_at(i)
			units.erase(u.id)
			_last_sent.erase(u.id)
			events.append(["despawn", u.id])
		else:
			i += 1


func _hero_of(u: Unit) -> HeroData:
	if u == null or not u.is_hero():
		return null
	return heroes.get(u.owner_peer)


func hero_unit(peer: int) -> Unit:
	var hd: HeroData = heroes.get(peer)
	return units.get(hd.unit_id) if hd else null


# --- Griglia spaziale e separazione -----------------------------------------

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Game.GRID_CELL), floori(p.y / Game.GRID_CELL))


func _rebuild_grid() -> void:
	for k in _grid:
		(_grid[k] as Array).clear()
	for u in unit_list:
		if not u.alive:
			continue
		var c := _cell(u.pos)
		var arr: Array = _grid.get(c, [])
		if arr.is_empty() and not _grid.has(c):
			_grid[c] = arr
		arr.append(u)


## Unità vive entro (circa) r da p. Usa la griglia del tick corrente.
func _query(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c0 := _cell(p - Vector2(r, r))
	var c1 := _cell(p + Vector2(r, r))
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var arr: Array = _grid.get(Vector2i(x, y), [])
			for u in arr:
				if u.alive:
					out.append(u)
	return out


func query_units(p: Vector2, r: float) -> Array:
	return _query(p, r)


const _HALF_NEIGHBORS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const _EMPTY: Array = []

## Separazione tra unità vicine: coppie confrontate solo tra celle adiacenti (metà vicinato,
## nessuna coppia ripetuta, nessuna allocazione). Il controllo dei bordi è fatto una volta per unità spinta.
func _separate() -> void:
	var pushed: Array[Unit] = []
	for c in _grid:
		var a_arr: Array = _grid[c]
		if a_arr.is_empty():
			continue
		for off in _HALF_NEIGHBORS:
			var same: bool = off == Vector2i.ZERO
			var b_arr: Array = a_arr if same else _grid.get(c + off, _EMPTY)
			if b_arr.is_empty():
				continue
			for i in a_arr.size():
				var a: Unit = a_arr[i]
				if a.kind >= Game.Kind.TOWER:
					continue
				for j in range(i + 1 if same else 0, b_arr.size()):
					var b: Unit = b_arr[j]
					if b.kind >= Game.Kind.TOWER:
						continue
					var dx: float = b.pos.x - a.pos.x
					var dy: float = b.pos.y - a.pos.y
					var min_d: float = a.radius + b.radius
					var l2 := dx * dx + dy * dy
					if l2 >= min_d * min_d:
						continue
					var l := sqrt(l2)
					var n2 := Vector2(dx / l, dy / l) if l > 0.0001 else Vector2.from_angle(a.id * 1.7)
					var push := (min_d - l) * 0.5
					# gli eroi spingono di più di quanto vengano spinti
					var wa := 0.25 if a.kind == Game.Kind.HERO else 1.0
					var wb := 0.25 if b.kind == Game.Kind.HERO else 1.0
					a.pos -= n2 * push * wa
					b.pos += n2 * push * wb
					pushed.append(a)
					pushed.append(b)
	for u in pushed:
		u.pos = MapData.clamp_walkable(u.pos, u.radius)


# ============================================================================
# Snapshot (rete)
# ============================================================================

const M_POS := 1
const M_HP := 2
const M_MANA := 4
const M_FLAGS := 8
const M_MAX := 16

## Snapshot compatto. full=false invia solo i campi cambiati dall'ultimo snapshot.
func build_snapshot(full: bool) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(tick_n)
	buf.put_u16(0)  # segnaposto per il conteggio
	var count := 0
	for u in unit_list:
		var qx := clampi(roundi(u.pos.x * 100.0), -32767, 32767)
		var qy := clampi(roundi(u.pos.y * 100.0), -32767, 32767)
		var qf := posmod(roundi(u.facing / TAU * 256.0), 256)
		var qhp := clampi(ceili(u.hp), 0, 65535)
		var qmana := clampi(roundi(u.mana), 0, 65535)
		var fl := u.compute_flags()
		var qmax := clampi(roundi(u.max_hp), 0, 65535)
		var qmaxm := clampi(roundi(u.max_mana), 0, 65535)
		var last: PackedInt32Array = _last_sent.get(u.id, PackedInt32Array())
		var mask := 0
		if full or last.is_empty():
			mask = M_POS | M_HP | M_FLAGS | M_MAX | (M_MANA if u.is_hero() else 0)
		else:
			if last[0] != qx or last[1] != qy or last[2] != qf: mask |= M_POS
			if last[3] != qhp: mask |= M_HP
			if last[4] != qmana: mask |= M_MANA
			if last[5] != fl: mask |= M_FLAGS
			if last[6] != qmax or last[7] != qmaxm: mask |= M_MAX
		if mask == 0:
			continue
		count += 1
		buf.put_u16(u.id)
		buf.put_u8(mask)
		if mask & M_POS:
			buf.put_16(qx)
			buf.put_16(qy)
			buf.put_u8(qf)
		if mask & M_HP: buf.put_u16(qhp)
		if mask & M_MANA: buf.put_u16(qmana)
		if mask & M_FLAGS: buf.put_u8(fl)
		if mask & M_MAX:
			buf.put_u16(qmax)
			buf.put_u16(qmaxm)
		_last_sent[u.id] = PackedInt32Array([qx, qy, qf, qhp, qmana, fl, qmax, qmaxm])
	buf.seek(4)
	buf.put_u16(count)
	return buf.data_array


## Stato iniziale completo per un client appena entrato: eventi di spawn per tutte le unità.
func spawn_events_for_all() -> Array:
	var out: Array = []
	for u in unit_list:
		out.append(["spawn", u.id, u.kind, u.team, u.subtype, u.pos.x, u.pos.y, u.facing, u.owner_peer, u.max_hp])
		if not u.alive:
			out.append(["death", u.id, 0])
	return out
