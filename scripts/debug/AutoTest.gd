class_name AutoTest
extends Node
## Test automatici e strumenti di verifica (argomenti dopo "--"):
##   --autotest-training            partita di allenamento simulata con verifiche -> AUTOTEST OK/FAIL
##   --autotest-net-host [--port P] [--duration S] [--expect-disconnect]
##   --autotest-net-client [--port P] [--duration S] [--netsim latency=..,jitter=..,loss=..]
##   --shots <cartella>             sequenza di screenshot (menu, informazioni, partita, abilità, torre, negozio, animazioni, vittoria)
##   --views <cartella> [--views-quality Q]  inquadrature fisse per la revisione grafica (guado, corsia, basi...)
##   --benchmark [--bench-seconds S] [--bench-preset Q] [--bench-at x,y] [--bench-hero gorm] scenario di carico per ogni preset -> benchmark_results.md
##   --soak [--soak-minutes M]      partita lunga accelerata: memoria, nodi, creep incastrati, errori
##   --duel [--duel-runs N] [--duel-level L] [--duel-pair a,b] [--duel-ban eroeN,..] [--duel-stats]
##                                  duelli 1 contro 1 in simulazione pura (IA semplice) per confrontare gli eroi
##                                  (DUEL_TRACE=1 nell'ambiente stampa gli eventi di ogni duello)
## Vedi wiki/systems/test-automatici.md.

var main: Node
var failures: Array[String] = []
var _t0 := 0


static func wants_autotest() -> bool:
	for a in ["--autotest-training", "--autotest-net-host", "--autotest-net-client", "--shots", "--views", "--benchmark", "--soak", "--duel"]:
		if Game.has_arg(a):
			return true
	return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	var watchdog := float(Game.arg_value("--watchdog", "900"))
	get_tree().create_timer(watchdog, true, false, true).timeout.connect(func():
		print("AUTOTEST FAIL: watchdog scaduto dopo %d s" % int(watchdog))
		get_tree().quit(2))
	if Game.has_arg("--autotest-training"):
		_run_training.call_deferred()
	elif Game.has_arg("--autotest-net-host"):
		_run_net_host.call_deferred()
	elif Game.has_arg("--autotest-net-client"):
		_run_net_client.call_deferred()
	elif Game.has_arg("--shots"):
		_run_shots.call_deferred()
	elif Game.has_arg("--views"):
		_run_views.call_deferred()
	elif Game.has_arg("--benchmark"):
		_run_benchmark.call_deferred()
	elif Game.has_arg("--soak"):
		_run_soak.call_deferred()
	elif Game.has_arg("--duel"):
		_run_duel.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("  [ok] ", what)
	else:
		print("  [FALLITO] ", what)
		failures.append(what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## Attende finché il tempo di simulazione raggiunge t (con timeout reale).
func _wait_sim(w: World, t: float, real_timeout: float = 120.0) -> void:
	var start := Time.get_ticks_msec()
	while is_instance_valid(w) and w.game_time < t and (Time.get_ticks_msec() - start) < real_timeout * 1000.0:
		await get_tree().process_frame


func _set_speed(s: float) -> void:
	Game.base_time_scale = s
	Engine.time_scale = s


func _finish(tag: String) -> void:
	var secs := (Time.get_ticks_msec() - _t0) / 1000.0
	if failures.is_empty():
		print("%s OK (%.1f s)" % [tag, secs])
		Game.quit(0)
	else:
		print("%s FAIL: %s" % [tag, "; ".join(failures)])
		Game.quit(1)


func _nearest_enemy(w: World, from: Vector2, team: int, max_d: float, creeps_only: bool = true) -> Unit:
	var best: Unit = null
	var bd := max_d
	for u in w.units.values():
		if u.team == team or not u.alive or u.kind == Game.Kind.FOUNTAIN:
			continue
		if creeps_only and not u.is_creep():
			continue
		var d: float = u.pos.distance_to(from)
		if d < bd:
			bd = d
			best = u
	return best


# ============================================================================
# Allenamento
# ============================================================================

func _run_training() -> void:
	print("== AUTOTEST allenamento")
	Game.settings.hero = "kael"     # il percorso principale verifica Kael; Peppino ha una sezione sua (non salvato)
	var w: World = main.start_training()
	_set_speed(float(Game.arg_value("--timescale", "6")))
	await get_tree().process_frame
	var sim := w.sim
	var hd := w.local_hero_data()
	var u := w.local_hero_unit()
	check(sim.unit_list.size() == 9, "8 edifici + eroe creati (%d unità)" % sim.unit_list.size())
	var d_t2: Unit = sim.units[sim.buildings[1].t2]
	var d_anc: Unit = sim.units[sim.buildings[1].ancient]
	check(d_t2.invulnerable and d_anc.invulnerable, "protezione a cascata attiva (T2 e Antico invulnerabili)")

	# Negozio alla fontana
	w.send_command(["buy", "sword"])
	await _wait_sim(w, 0.5)
	check(hd.items.has("sword") and int(hd.gold) <= 205, "acquisto Spada lunga (oro rimasto %d)" % int(hd.gold))
	check(absf(u.damage - (Game.hero_def("kael").damage + 15.0)) < 0.01, "statistiche aggiornate dall'oggetto (danno %.0f)" % u.damage)
	w.send_command(["learn", 2])   # Onda d'urto
	await _wait_sim(w, 1.0)
	check(hd.ability_levels[2] == 1, "abilità E appresa con il punto iniziale")

	# Ondate
	await _wait_sim(w, Game.FIRST_WAVE + 1.0)
	var creeps := sim.unit_list.filter(func(x): return x.is_creep()).size()
	check(creeps == (Game.WAVE_MELEE + Game.WAVE_RANGED) * 2, "prima ondata generata (%d creep)" % creeps)

	# Vai in corsia e combatti
	w.send_command(["amove", -8.0, 8.0])
	var cast_done := false
	var shock_done := false
	var mana_before := 0.0
	var deaths_seen := 0
	var t_end := 140.0
	while w.game_time < t_end:
		await get_tree().process_frame
		if not is_instance_valid(w):
			break
		u = w.local_hero_unit()
		if not u.alive:
			continue
		var e := _nearest_enemy(w, u.pos, u.team, 13.0)
		if e and not cast_done and hd.cooldowns[0] <= 0.0 and u.mana >= 80.0:
			mana_before = u.mana
			w.send_command(["cast", 0, e.pos.x, e.pos.y, 0])
			await _wait_sim(w, w.game_time + 0.6)
			check(hd.cooldowns[0] > 0.0 and u.mana < mana_before, "Palla di fuoco: mana consumato e ricarica avviata")
			cast_done = true
			w.send_command(["amove", -8.0, 8.0])
		if e and cast_done and not shock_done and u.pos.distance_to(e.pos) < 5.0 and hd.cooldowns[2] <= 0.0:
			w.send_command(["cast", 2, u.pos.x, u.pos.y, 0])
			await _wait_sim(w, w.game_time + 0.5)
			check(hd.cooldowns[2] > 0.0, "Onda d'urto lanciata")
			shock_done = true
			w.send_command(["amove", -8.0, 8.0])
		if hd.ability_points > 0:
			for slot in [0, 1, 2]:
				w.send_command(["learn", slot])
		# last hit: colpisce i creep nemici quasi morti
		var lh: Unit = null
		for c in w.units.values():
			if c.is_creep() and c.alive and c.team != u.team and c.pos.distance_to(u.pos) < 12.0 \
					and c.hp <= u.damage * Game.armor_multiplier(c.armor) * 1.4:
				lh = c
				break
		if lh and u.target_id != lh.id:
			w.send_command(["attack", lh.id])
		elif not u.has_move_goal and u.target_id == 0 and u.state == Unit.State.IDLE:
			w.send_command(["amove", -2.0 + randf() * 4.0, 2.0 - randf() * 4.0])
	check(cast_done, "almeno una Palla di fuoco lanciata")
	check(hd.last_hits > 0, "last hit eseguiti (%d)" % hd.last_hits)
	check(hd.xp > 0 or hd.level > 1, "esperienza guadagnata (livello %d, xp %d)" % [hd.level, hd.xp])
	check(hd.level >= 2, "salita di livello")
	check(hd.gold_total > 150, "oro guadagnato in partita (%d)" % int(hd.gold_total))
	var damaged_tower := false
	for t in [0, 1]:
		var t1: Unit = sim.units[sim.buildings[t].t1]
		if t1.hp < t1.max_hp:
			damaged_tower = true
	check(damaged_tower or sim.wave_number() >= 4, "le torri vengono attaccate / ondate regolari (ondata %d)" % sim.wave_number())

	# --- Fase 2 ---
	var sieges := w.sim.unit_list.filter(func(x): return x.kind == Game.Kind.CREEP_SIEGE).size()
	check(not Game.ENABLE_SIEGE or sieges > 0 or w.sim.wave_number() < 5, "creep d'assedio nella 5ª ondata (%d)" % sieges)
	# Deny: un proprio creep sotto il 50%
	if Game.ENABLE_DENY:
		# creep appena nato vicino alla propria base, lontano dai nemici
		w.sim._spawn_wave()
		await _wait_sim(w, w.game_time + 0.1)
		var ally: Unit = null
		var best_d := INF
		for c in w.sim.unit_list:
			if c.is_creep() and c.alive and c.team == u.team:
				var dd: float = c.pos.distance_to(MapData.CREEP_SPAWN[u.team])
				if dd < best_d:
					best_d = dd
					ally = c
		if ally:
			ally.hp = minf(ally.hp, 15.0)
			u.pos = ally.pos + Vector2(3, 0)
			u.prev_pos = u.pos
			w.send_command(["attack", ally.id])
			var sd := Time.get_ticks_msec()
			while ally.alive and Time.get_ticks_msec() - sd < 8000:
				await get_tree().process_frame
			check(hd.denies >= 1, "deny di un proprio creep (%d)" % hd.denies)
	# Meteora (ultimate): livello 6, impara R, lancia su un nemico
	if Game.ENABLE_ULTIMATE:
		while hd.level < 6:
			w.send_command(["cheat", "level"])
			await _wait_sim(w, w.game_time + 0.1)
		w.send_command(["learn", 3])
		await _wait_sim(w, w.game_time + 0.2)
		check(hd.ability_levels[3] == 1, "Meteora appresa al livello 6")
		w.send_command(["cheat", "cooldowns"])
		await _wait_sim(w, w.game_time + 0.2)
		var tgt := _nearest_enemy(w, u.pos, u.team, 60.0)
		if tgt == null:
			w.sim._spawn_wave()
			await _wait_sim(w, w.game_time + 0.2)
			tgt = _nearest_enemy(w, u.pos, u.team, 400.0)
		if tgt:
			u.pos = tgt.pos + Vector2(-8, 8)
			u.prev_pos = u.pos
			# vita alta: se la Meteora uccide il bersaglio non si può osservare lo stordimento
			tgt.max_hp = 5000.0
			tgt.hp = 5000.0
			var hp0 := tgt.hp
			w.send_command(["cast", 3, tgt.pos.x, tgt.pos.y, 0])
			await _wait_sim(w, w.game_time + 0.3)
			var stunned_seen := false
			var sm := w.game_time
			while w.game_time < sm + 2.0:
				await get_tree().process_frame
				for c in w.sim.unit_list:
					if c.team != u.team and c.alive and c.stun_time > 0.0:
						stunned_seen = true
			check(hd.cooldowns[3] > 0.0 and (tgt.hp < hp0 or not tgt.alive), "Meteora: danno ad area e ricarica")
			check(stunned_seen, "Meteora: stordimento dei nemici colpiti")
	# Oggetti della Fase 2
	if Game.ENABLE_PHASE2_ITEMS:
		u.pos = MapData.FOUNTAIN[u.team] + Vector2(5, -5)
		u.prev_pos = u.pos
		w.send_command(["cheat", "gold"])
		w.send_command(["cheat", "gold"])
		await _wait_sim(w, w.game_time + 0.1)
		for i in 6:
			w.send_command(["sell", i])
		w.send_command(["buy", "vampire"])
		await _wait_sim(w, w.game_time + 0.2)
		check(hd.items.has("vampire") and absf(u.lifesteal - 0.15) < 0.001, "Lama del vampiro: rubavita 15%")

	# Scatto
	if hd.ability_levels[1] == 0:
		hd.ability_points += 1
		w.send_command(["learn", 1])
		await _wait_sim(w, w.game_time + 0.3)
	w.send_command(["cheat", "cooldowns"])
	await _wait_sim(w, w.game_time + 0.2)
	var before := u.pos
	w.send_command(["cast", 1, u.pos.x - 8.0, u.pos.y + 8.0, 0])
	await _wait_sim(w, w.game_time + 0.5)
	check(u.pos.distance_to(before) > 5.0, "Scatto: teletrasporto di %.1f m" % u.pos.distance_to(before))

	await _test_peppino(w)
	await _test_gorm(w)

	# Morte e rinascita
	sim._kill(u, null)
	await _wait_sim(w, w.game_time + 0.2)
	check(not u.alive and hd.respawn_timer > 0.0, "eroe morto, rinascita tra %.0f s" % hd.respawn_timer)
	await _wait_sim(w, w.game_time + hd.respawn_timer + 1.0)
	check(u.alive and u.pos.distance_to(MapData.FOUNTAIN[0]) < 12.0, "eroe rinato alla fontana")

	# Vittoria
	var result := {}
	w.finished.connect(func(r): result.merge(r))
	w.send_command(["cheat", "kill_ancient"])
	var start := Time.get_ticks_msec()
	while result.is_empty() and Time.get_ticks_msec() - start < 20000:
		await get_tree().process_frame
	check(result.get("victory", false), "vittoria alla distruzione dell'Antico nemico")
	check(Audio.started_count > 10 and Audio.failed_count == 0, "audio: %d suoni avviati, %d file mancanti" % [Audio.started_count, Audio.failed_count])
	print("  tick medio sim: %d us, FPS: %d" % [sim.last_tick_usec, Engine.get_frames_per_second()])
	_finish("AUTOTEST")


## Peppino: un secondo eroe alleato comandato dal test (peer 99) prova le quattro abilità e l'attacco corpo a corpo.
func _test_peppino(w: World) -> void:
	var sim := w.sim
	var phd := sim.add_hero(99, 0, "Peppino", "peppino")
	var pu: Unit = sim.units[phd.unit_id]
	check(pu.subtype == "peppino" and not pu.is_ranged(), "Peppino creato (corpo a corpo, %d vita)" % int(pu.max_hp))
	phd.level = 6
	phd.ability_levels = [1, 1, 1, 1]
	phd.apply_stats(pu)
	pu.hp = pu.max_hp
	pu.mana = pu.max_mana
	await _wait_sim(w, w.game_time + 0.2)
	check(w.views.has(pu.id) and (w.views[pu.id] as UnitView).model_key == "hero_peppino", "vista di Peppino con il modello del guerriero")
	var refill := func():
		for i in 4:
			phd.cooldowns[i] = 0.0
		pu.mana = pu.max_mana
	# un nemico vicino da colpire: creep nuovo della squadra avversaria
	sim._spawn_wave()
	await _wait_sim(w, w.game_time + 0.1)
	var tgt: Unit = null
	for c in sim.unit_list:
		if c.is_creep() and c.alive and c.team == 1 and (tgt == null or c.max_hp > tgt.max_hp):
			tgt = c
	check(tgt != null, "bersaglio per Peppino")
	if tgt == null:
		return
	tgt.max_hp = 99999.0
	tgt.hp = 99999.0
	# Carica (W)
	pu.pos = tgt.pos + Vector2(-6.5, 0)
	pu.prev_pos = pu.pos
	sim.queue_command(99, ["cast", 1, tgt.pos.x, tgt.pos.y])
	await _wait_sim(w, w.game_time + 0.25)
	var stunned := tgt.stun_time > 0.0
	await _wait_sim(w, w.game_time + 0.4)
	stunned = stunned or tgt.stun_time > 0.0 or tgt.hp < 99999.0
	check(pu.pos.distance_to(tgt.pos) < 3.6 and tgt.hp < 99999.0, "Carica: arrivo sul bersaglio (%.1f m) e danno" % pu.pos.distance_to(tgt.pos))
	check(stunned, "Carica: stordimento all'impatto")
	# Fendente rotante (Q)
	refill.call()
	var hp0 := tgt.hp
	sim.queue_command(99, ["cast", 0, pu.pos.x, pu.pos.y])
	await _wait_sim(w, w.game_time + 0.5)
	check(tgt.hp < hp0 and phd.cooldowns[0] > 0.0, "Fendente rotante: danno ad area (%d)" % int(hp0 - tgt.hp))
	# Scudo di ferro (E): riduzione dei danni
	refill.call()
	sim.queue_command(99, ["cast", 2, pu.pos.x, pu.pos.y])
	await _wait_sim(w, w.game_time + 0.4)
	check(pu.shield_time > 0.0, "Scudo di ferro attivo")
	var php := pu.hp
	sim._damage(null, pu, 100.0, true, false)
	var taken := php - pu.hp
	var expected: float = 100.0 * (1.0 - pu.magic_resist) * (1.0 - Game.hero_abilities("peppino")[2].reduction[0])
	check(absf(taken - expected) < 0.5, "Scudo di ferro: danno ridotto (%.0f invece di %.0f)" % [taken, 100.0 * (1.0 - pu.magic_resist)])
	# Spaccaterra (R)
	refill.call()
	pu.pos = tgt.pos + Vector2(-7.0, 0.5)
	pu.prev_pos = pu.pos
	tgt.stun_time = 0.0
	hp0 = tgt.hp
	sim.queue_command(99, ["cast", 3, tgt.pos.x, tgt.pos.y])
	await _wait_sim(w, w.game_time + 0.7)
	check(tgt.hp < hp0 and tgt.stun_time > 0.0, "Spaccaterra: danno e stordimento in linea (%d)" % int(hp0 - tgt.hp))
	# attacco corpo a corpo
	tgt.stun_time = 0.0
	hp0 = tgt.hp
	sim.queue_command(99, ["attack", tgt.id])
	await _wait_sim(w, w.game_time + 3.0)
	check(tgt.hp < hp0, "Peppino attacca in mischia (%d danni)" % int(hp0 - tgt.hp))
	sim.queue_command(99, ["stop"])
	tgt.max_hp = 300.0
	tgt.hp = 1.0
	await _wait_sim(w, w.game_time + 0.3)


## Gorm: terzo eroe alleato comandato dal test (peer 98). Verifica Fenditura (danno, stordimento, muro che blocca
## e poi si aggira), Totem (balzo, scossa, attacco potenziato), passiva non lanciabile, Eco del sisma (echi).
func _test_gorm(w: World) -> void:
	var sim := w.sim
	var ghd := sim.add_hero(98, 0, "Gorm", "gorm")
	var gu: Unit = sim.units[ghd.unit_id]
	check(gu.subtype == "gorm" and not gu.is_ranged(), "Gorm creato (corpo a corpo, %d vita)" % int(gu.max_hp))
	ghd.level = 6
	ghd.ability_levels = [1, 1, 1, 1]
	ghd.apply_stats(gu)
	gu.hp = gu.max_hp
	gu.mana = gu.max_mana
	await _wait_sim(w, w.game_time + 0.2)
	check(w.views.has(gu.id) and (w.views[gu.id] as UnitView).model_key == "hero_gorm" and (w.views[gu.id] as UnitView).totem_rune != null,
		"vista di Gorm con il modello e il totem")
	var refill := func():
		for i in 4:
			ghd.cooldowns[i] = 0.0
		gu.mana = gu.max_mana
	sim._spawn_wave()
	await _wait_sim(w, w.game_time + 0.1)
	var foes: Array[Unit] = []
	for c in sim.unit_list:
		if c.is_creep() and c.alive and c.team == 1 and c.max_hp < 99999.0:
			foes.append(c)
	check(foes.size() >= 3, "bersagli per Gorm (%d creep)" % foes.size())
	if foes.size() < 3:
		return
	# bastano tre bersagli: tutti gli altri creep vengono rimossi e le ondate sospese (non devono intralciare)
	foes.resize(3)
	for c in sim.unit_list:
		if c.is_creep() and c.alive and not foes.has(c):
			sim._kill(c, null)
	var wave_timer := sim._wave_timer
	sim._wave_timer = 1e9
	var tgt: Unit = foes[0]
	for f in foes:
		f.max_hp = 99999.0
		f.hp = 99999.0
		f.damage = 0.0
	# lontano da torri ed eroi: al centro della corsia, i creep fermi (storditi) in fila
	var base := Vector2(-6, 6)
	var lane := MapData.lane_dir()
	var nrm := MapData.lane_normal()
	for i in foes.size():
		foes[i].pos = base + nrm * (i * 1.6 - 1.0) + lane * 0.3 * i
		foes[i].prev_pos = foes[i].pos
		foes[i].stun_time = 30.0
	# gli altri eroi lontano (da fermi attaccherebbero i bersagli e falserebbero i danni misurati)
	var ku := w.local_hero_unit()
	var pu0: Unit = sim.hero_unit(99)
	for hu in [ku, pu0]:
		if hu:
			hu.pos = base - lane * 30.0
			hu.prev_pos = hu.pos
			sim.queue_command(hu.owner_peer, ["stop"])
	# --- Fenditura (Q): da 5 m, lungo la corsia verso il bersaglio
	gu.pos = tgt.pos - lane * 5.0
	gu.prev_pos = gu.pos
	sim.queue_command(98, ["cast", 0, tgt.pos.x, tgt.pos.y])
	tgt.stun_time = 0.0
	var hp0 := tgt.hp
	await _wait_sim(w, w.game_time + 0.7)
	check(tgt.hp < hp0 and tgt.stun_time > 0.0, "Fenditura: danno e stordimento in linea (%d)" % int(hp0 - tgt.hp))
	check(sim.walls.size() == 1, "Fenditura: muro di roccia creato")
	if sim.walls.size() == 1:
		var wl: Dictionary = sim.walls[0]
		var wa: Vector2 = wl.a
		var wb: Vector2 = wl.b
		var near_wall := Geometry2D.get_closest_point_to_segment(tgt.pos, wa, wb).distance_to(tgt.pos)
		check(near_wall >= wl.w + tgt.radius - 0.05, "Fenditura: le unità sulla linea sono spinte fuori dal muro (%.2f m)" % near_wall)
		# Peppino prova ad attraversare il muro perpendicolarmente al centro: si ferma, poi lo aggira
		var pu: Unit = sim.hero_unit(99)
		var mid := (wa + wb) * 0.5
		var side := (wb - wa).normalized().orthogonal()
		pu.pos = mid + side * 3.0
		pu.prev_pos = pu.pos
		pu.stun_time = 0.0
		pu.target_id = 0
		var goal := mid - side * 3.0
		sim.queue_command(99, ["move", goal.x, goal.y])
		await _wait_sim(w, w.game_time + 0.45)
		var still := (pu.pos - mid).dot(side) > 0.0
		var min_d := Geometry2D.get_closest_point_to_segment(pu.pos, wa, wb).distance_to(pu.pos)
		check(still and min_d >= wl.w + pu.radius - 0.05, "Fenditura: il muro blocca il passaggio (%.2f m dal muro)" % min_d)
		await _wait_sim(w, w.game_time + 3.0)
		check(pu.pos.distance_to(goal) < 1.5, "Fenditura: il muro si aggira dalle estremità (%.1f m dalla meta)" % pu.pos.distance_to(goal))
		sim.queue_command(99, ["stop"])
		pu.pos = base - lane * 30.0
		pu.prev_pos = pu.pos
		await _wait_sim(w, w.game_time + float(Game.hero_abilities("gorm")[0].wall_time))
		check(sim.walls.is_empty(), "Fenditura: il muro sparisce dopo %d s" % int(Game.hero_abilities("gorm")[0].wall_time))
	# --- Passiva (E): non si lancia
	refill.call()
	var mana0 := gu.mana
	sim.queue_command(98, ["cast", 2, gu.pos.x, gu.pos.y])
	await _wait_sim(w, w.game_time + 0.2)
	check(gu.mana == mana0 and ghd.cooldowns[2] == 0.0 and gu.state != Unit.State.CASTING, "Scossa di ritorno: passiva, non si lancia")
	# --- Totem (W) con balzo: atterra vicino al bersaglio, la scossa stordisce, il colpo è potenziato
	refill.call()
	for f in foes:
		f.stun_time = 0.0
	var start := tgt.pos - lane * 5.5
	gu.pos = start
	gu.prev_pos = start
	gu.target_id = 0
	hp0 = tgt.hp
	var land := tgt.pos - lane * 1.6
	sim.queue_command(98, ["cast", 1, land.x, land.y])
	var tw := w.game_time
	var lifted := false
	while w.game_time < tw + 1.0:
		await get_tree().process_frame
		var gv: UnitView = w.views.get(gu.id)
		if gv and gv.model and gv.model.position.y > 0.8:
			lifted = true
	check(gu.pos.distance_to(start) > 3.5 and gu.empower_time > 0.0, "Totem: balzo di %.1f m e totem carico" % gu.pos.distance_to(start))
	check(lifted, "Totem: il modello segue l'arco del balzo")
	check(tgt.hp < hp0 and tgt.stun_time > 0.0, "Scossa di ritorno: all'atterraggio danno e stordimento (%d)" % int(hp0 - tgt.hp))
	var gv2: UnitView = w.views.get(gu.id)
	check(gv2 != null and gv2.empowered and gv2.totem_fire.visible, "Totem: rune accese sul totem carico")
	hp0 = tgt.hp
	var mult: float = 1.0 + float(Game.hero_abilities("gorm")[1].bonus[0])
	var expect := gu.damage * mult * Game.armor_multiplier(tgt.armor)
	sim.queue_command(98, ["attack", tgt.id])
	var ta := w.game_time
	while tgt.hp >= hp0 and w.game_time < ta + 3.0:
		await get_tree().process_frame
	check(absf((hp0 - tgt.hp) - expect) < 2.0 and gu.empower_time <= 0.0, "Totem: attacco potenziato (%d, atteso %d)" % [int(hp0 - tgt.hp), int(expect)])
	sim.queue_command(98, ["stop"])
	# --- Eco del sisma (R): danno subito, poi gli echi degli altri nemici
	refill.call()
	for f in foes:
		f.stun_time = 0.0
	gu.pos = tgt.pos - lane * 1.5
	gu.prev_pos = gu.pos
	hp0 = tgt.hp
	sim.queue_command(98, ["cast", 3, gu.pos.x, gu.pos.y])
	var r_ab: Dictionary = Game.hero_abilities("gorm")[3]
	await _wait_sim(w, w.game_time + float(r_ab.cast_point) + 0.1)
	var first := hp0 - tgt.hp
	await _wait_sim(w, w.game_time + float(r_ab.echo_delay) + 0.1)
	var total := hp0 - tgt.hp
	check(first > 0.0 and total > first + 1.0 and ghd.cooldowns[3] > 0.0, "Eco del sisma: colpo %d + echi %d" % [int(first), int(total - first)])
	for f in foes:
		f.max_hp = 300.0
		f.hp = 1.0
		f.stun_time = 0.0
	sim._wave_timer = minf(wave_timer, 5.0)
	await _wait_sim(w, w.game_time + 0.3)


# ============================================================================
# Rete
# ============================================================================

func _run_net_host() -> void:
	var port := int(Game.arg_value("--port", "7790"))
	var duration := float(Game.arg_value("--duration", "40"))
	print("== NETTEST host sulla porta %d" % port)
	Game.player_name = "Host"
	check(Net.host(port) == OK, "server avviato")
	Net.stats_enabled = true
	Net.lobby_changed.connect(func():
		if Net.lobby.size() == 2 and not Net.lobby[1].ready:
			Net.set_ready(true))
	var start := Time.get_ticks_msec()
	while (main.world == null or main.world._remote_peers.is_empty()) and Time.get_ticks_msec() - start < 30000:
		await get_tree().process_frame
	var w: World = main.world
	check(w != null and not w._remote_peers.is_empty(), "client entrato in partita")
	if w == null:
		_finish("NETTEST")
		return
	var peer: int = w._remote_peers[0] if not w._remote_peers.is_empty() else 0
	var expect_disc := Game.has_arg("--expect-disconnect")
	var t_end := Time.get_ticks_msec() + int(duration * 1000.0)
	var fps_sum := 0.0
	var fps_n := 0
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		fps_sum += Engine.get_frames_per_second()
		fps_n += 1
		if expect_disc and w.over:
			break
	if expect_disc:
		check(w.over and w.forfeit and w.winner == 0, "disconnessione del client gestita: vittoria a tavolino")
		# ritorno al menu e nuova partita senza riavviare
		main._leave_game()
		await _wait(1.0)
		var w2: World = main.start_training()
		await _wait(3.0)
		check(is_instance_valid(w2) and w2.sim.time > 1.0, "nuova partita di allenamento dopo la disconnessione")
		_finish("ROBUST")
		return
	var cu: Unit = w.sim.hero_unit(peer)
	var moved := cu.pos.distance_to(MapData.FOUNTAIN[1]) if cu else 0.0
	check(moved > 20.0, "l'eroe del client si muove sul server (%.0f m dalla fontana)" % moved)
	check(w.sim.unit_list.size() >= 10, "simulazione attiva (%d unità)" % w.sim.unit_list.size())
	var secs := duration
	print("  NET host: banda in uscita snapshot %.1f KB/s, unità %d, FPS medio %.0f" % [Net.bytes_out / 1024.0 / secs, w.sim.unit_list.size(), fps_sum / maxf(1, fps_n)])
	await _wait(2.0)
	_finish("NETTEST")


func _run_net_client() -> void:
	var port := int(Game.arg_value("--port", "7790"))
	var duration := float(Game.arg_value("--duration", "40"))
	print("== NETTEST client (netsim %s)" % str(Net.netsim))
	if Game.has_arg("--recon-offset"):
		World.RECON_TICK_OFFSET = float(Game.arg_value("--recon-offset", "-0.5"))
	Game.player_name = "Client"
	Net.stats_enabled = true
	Net.connected.connect(func(): Net.set_ready(true))
	var ok := false
	for attempt in 20:
		if Net.join("127.0.0.1", port) == OK:
			var s := Time.get_ticks_msec()
			while Time.get_ticks_msec() - s < 1500 and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
				await get_tree().process_frame
			if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				ok = true
				break
		await _wait(0.5)
	check(ok, "connesso all'host")
	var start := Time.get_ticks_msec()
	while main.world == null and Time.get_ticks_msec() - start < 20000:
		await get_tree().process_frame
	var w: World = main.world
	check(w != null, "partita avviata sul client")
	if w == null:
		_finish("NETTEST")
		return
	# attende il conto alla rovescia e lo stato iniziale
	start = Time.get_ticks_msec()
	while (w.local_hero_unit() == null or w.countdown > 0.0) and Time.get_ticks_msec() - start < 15000:
		await get_tree().process_frame
	await _wait(3.5)
	var u := w.local_hero_unit()
	check(u != null, "eroe locale ricevuto dal server")
	if u:
		check(u.subtype == str(Game.settings.hero), "eroe scelto nel menu (%s) creato dal server" % u.subtype)
	if Game.has_arg("--die-after"):
		await _wait(float(Game.arg_value("--die-after", "5")))
		print("  client: chiusura brusca simulata")
		OS.kill(OS.get_process_id())
	w.recon_err_sum = 0.0
	w.recon_err_n = 0
	w.recon_err_max = 0.0
	w._max_jump_seen = 0.0
	Net.bytes_in = 0
	var t0 := Time.get_ticks_msec()
	var t_end := t0 + int(duration * 1000.0)
	var next_cmd := 0
	var spawn := u.pos if u else Vector2.ZERO
	var path := [Vector2(60, -60), Vector2(45, -45), Vector2(30, -30), Vector2(20, -20), Vector2(35, -35)]
	var step := 0
	var frame_jump_max := 0.0
	var watch_id := 0
	var watch_prev := Vector3.INF
	# Gorm: in rete prova anche Fenditura e balzo del Totem (muro noto al client, flag del totem carico)
	var gorm := u != null and u.subtype == "gorm"
	var saw_wall := false
	var saw_empower := false
	if gorm:
		w.send_command(["learn", 1])
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if gorm:
			saw_wall = saw_wall or not w._walls.is_empty()
			var lu := w.local_hero_unit()
			saw_empower = saw_empower or (lu != null and (lu.flags & Unit.F_EMPOWERED) != 0)
		if now >= next_cmd:
			next_cmd = now + 2500
			u = w.local_hero_unit()
			if gorm and u and u.alive and (step == 1 or step == 2):
				var nxt: Vector2 = path[step % path.size()]
				w.send_command(["cast", step - 1, nxt.x, nxt.y, 0])
				await _wait(0.9)
				watch_prev = Vector3.INF     # durante l'attesa il salto per frame non è stato misurato
			if u and u.alive:
				var e := _nearest_enemy(w, u.pos, u.team, 10.0)
				if e and step >= 3 and randf() < 0.5:
					w.send_command(["attack", e.id])
				else:
					var p: Vector2 = path[step % path.size()]
					w.send_command(["move", p.x, p.y])
					step += 1
		# salto visivo massimo per frame di un creep osservato (niente "teletrasporti")
		if watch_id == 0 or not w.views.has(watch_id):
			for id in w.views:
				var uu: Unit = w.units.get(id)
				if uu and uu.is_creep() and uu.alive:
					watch_id = id
					watch_prev = Vector3.INF
					break
		elif w.views.has(watch_id):
			var vp: Vector3 = (w.views[watch_id] as UnitView).vis_pos
			if watch_prev != Vector3.INF and (w.units[watch_id] as Unit).alive:
				frame_jump_max = maxf(frame_jump_max, vp.distance_to(watch_prev))
			watch_prev = vp
	var secs := duration
	u = w.local_hero_unit()
	var avg_err := w.recon_err_sum / maxf(1, w.recon_err_n)
	var kbs := Net.bytes_in / 1024.0 / secs
	print("  NET client: errore riconciliazione medio %.3f m (max %.2f), banda in ingresso %.1f KB/s, snapshot %d (scartati %d), salto max creep/frame %.2f m, ping %.0f ms" % [avg_err, w.recon_err_max, kbs, Net.snapshots_in, Net.snapshots_dropped, frame_jump_max, Net.rtt * 1000.0])
	check(w.units.size() >= 10, "unità sincronizzate (%d)" % w.units.size())
	check(u != null and u.pos.distance_to(spawn) > 15.0, "il proprio eroe si è mosso (autorità server)")
	check(kbs < 30.0, "banda < 30 KB/s (%.1f)" % kbs)
	var lat: float = Net.netsim.latency
	if lat <= 150.0:
		check(avg_err < 0.3, "errore medio di riconciliazione < 0.3 m (%.3f)" % avg_err)
	check(frame_jump_max < 1.5, "nessun teletrasporto visivo dei creep (salto max %.2f m)" % frame_jump_max)
	if gorm:
		check(saw_wall, "Gorm in rete: muro della Fenditura noto al client")
		check(saw_empower, "Gorm in rete: totem carico trasmesso (flag a 16 bit)")
	Net.leave()
	_finish("NETTEST")


# ============================================================================
# Screenshot
# ============================================================================

func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var vp: Viewport = _svp if _svp else get_viewport()
	var img := vp.get_texture().get_image()
	var path := dir.path_join(name + ".png")
	img.save_png(path)
	print("  screenshot: ", path)


func _focus(w: World, p: Vector2, zoom: float = 30.0) -> void:
	w.cam.locked = false
	w.cam.center_on(MapData.to3(p), true)
	w.cam.target_zoom = zoom
	w.cam.zoom = zoom


## Viewport a dimensione fissa (indipendente dalla finestra, che il window manager può ridimensionare).
var _svp: SubViewport

func _use_fixed_viewport(size: Vector2i) -> void:
	_svp = SubViewport.new()
	_svp.size = size
	_svp.own_world_3d = true
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svp.msaa_3d = Viewport.MSAA_2X
	_svp.audio_listener_enable_3d = true
	main.add_child(_svp)
	main.host_node = _svp
	Game.settings.edge_scroll = false   # il mouse non è dentro il viewport di test


func _run_shots() -> void:
	_use_fixed_viewport(Vector2i(1600, 900))
	var dir := Game.arg_value("--shots", "res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir if dir.is_absolute_path() else ProjectSettings.globalize_path(dir))
	print("== Screenshot in ", dir)
	Game.settings.hero = "kael"
	main.show_menu()
	await _wait(4.0)
	await _shot(dir, "01_menu")
	main.menu._show(main.menu._about_panel)
	await _wait(0.5)
	await _shot(dir, "01b_informazioni")
	main.menu._show(main.menu._main_panel)
	var w: World = main.start_training()
	await _wait(2.5)
	print("  debug: hud size ", w.hud.size, " vp ", w.hud.get_viewport_rect(), " overlay ", w.overlay.size)
	_focus(w, MapData.FOUNTAIN[0] + MapData.team_dir(0) * 8.0, 26.0)
	await _wait(0.8)
	await _shot(dir, "02_inizio")
	# accelera fino allo scontro tra creep
	w.send_command(["learn", 2])
	w.send_command(["amove", -14.0, 14.0])
	_set_speed(5.0)
	await _wait_sim(w, 27.0)
	_set_speed(1.0)
	var mid := Vector2.ZERO
	var n := 0
	for u in w.sim.unit_list:
		if u.is_creep() and u.alive:
			mid += u.pos
			n += 1
	if n > 0:
		mid /= n
	_focus(w, mid, 24.0)
	await _wait(1.2)
	await _shot(dir, "03_scontro_creep")
	var hu := w.local_hero_unit()
	var e := _nearest_enemy(w, hu.pos, 0, 40.0)
	if e:
		w.send_command(["move", e.pos.x - 9.0, e.pos.y + 9.0])
		var sm := Time.get_ticks_msec()
		while hu.pos.distance_to(e.pos) > 13.0 and Time.get_ticks_msec() - sm < 6000:
			await get_tree().process_frame
		_focus(w, hu.pos.lerp(e.pos, 0.5), 22.0)
		w.send_command(["cast", 0, e.pos.x, e.pos.y, 0])
		await _wait(0.42)
		await _shot(dir, "04_palla_di_fuoco")
		await _wait(0.4)
		await _shot(dir, "04b_esplosione")
	w.send_command(["cheat", "cooldowns"])
	await _wait(0.3)
	w.send_command(["cast", 2, hu.pos.x, hu.pos.y, 0])
	await _wait(0.45)
	_focus(w, hu.pos, 22.0)
	await _shot(dir, "05_onda_d_urto")
	# animazioni: camminata e attacco, sequenze di fotogrammi ravvicinati
	w.cam.pitch = deg_to_rad(28.0)
	w.send_command(["move", hu.pos.x - 12.0, hu.pos.y + 4.0])
	await _wait(0.3)
	for i in 6:
		_focus(w, hu.pos, 11.0)
		await _shot(dir, "anim_camminata_%d" % i)
		await _wait(0.1)
	e = _nearest_enemy(w, hu.pos, 0, 25.0)
	if e:
		w.send_command(["attack", e.id])
		var s := Time.get_ticks_msec()
		while hu.state != Unit.State.ATTACKING and Time.get_ticks_msec() - s < 5000:
			await get_tree().process_frame
		for i in 6:
			_focus(w, hu.pos, 11.0)
			await _shot(dir, "anim_attacco_%d" % i)
			await _wait(0.1)
	w.cam.pitch = CameraRig.PITCH_DEFAULT
	# torre che spara: porta l'eroe (invulnerabile) sotto la T1 nemica
	w.send_command(["cheat", "invulnerable"])
	var dt1: Vector2 = MapData.T1[1]
	w.send_command(["move", dt1.x - 5.0, dt1.y + 5.0])
	_set_speed(4.0)
	var s2 := Time.get_ticks_msec()
	while hu.pos.distance_to(dt1) > 8.0 and Time.get_ticks_msec() - s2 < 20000:
		await get_tree().process_frame
	_set_speed(1.0)
	_focus(w, dt1.lerp(hu.pos, 0.4), 26.0)
	await _wait(1.3)
	await _shot(dir, "06_torre")
	# negozio
	w.hud.toggle_shop()
	await _wait(0.5)
	await _shot(dir, "07_negozio")
	w.hud.toggle_shop()
	# vista d'insieme dello schieramento della base nemica
	_focus(w, MapData.ANCIENT[1] + Vector2(-8, 8), 40.0)
	await _wait(1.0)
	await _shot(dir, "08_base_nemica")
	# vittoria
	var done := {}
	w.finished.connect(func(r): done.merge(r))
	w.send_command(["cheat", "kill_ancient"])
	_focus(w, MapData.ANCIENT[1], 34.0)
	await _wait(0.6)
	await _shot(dir, "09_antico_distrutto")
	var s3 := Time.get_ticks_msec()
	while done.is_empty() and Time.get_ticks_msec() - s3 < 10000:
		await get_tree().process_frame
	await _wait(1.0)
	await _shot(dir, "10_vittoria")
	_finish("SHOTS")


## Inquadrature fisse per la revisione grafica, senza scenario di gioco (pochi secondi): guado con creep,
## corsia, riva fuori dalla corsia, basi, vista d'insieme. --views-quality Q sceglie il preset.
func _run_views() -> void:
	_use_fixed_viewport(Vector2i(1600, 900))
	var dir := Game.arg_value("--views", "res://screenshots/views")
	DirAccess.make_dir_recursive_absolute(dir if dir.is_absolute_path() else ProjectSettings.globalize_path(dir))
	if Game.has_arg("--views-quality"):
		Game.settings.quality = int(Game.arg_value("--views-quality", "1"))
	Game.settings.hero = Game.arg_value("--views-hero", "kael")
	var w: World = main.start_training()
	await _wait(1.0)
	w.sim._spawn_wave()
	for u in w.sim.unit_list:
		if u.is_creep():
			u.pos = MapData.closest_on_lane(u.pos).lerp(Vector2.ZERO, 0.9) + MapData.lane_normal() * u.lane_offset * 2.0
			u.prev_pos = u.pos
	var hu := w.local_hero_unit()
	hu.pos = Vector2(-6, 6)
	hu.prev_pos = hu.pos
	var views := [["guado", Vector2(0, 0), 24.0], ["corsia", Vector2(-40, 40), 26.0], ["riva", Vector2(18, 22), 26.0],
		["base_lega", MapData.ANCIENT[0] + Vector2(6, -6), 30.0], ["base_culto", MapData.ANCIENT[1] + Vector2(-8, 8), 34.0],
		["torre_culto", MapData.T1[1], 26.0], ["corsia_culto", Vector2(42, -42), 26.0], ["insieme", Vector2(0, 0), 60.0]]
	if Game.has_arg("--views-fx"):
		views = []
	for v in views:
		_focus(w, v[1], v[2])
		await _wait(0.6)
		await _shot(dir, v[0])
	# --views-fx: fotogrammi ravvicinati delle abilità (onda d'urto, palla di fuoco, scatto, meteora)
	if Game.has_arg("--views-fx"):
		w.send_command(["cheat", "invulnerable"])
		w.local_hero_data().ability_levels = [4, 4, 4, 3]
		_focus(w, hu.pos, 20.0)
		await _wait(0.5)
		var casts := [["onda", 2, Vector2.ZERO], ["palla", 0, Vector2(10, -8)], ["scatto", 1, Vector2(4, -6)], ["meteora", 3, Vector2(6, -2)]]
		if w.local_hero_id() == "peppino":
			casts = [["fendente", 0, Vector2.ZERO], ["carica", 1, Vector2(7, -5)], ["scudo", 2, Vector2.ZERO], ["spaccaterra", 3, Vector2(8, -6)]]
			_focus(w, hu.pos, 9.0)
			await _wait(0.6)
			await _shot(dir, "eroe")
		elif w.local_hero_id() == "gorm":
			# creep nemici vicini (fermi) per vedere scossa, echi e stordimenti
			for c in w.sim.unit_list:
				if c.is_creep() and c.team == 1 and c.alive:
					c.pos = hu.pos + Vector2(randf_range(2.0, 6.0), randf_range(-6.0, -2.0))
					c.prev_pos = c.pos
					c.damage = 0.0
					c.max_hp = 99999.0
					c.hp = 99999.0
			casts = [["fenditura", 0, Vector2(8, -6)], ["totem", 1, Vector2(4, -3)], ["eco", 3, Vector2.ZERO]]
			_focus(w, hu.pos, 9.0)
			await _wait(0.6)
			await _shot(dir, "eroe")
			# anteprima di mira della Fenditura (rettangolo verso il mouse)
			_focus(w, hu.pos, 20.0)
			await _wait(0.3)
			var aim3 := MapData.to3(hu.pos + Vector2(8, -6))
			Input.warp_mouse(w.cam.camera.unproject_position(aim3))
			w.targeting_slot = 0
			await _wait(0.3)
			await _shot(dir, "mira_fenditura")
			w._cancel_targeting()
		for c in casts:
			w.send_command(["cheat", "cooldowns"])
			var tgt: Vector2 = hu.pos + c[2]
			w.send_command(["cast", c[1], tgt.x, tgt.y, 0])
			for i in (5 if c[1] != 3 else 10):
				_focus(w, hu.pos.lerp(tgt, 0.5), 20.0)
				await _wait(0.12 if c[1] != 3 else 0.15)
				await _shot(dir, "fx_%s_%d" % [c[0], i])
			await _wait(1.0)
	_finish("VIEWS")


# ============================================================================
# Benchmark
# ============================================================================

func _run_benchmark() -> void:
	_use_fixed_viewport(Vector2i(1600, 900))
	var secs := float(Game.arg_value("--bench-seconds", "30"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var results: Array = []
	var presets := [0, 1, 2]
	if Game.has_arg("--bench-preset"):
		presets = [int(Game.arg_value("--bench-preset", "1"))]
	# scenario fisso: stesse abilità a ogni misura (--bench-hero gorm: muri, balzi ed echi a ripetizione)
	Game.settings.hero = Game.arg_value("--bench-hero", "kael")
	var bench_gorm: bool = Game.settings.hero == "gorm"
	for q in presets:
		Game.settings.quality = q
		var w: World = main.start_training()
		await _wait(1.0)
		# scenario di carico fisso: 5 ondate per lato tutte insieme al centro
		for i in 5:
			w.sim._spawn_wave()
		for u in w.sim.unit_list:
			if u.is_creep():
				u.pos = MapData.closest_on_lane(u.pos).lerp(Vector2.ZERO, 0.8) + MapData.lane_normal() * u.lane_offset * 2.0
				u.prev_pos = u.pos
		w.send_command(["cheat", "invulnerable"])
		w.sim.heroes[1].ability_levels = [4, 4, 4, 3] if bench_gorm else [4, 4, 4, 0]
		var hu := w.local_hero_unit()
		hu.pos = Vector2(-6, 6)
		hu.prev_pos = hu.pos
		# --bench-at x,y: inquadra un altro punto (es. una base) invece del centro
		var at := Vector2.ZERO
		if Game.has_arg("--bench-at"):
			var xy := Game.arg_value("--bench-at", "0,0").split(",")
			at = Vector2(float(xy[0]), float(xy[1]))
		_focus(w, at, 32.0)
		await _wait(2.0)
		Game.prof_enabled = true
		Game.prof.clear()
		var frames: Array[float] = []
		var ticks: Array[int] = []
		var calls := 0
		var calls_n := 0
		var proc_sum := 0.0
		var last := Time.get_ticks_usec()
		var end := Time.get_ticks_msec() + int(secs * 1000.0)
		var next_cast := 0
		var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
		var spikes: Array = []
		# tempi di rendering misurati dal driver (GPU) e dalla CPU di rendering, per capire chi limita
		var vp_rid := _svp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		var gpu_sum := 0.0
		var cpu_sum := 0.0
		while Time.get_ticks_msec() < end:
			var units_before := w.views.size()
			var tick_before := w.sim.tick_n
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ft := (now - last) / 1000.0
			frames.append(ft)
			last = now
			if ft > 30.0 and spikes.size() < 12:
				spikes.append("%.0fms(proc=%.1fms,tick+%d,viste%+d)" % [ft, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, w.sim.tick_n - tick_before, w.views.size() - units_before])
			ticks.append(w.sim.last_tick_usec)
			calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			calls_n += 1
			_focus(w, at, 32.0)
			if Time.get_ticks_msec() > next_cast and not Game.has_arg("--bench-nocast"):
				next_cast = Time.get_ticks_msec() + 700
				w.send_command(["cheat", "cooldowns"])
				var e := _nearest_enemy(w, hu.pos, 0, 14.0)
				var target := e.pos if e else Vector2(5, -5)
				w.send_command(["cast", ([0, 1, 3] if bench_gorm else [0, 2])[randi() % (3 if bench_gorm else 2)], target.x, target.y, 0])
				# mantiene lo scontro vivo: nuove ondate se i creep calano
				if w.sim.unit_list.filter(func(x): return x.is_creep() and x.alive).size() < 40:
					w.sim._spawn_wave()
		var sorted := frames.duplicate()
		sorted.sort()
		var avg_ms := 0.0
		for f in frames:
			avg_ms += f
		avg_ms /= frames.size()
		var worst := sorted.slice(int(sorted.size() * 0.99))
		var low_ms := 0.0
		for f in worst:
			low_ms += f
		low_ms /= maxf(1, worst.size())
		var tick_avg := 0.0
		for t in ticks:
			tick_avg += t
		tick_avg /= maxf(1, ticks.size())
		var units := w.sim.unit_list.size()
		var r := {"q": ["Bassa", "Media", "Alta"][q], "fps": 1000.0 / avg_ms, "low": 1000.0 / low_ms, "max_ms": sorted.back(),
			"tick_us": tick_avg, "calls": calls / maxf(1, calls_n), "units": units,
			"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "mem_delta": (Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0}
		results.append(r)
		if not spikes.is_empty():
			print("  picchi: ", ", ".join(spikes))
		var pr := "  profilo (ms/frame):"
		for k in Game.prof:
			if k.begins_with("ev_"):
				pr += " %s=%.2fms/evento" % [k, Game.prof[k][0] / 1000.0 / maxf(1, Game.prof[k][1])]
			else:
				pr += " %s=%.2f" % [k, Game.prof[k][0] / 1000.0 / maxf(1, calls_n)]
		print(pr)
		print("  rendering: GPU %.2f ms/frame, CPU di rendering %.2f ms/frame, logica %.2f ms/frame" % [gpu_sum / maxf(1, calls_n), cpu_sum / maxf(1, calls_n), proc_sum / maxf(1, calls_n)])
		Game.prof_enabled = false
		print("  BENCH %s: FPS medio %.0f, 1%% low %.0f, frame max %.1f ms, tick sim %.0f us, draw call %.0f, unità %d" % [r.q, r.fps, r.low, r.max_ms, r.tick_us, r.calls, units])
	_write_benchmark(results, secs)
	_finish("BENCHMARK")


func _write_benchmark(results: Array, secs: float) -> void:
	var path := ProjectSettings.globalize_path("res://benchmark_results.md")
	var old := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "# Risultati dei benchmark\n\nScenario: 5 ondate per lato contemporaneamente al centro della mappa + abilità lanciate a ripetizione, telecamera sullo scontro, VSync disattivato.\nLimiti (preset Media): FPS medio ≥ 60, 1% low ≥ 45, tick di simulazione < 4 ms, draw call < 1000.\n"
	var gpu := RenderingServer.get_video_adapter_name()
	var label := Game.arg_value("--bench-label", "")
	var s := "\n## %s %s\n\nGPU: %s · risoluzione %s · durata %d s per preset\n\n| Preset | FPS medio | 1%% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |\n|---|---|---|---|---|---|---|---|\n" % [Time.get_datetime_string_from_system(), label, gpu, str(_svp.size) if _svp else str(get_viewport().get_visible_rect().size), int(secs)]
	for r in results:
		s += "| %s | %.0f | %.0f | %.1f | %.0f | %.0f | %d | %.0f |\n" % [r.q, r.fps, r.low, r.max_ms, r.tick_us, r.calls, r.units, r.mem_mb]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(old + s)
	f.close()


# ============================================================================
# Soak test
# ============================================================================

func _run_soak() -> void:
	var minutes := float(Game.arg_value("--soak-minutes", "30"))
	print("== SOAK allenamento per %d minuti di gioco" % int(minutes))
	var w: World = main.start_training()
	_set_speed(float(Game.arg_value("--timescale", "10")))
	await get_tree().process_frame
	var nodes5 := 0.0
	var mem5 := 0.0
	var stuck_max := 0.0
	var last_pos: Dictionary = {}
	var last_moved: Dictionary = {}
	var next_check := 10.0
	var next_cmd := 5.0
	var fps_min := 9999.0
	var tick_max := 0
	while w.game_time < minutes * 60.0:
		await get_tree().process_frame
		if not is_instance_valid(w) or w.over:
			break
		tick_max = maxi(tick_max, w.sim.last_tick_usec)
		var hu := w.local_hero_unit()
		if w.game_time >= next_cmd:
			next_cmd = w.game_time + 6.0
			if hu.alive:
				# l'eroe farma vicino alla propria T1 e ogni tanto lancia abilità
				w.send_command(["amove", -24.0 + randf() * 6.0, 24.0 - randf() * 6.0])
				var e := _nearest_enemy(w, hu.pos, 0, 12.0)
				if e and randf() < 0.5:
					w.send_command(["cast", 0, e.pos.x, e.pos.y, 0])
				for slot in [0, 1, 2]:
					w.send_command(["learn", slot])
		if w.game_time >= next_check:
			next_check += 10.0
			for u in w.sim.unit_list:
				if not u.is_creep() or not u.alive:
					continue
				var lp: Vector2 = last_pos.get(u.id, Vector2.INF)
				if lp == Vector2.INF or lp.distance_to(u.pos) > 0.5 or u.target_id != 0:
					last_pos[u.id] = u.pos
					last_moved[u.id] = w.game_time
				else:
					stuck_max = maxf(stuck_max, w.game_time - float(last_moved.get(u.id, w.game_time)))
			if absf(w.game_time - 300.0) < 10.0 and nodes5 == 0.0:
				nodes5 = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
				mem5 = Performance.get_monitor(Performance.MEMORY_STATIC)
			print("  t=%4.0fs unità=%d nodi=%d mem=%.1f MB tick_max=%d us" % [w.game_time, w.sim.unit_list.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, tick_max])
	var nodes_end := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem_end := Performance.get_monitor(Performance.MEMORY_STATIC)
	if nodes5 > 0.0:
		check(nodes_end <= nodes5 * 1.05 + 50, "numero di nodi stabile (%d -> %d)" % [nodes5, nodes_end])
		check(mem_end <= mem5 * 1.05 + 4.0 * 1048576.0, "memoria stabile (%.1f -> %.1f MB)" % [mem5 / 1048576.0, mem_end / 1048576.0])
	check(stuck_max < 10.0, "nessun creep incastrato più di 10 s (max %.0f s)" % stuck_max)
	check(w.sim.unit_list.size() <= Game.MAX_UNITS, "limite di unità rispettato (%d)" % w.sim.unit_list.size())
	check(tick_max < 8000, "tick di simulazione massimo < 8 ms (%d us)" % tick_max)
	_finish("SOAK")


# ============================================================================
# Duelli tra eroi (bilanciamento)
# ============================================================================

## Combattimenti 1 contro 1 a vari livelli con gli stessi oggetti, in simulazione pura (nessuna scena),
## lontano da torri e creep. L'IA è semplice ma usa le abilità di ogni eroe come farebbe un giocatore:
## Kael tiene la distanza e usa lo scatto per fuggire, Peppino carica e stordisce.
var _duel_stats: Dictionary = {}

func _run_duel() -> void:
	var runs := int(Game.arg_value("--duel-runs", "40"))
	print("== DUELLI (%d per caso)" % runs)
	var builds := {1: [], 3: ["sword"], 6: ["sword", "armor", "vitality"], 10: ["sword", "armor", "vitality", "boots", "vampire"]}
	var pairs := [["kael", "kael"], ["peppino", "peppino"], ["gorm", "gorm"], ["kael", "peppino"], ["kael", "gorm"], ["peppino", "gorm"]]
	var lines: Array[String] = []
	var levels := [1, 3, 6, 10]
	if Game.arg_value("--duel-level") != "":
		levels = [int(Game.arg_value("--duel-level"))]
		pairs = [["kael", "peppino"], ["kael", "gorm"], ["peppino", "gorm"]]
		if Game.arg_value("--duel-pair") != "":
			pairs = [Game.arg_value("--duel-pair").split(",")]
	if Game.has_arg("--duel-noitems"):
		for k in builds:
			builds[k] = []
	for lvl in levels:
		for pr in pairs:
			var wins := [0, 0]
			var draws := 0
			var t_sum := 0.0
			var hp_left := [0.0, 0.0]
			for r in runs:
				# a turno ciascun eroe gioca per la Lega o per il Culto (nessun vantaggio di lato)
				var swap := r % 2 == 1
				var res: Array = _duel_once(pr[1] if swap else pr[0], pr[0] if swap else pr[1], lvl, builds[lvl], 1000 + r)
				var w: int = res[0]
				if w < 0:
					draws += 1
				else:
					var who := w if not swap else 1 - w
					wins[who] += 1
					hp_left[who] += res[2]
				t_sum += res[1]
			var line := "liv %2d  %-8s vs %-8s  vittorie %2d - %2d  (doppio KO %d)  durata media %.1f s  vita residua del vincitore %d%% / %d%%" % [
				lvl, pr[0], pr[1], wins[0], wins[1], draws, t_sum / runs,
				roundi(100.0 * hp_left[0] / maxf(1.0, wins[0])), roundi(100.0 * hp_left[1] / maxf(1.0, wins[1]))]
			print(line)
			lines.append(line)
	if Game.has_arg("--duel-stats"):
		for k in _duel_stats:
			print("  %-12s lanci %4d  a segno %4d" % [k, _duel_stats[k][0], _duel_stats[k][1]])
	print("DUEL OK")
	Game.quit(0)


func _duel_once(h0: String, h1: String, lvl: int, items: Array, seed_n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var sim := Sim.new(true)
	sim._wave_timer = 1e9
	var hds: Array[HeroData] = [sim.add_hero(1, 0, "A", h0), sim.add_hero(2, 1, "B", h1)]
	var us: Array[Unit] = []
	# posizioni: sulla corsia a metà strada tra le T1, a 9-15 m l'uno dall'altro
	var dir := MapData.team_dir(0)
	var nrm := MapData.lane_normal()
	var center := Vector2(-20, 20) + nrm * rng.randf_range(-4.0, 4.0)
	var gap := rng.randf_range(9.0, 15.0)
	for i in 2:
		var hd := hds[i]
		hd.level = lvl
		hd.ability_levels = [0, 0, 0, 0]
		hd.ability_points = 0
		_duel_build(hd, lvl)
		for k in items.size():
			hd.items[k] = items[k]
		var u: Unit = sim.units[hd.unit_id]
		hd.apply_stats(u)
		u.hp = u.max_hp
		u.mana = u.max_mana
		u.pos = center + dir * (gap * 0.5) * (-1.0 if i == 0 else 1.0) + nrm * rng.randf_range(-2.0, 2.0)
		u.prev_pos = u.pos
		us.append(u)
	var t := 0.0
	var think := [rng.randf_range(0.0, 0.3), rng.randf_range(0.0, 0.3)]
	while t < 90.0:
		for i in 2:
			think[i] -= Game.TICK
			if think[i] <= 0.0:
				think[i] = rng.randf_range(0.12, 0.3)     # tempo di reazione variabile
				_duel_ai(sim, hds[i], us[i], us[1 - i], i + 1, rng)
		var hp_before := [us[0].hp, us[1].hp]
		sim.tick()
		if Game.has_arg("--duel-stats"):
			for e in sim.events:
				if e[0] == "fx" and e[1] in ["meteor_hit", "explosion", "earthsplit", "cleave", "charge_hit", "shockwave", "fissure", "aftershock", "echo_slam", "totem_hit"]:
					var k: String = e[1]
					var victim := 1 if int(e[4]) == us[0].id else 0
					var hit: bool = us[victim].hp < float(hp_before[victim]) - 1.0
					var st: Array = _duel_stats.get(k, [0, 0])
					st[0] += 1
					st[1] += 1 if hit else 0
					_duel_stats[k] = st
		if OS.get_environment("DUEL_TRACE") != "":
			for e in sim.events:
				if e[0] in ["fx", "cast"] or (e[0] == "dmg"):
					print("T %.2f %s  hp %d/%d  st %.1f/%.1f  d %.1f  s0 %d s1 %d" % [t, str(e), us[0].hp, us[1].hp, us[0].stun_time, us[1].stun_time, us[0].pos.distance_to(us[1].pos), us[0].state, us[1].state])
		sim.events.clear()
		t += Game.TICK
		if not us[0].alive or not us[1].alive:
			break
	var winner := -1
	if us[0].alive and not us[1].alive:
		winner = 0
	elif us[1].alive and not us[0].alive:
		winner = 1
	var left := us[winner].hp / us[winner].max_hp if winner >= 0 else 0.0
	return [winner, t, left]


## Distribuisce i punti abilità come un giocatore tipico: ultimate appena possibile, poi Q, E, W a rotazione.
func _duel_build(hd: HeroData, lvl: int) -> void:
	var points := lvl + 1
	var order := [3, 0, 2, 1]
	var abs_: Array = hd.abilities()
	while points > 0:
		var spent := false
		for s in order:
			var cur: int = hd.ability_levels[s]
			if cur < abs_[s].max_level and lvl >= Sim.required_level(s, cur + 1):
				hd.ability_levels[s] = cur + 1
				points -= 1
				spent = true
				break
		if not spent:
			break
		# rotazione tra le abilità base dopo ogni punto
		var base: Array = [order[1], order[2], order[3]]
		base.push_back(base.pop_front())
		order = [3, base[0], base[1], base[2]]


func _duel_ai(sim: Sim, hd: HeroData, me: Unit, en: Unit, peer: int, _rng: RandomNumberGenerator) -> void:
	if not me.alive or not en.alive or me.state == Unit.State.CASTING or me.dash_time > 0.0:
		return
	var d := me.pos.distance_to(en.pos)
	var ready := func(s: int) -> bool:
		if Game.arg_value("--duel-ban").split(",").has("%s%d" % [hd.hero, s]):
			return false
		var lvl: int = hd.ability_levels[s]
		return lvl > 0 and hd.cooldowns[s] <= 0.0 and me.mana >= hd.abilities()[s].mana[lvl - 1]
	var cast := func(s: int, p: Vector2) -> void:
		sim.queue_command(peer, ["cast", s, p.x, p.y])
	match hd.hero:
		"kael":
			var enemy_melee := not en.is_ranged()
			if enemy_melee and d < 3.2 and ready.call(1):
				var away := (me.pos - en.pos).normalized()
				cast.call(1, me.pos + away * 10.0)
				return
			# mira anticipata: dove sarà il nemico (meteora dopo 1 s, palla di fuoco a 25 m/s)
			var vel := ((en.pos - en.prev_pos) / Game.TICK).limit_length(en.current_move_speed())
			if en.dash_time > 0.0:
				vel = Vector2.ZERO
			if ready.call(3) and d <= 15.0 and (en.is_stunned() or en.slow_time > 0.0 or d < 5.0):
				# un nemico corpo a corpo che insegue finirà addosso a Kael: si mira tra i due
				var aim := en.pos if en.is_stunned() else (me.pos.lerp(en.pos, 0.35) if enemy_melee and d < 6.0 else en.pos + vel * 1.1)
				cast.call(3, aim)
				return
			if ready.call(0) and d <= 13.0:
				cast.call(0, en.pos + vel * (d / 25.0))
				return
			if ready.call(2) and d <= 4.6:
				cast.call(2, me.pos)
				return
			# kiting: tra un colpo e l'altro si allontana da un nemico corpo a corpo
			if enemy_melee and d < 4.0 and me.windup <= 0.0 and me.attack_cd > 0.45:
				var away2 := (me.pos - en.pos).normalized()
				sim.queue_command(peer, ["move", me.pos.x + away2.x * 3.0, me.pos.y + away2.y * 3.0])
				return
		"peppino":
			if ready.call(1) and d > 3.0 and d <= 9.0:
				cast.call(1, en.pos)
				return
			if ready.call(3) and d <= 11.0:
				cast.call(3, en.pos)
				return
			if ready.call(2) and d <= 6.0:
				cast.call(2, me.pos)
				return
			if ready.call(0) and d <= 3.2:
				cast.call(0, me.pos)
				return
		"gorm":
			# combinazione tipica: balzo addosso (scossa) o Fenditura, poi Eco del sisma e colpo del totem
			var vel2 := ((en.pos - en.prev_pos) / Game.TICK).limit_length(en.current_move_speed())
			if ready.call(3) and d <= 5.5:
				cast.call(3, me.pos)
				return
			if ready.call(1) and d > 2.6 and d <= 8.0:
				cast.call(1, en.pos - (en.pos - me.pos).normalized() * 1.2)
				return
			if ready.call(0) and d <= 11.0 and not en.is_stunned():
				cast.call(0, en.pos + vel2 * 0.5)
				return
			if ready.call(1) and d <= 2.6 and me.empower_time <= 0.0:
				cast.call(1, me.pos)
				return
	if me.target_id != en.id:
		sim.queue_command(peer, ["attack", en.id])
