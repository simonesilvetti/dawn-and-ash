class_name Vfx
extends Node3D
## Effetti visivi in scena con pool: proiettili, esplosioni, anelli, luci temporanee.
## Riceve gli eventi da World; tutto è puramente visivo (nessuna logica di gioco).

const MAX_LIGHTS := 4

var world: Node                       # World (per le posizioni visive dei bersagli)
var quality: int = 1
var projectiles: Dictionary = {}      # pid -> {node, type, target, pos, dir, speed, dist, max}
var _pools: Dictionary = {}           # chiave -> Array[Node3D]
var _active: Array = []               # effetti a tempo: {node, t, dur, kind, data}
var _lights: Array[OmniLight3D] = []
var _light_t: Array[float] = []
var _ring_mesh: QuadMesh
var _ring_shader: Shader
var shake: float = 0.0                # intensità della scossa della telecamera (letta da CameraRig)


func _ready() -> void:
	_ring_mesh = QuadMesh.new()
	_ring_mesh.size = Vector2(2, 2)
	_ring_mesh.orientation = PlaneMesh.FACE_Y
	_ring_shader = load("res://scripts/vfx/fx_ring.gdshader")
	for i in MAX_LIGHTS:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
		_light_t.append(0.0)


# --- Pool ----------------------------------------------------------------------

func _take(key: String, factory: Callable) -> Node3D:
	var pool: Array = _pools.get(key, [])
	var n: Node3D
	if pool.is_empty():
		n = factory.call()
		n.set_meta("pool", key)
		add_child(n)
	else:
		n = pool.pop_back()
		n.visible = true
	return n


func _give(n: Node3D) -> void:
	n.visible = false
	var key: String = n.get_meta("pool", "")
	var pool: Array = _pools.get(key, [])
	pool.append(n)
	_pools[key] = pool


## Precarica i pool più usati per evitare scatti alla prima apparizione.
func warmup() -> void:
	var tmp: Array = []
	for t in ["bolt_0", "bolt_1", "creep_bolt_0", "creep_bolt_1", "tower_0", "tower_1"]:
		for i in 6:
			tmp.append(_take("proj_" + t, _proj_factory(t)))
	for n in tmp:
		_give(n)
	for k in ["explosion", "burst_gold", "burst_fire"]:
		var e: Node3D = _take("fx_" + k, _fx_factory(k))
		_give(e)


# --- Proiettili ----------------------------------------------------------------

func _proj_factory(key: String) -> Callable:
	return func() -> Node3D:
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 10
		sm.rings = 5
		var team := int(key.right(1))
		var c: Color
		var r := 0.22
		var trail := false
		match key.left(key.length() - 2):
			"bolt":
				c = Color(1.0, 0.5, 0.12) if team == 0 else Color(0.7, 0.3, 1.0)
				r = 0.26
				trail = true
			"fireball":
				c = Color(1.0, 0.45, 0.1) if team == 0 else Color(0.75, 0.3, 1.0)
				r = 0.55
				trail = true
			"creep_bolt":
				c = Color(1.0, 0.9, 0.5) if team == 0 else Color(0.65, 0.35, 0.95)
				r = 0.16
			"tower", "fountain":
				c = Game.TEAM_COLORS[team].lightened(0.2)
				r = 0.35
				trail = quality >= 1
			_:
				c = Color(0.6, 0.55, 0.5)
				r = 0.4
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh = sm
		mi.material_override = VfxLib.glow_material(c, 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		if trail:
			var tr := VfxLib.make_trail(c, r * 1.4)
			tr.name = "Trail"
			root.add_child(tr)
		return root


func spawn_projectile(pid: int, ptype: String, team: int, start: Vector3, target_id: int, dir: Vector3, speed: float, max_dist: float) -> void:
	var key := "%s_%d" % [ptype, team]
	var n := _take("proj_" + key, _proj_factory(key))
	n.position = start
	var tr: GPUParticles3D = n.get_node_or_null("Trail")
	if tr:
		tr.emitting = false
		tr.restart()
		tr.emitting = true
	projectiles[pid] = {"node": n, "type": ptype, "target": target_id, "pos": start, "dir": dir, "speed": speed,
		"dist": 0.0, "max": max_dist if max_dist > 0.0 else 999.0}


func end_projectile(pid: int) -> void:
	var p: Dictionary = projectiles.get(pid, {})
	if p.is_empty():
		return
	projectiles.erase(pid)
	_give(p.node)


func _update_projectiles(delta: float) -> void:
	var finished: Array = []
	for pid in projectiles:
		var p: Dictionary = projectiles[pid]
		var step: float = p.speed * delta
		if p.target != 0:
			var tp: Vector3 = world.view_hit_point(p.target)
			if tp == Vector3.INF:
				finished.append(pid)
				continue
			var to: Vector3 = tp - p.pos
			if to.length() <= step:
				p.pos = tp
				finished.append(pid)   # arrivato: in attesa di proj_end non serve tenerlo
			else:
				p.pos += to.normalized() * step
		else:
			p.pos += p.dir * step
			p.dist += step
			if p.dist > p.max + 1.0:
				finished.append(pid)
		p.node.position = p.pos
	for pid in finished:
		end_projectile(pid)


# --- Effetti a tempo -----------------------------------------------------------

func _fx_factory(kind: String) -> Callable:
	return func() -> Node3D:
		match kind:
			"explosion": return VfxLib.make_explosion(Color(1.0, 0.45, 0.1), 1.0)
			"explosion_dire": return VfxLib.make_explosion(Color(0.7, 0.3, 1.0), 1.0)
			"big_explosion": return VfxLib.make_explosion(Color(1.0, 0.5, 0.15), 2.5)
			"burst_fire": return VfxLib.make_burst(Color(1.0, 0.5, 0.1), 40, 4.0, 0.8)
			"burst_violet": return VfxLib.make_burst(Color(0.7, 0.3, 1.0), 40, 4.0, 0.8)
			"burst_gold": return VfxLib.make_burst(Color(1.0, 0.85, 0.3), 60, 6.0, 1.0)
			"burst_heal": return VfxLib.make_burst(Color(0.4, 1.0, 0.5), 24, 2.0, 0.6)
			"burst_dust": return VfxLib.make_burst(Color(0.75, 0.7, 0.6), 30, 2.0, 0.6)
			"ring":
				var mi := MeshInstance3D.new()
				mi.mesh = _ring_mesh
				var m := ShaderMaterial.new()
				m.shader = _ring_shader
				mi.material_override = m
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				return mi
			"column":
				var mi := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 1.0
				cm.bottom_radius = 1.0
				cm.height = 1.0
				cm.radial_segments = 16
				cm.cap_top = false
				cm.cap_bottom = false
				mi.mesh = cm
				var m := ShaderMaterial.new()
				m.shader = load("res://scripts/vfx/glow.gdshader")
				mi.material_override = m
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				return mi
			"meteor":
				var mi := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(1.6, 2.6, 1.6)
				mi.mesh = pm
				mi.material_override = VfxLib.glow_material(Color(1.0, 0.45, 0.1), 3.5)
				var tr := VfxLib.make_trail(Color(1.0, 0.5, 0.1), 1.6)
				mi.add_child(tr)
				return mi
		return Node3D.new()


func _particles(kind: String, pos: Vector3) -> void:
	var p := _take("fx_" + kind, _fx_factory(kind)) as GPUParticles3D
	p.position = pos
	p.restart()
	p.emitting = true
	_active.append({"node": p, "t": 0.0, "dur": p.lifetime + 0.3, "kind": "particles"})


func _ring(pos: Vector3, c: Color, r0: float, r1: float, dur: float, thickness: float = 0.15, fill: float = 0.0) -> void:
	var mi := _take("fx_ring", _fx_factory("ring")) as MeshInstance3D
	mi.position = pos + Vector3(0, 0.08, 0)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("thickness", thickness)
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("fade", 1.0)
	mi.scale = Vector3(r0, 1, r0)
	_active.append({"node": mi, "t": 0.0, "dur": dur, "kind": "ring", "r0": r0, "r1": r1})


func _column(pos: Vector3, c: Color, r: float, h: float, dur: float) -> void:
	var mi := _take("fx_column", _fx_factory("column")) as MeshInstance3D
	mi.position = pos + Vector3(0, h * 0.5, 0)
	mi.scale = Vector3(r, h, r)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("intensity", 2.0)
	m.set_shader_parameter("fade", 1.0)
	_active.append({"node": mi, "t": 0.0, "dur": dur, "kind": "column", "r": r})


func _flash_light(pos: Vector3, c: Color, energy: float, rng: float, dur: float) -> void:
	# usa la luce libera (o quella più vecchia): massimo MAX_LIGHTS contemporanee
	var best := 0
	for i in MAX_LIGHTS:
		if _light_t[i] <= 0.0:
			best = i
			break
		if _light_t[i] < _light_t[best]:
			best = i
	var l := _lights[best]
	l.position = pos + Vector3(0, 1.5, 0)
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.visible = true
	l.set_meta("e0", energy)
	l.set_meta("dur", dur)
	_light_t[best] = dur


func click_indicator(pos: Vector3, attack: bool) -> void:
	var c := Color(1.0, 0.3, 0.25, 1.0) if attack else Color(0.4, 1.0, 0.5, 1.0)
	_ring(pos, c, 1.1, 0.3, 0.35, 0.25)


func meteor_warning(pos: Vector3, radius: float, dur: float) -> void:
	_ring(pos, Color(1.0, 0.25, 0.1, 0.9), radius, radius, dur, 0.06, 0.35)
	var m := _take("fx_meteor", _fx_factory("meteor"))
	m.position = pos + Vector3(6, 26, -6)
	_active.append({"node": m, "t": 0.0, "dur": dur, "kind": "meteor", "from": m.position, "to": pos})


## Effetti nominati (dagli eventi "fx" del server).
func effect(name: String, pos: Vector3, team: int) -> void:
	var fire := Color(1.0, 0.5, 0.12) if team == 0 else Color(0.7, 0.3, 1.0)
	var burst := "burst_fire" if team == 0 else "burst_violet"
	match name:
		"explosion":
			_particles("explosion" if team == 0 else "explosion_dire", pos + Vector3(0, 0.8, 0))
			_ring(pos, Color(fire, 0.9), 0.5, 3.2, 0.45, 0.2)
			_flash_light(pos, fire, 6.0, 10.0, 0.4)
			shake = maxf(shake, 0.15)
		"blink_out":
			_particles(burst, pos)
			_ring(pos, Color(fire, 0.9), 1.6, 0.2, 0.4, 0.2)
		"blink_in":
			_particles(burst, pos)
			_ring(pos, Color(fire, 0.9), 0.2, 2.2, 0.4, 0.2)
			_flash_light(pos, fire, 4.0, 7.0, 0.35)
		"shockwave":
			_ring(pos, Color(0.4, 0.75, 1.0, 1.0), 0.5, 5.2, 0.5, 0.18, 0.15)
			_ring(pos, Color(fire, 1.0), 0.3, 4.6, 0.45, 0.1)
			_particles(burst, pos)
			_flash_light(pos, Color(0.5, 0.75, 1.0), 5.0, 9.0, 0.4)
			shake = maxf(shake, 0.2)
		"meteor_hit":
			_particles("big_explosion", pos + Vector3(0, 1, 0))
			_ring(pos, Color(1.0, 0.45, 0.1, 1.0), 1.0, 6.5, 0.6, 0.2, 0.3)
			_flash_light(pos, Color(1.0, 0.5, 0.15), 10.0, 18.0, 0.6)
			shake = maxf(shake, 0.7)
		"levelup":
			_column(pos, Color(1.0, 0.85, 0.35, 0.9), 1.0, 7.0, 1.0)
			_ring(pos, Color(1.0, 0.85, 0.3, 1.0), 0.5, 3.5, 0.8, 0.15)
			_particles("burst_gold", pos)
		"respawn":
			_column(pos, Color(fire, 0.9), 1.3, 9.0, 1.0)
			_particles(burst, pos)
		"learn", "buy":
			_particles("burst_gold", pos)
		"potion":
			_particles("burst_heal", pos)
		"tower_destroyed":
			_particles("big_explosion", pos + Vector3(0, 4, 0))
			_particles("burst_dust", pos)
			_flash_light(pos + Vector3(0, 3, 0), Color(1.0, 0.6, 0.3), 10.0, 20.0, 0.8)
			shake = maxf(shake, 0.6)
		"ancient_destroyed":
			_particles("big_explosion", pos + Vector3(0, 6, 0))
			_particles("big_explosion", pos + Vector3(3, 2, 2))
			_particles("big_explosion", pos + Vector3(-3, 3, -2))
			_ring(pos, Color(1.0, 0.6, 0.2, 1.0), 2.0, 20.0, 1.2, 0.1, 0.2)
			_flash_light(pos + Vector3(0, 5, 0), Color(1.0, 0.7, 0.4), 16.0, 40.0, 1.5)
			shake = 1.2
		"hit_spark":
			pass


func _process(delta: float) -> void:
	_update_projectiles(delta)
	var i := 0
	while i < _active.size():
		var a: Dictionary = _active[i]
		a.t += delta
		var k: float = clampf(a.t / a.dur, 0.0, 1.0)
		match a.kind:
			"ring":
				var r: float = lerpf(a.r0, a.r1, 1.0 - pow(1.0 - k, 2.0))
				a.node.scale = Vector3(r, 1, r)
				(a.node.material_override as ShaderMaterial).set_shader_parameter("fade", 1.0 - k * k)
			"column":
				var r2: float = a.r * (1.0 - k * 0.6)
				a.node.scale.x = r2
				a.node.scale.z = r2
				(a.node.material_override as ShaderMaterial).set_shader_parameter("fade", 1.0 - k)
			"meteor":
				a.node.position = (a.from as Vector3).lerp(a.to, k * k)
		if a.t >= a.dur:
			_give(a.node)
			_active.remove_at(i)
		else:
			i += 1
	for j in MAX_LIGHTS:
		if _light_t[j] > 0.0:
			_light_t[j] -= delta
			var l := _lights[j]
			var dur: float = l.get_meta("dur", 0.5)
			l.light_energy = float(l.get_meta("e0", 1.0)) * clampf(_light_t[j] / dur, 0.0, 1.0)
			if _light_t[j] <= 0.0:
				l.visible = false
	shake = maxf(0.0, shake - delta * 2.0)
