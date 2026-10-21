class_name Vfx
extends Node3D
## Effetti visivi in scena con pool: proiettili (nucleo + coda continua), esplosioni a strati, anelli,
## muri di fiamme, bruciature a terra (Decal), luci temporanee.
## Riceve gli eventi da World; tutto è puramente visivo (nessuna logica di gioco).

const MAX_LIGHTS := 4
const MAX_DECALS := 10
const MAX_SPARKS := 12

var world: Node                       # World (per le posizioni visive dei bersagli e la telecamera)
var quality: int = 1
var projectiles: Dictionary = {}      # pid -> {node, type, target, pos, dir, speed, dist, max, tail}
var _pools: Dictionary = {}           # chiave -> Array[Node3D]
var _active: Array = []               # effetti a tempo: {node, t, dur, kind, ...}
var _lights: Array[OmniLight3D] = []
var _light_t: Array[float] = []
var _decals: Array[Decal] = []
var _decal_t: Array[float] = []
var _decal_next := 0
var _sparks_active := 0
var _ring_mesh: QuadMesh
var _ring_shader: Shader
var shake: float = 0.0                # intensità della scossa della telecamera (letta da CameraRig)

# Aspetto dei proiettili: [raggio del nucleo, lunghezza coda, larghezza coda, fuoco animato]
const PROJ_LOOK := {
	"bolt": [0.26, 2.2, 0.55, true],
	"fireball": [0.6, 4.5, 1.5, true],
	"creep_bolt": [0.17, 1.2, 0.3, false],
	"tower": [0.38, 3.0, 0.8, false],
	"fountain": [0.38, 3.0, 0.8, false],
}


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
	if quality >= 1:
		for i in MAX_DECALS:
			var d := Decal.new()
			d.texture_albedo = VfxLib.scorch_texture()
			d.visible = false
			d.cull_mask = 1
			d.upper_fade = 0.3
			d.lower_fade = 0.3
			add_child(d)
			_decals.append(d)
			_decal_t.append(0.0)


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


## Precarica i pool e fa comparire una volta ogni effetto (fuori vista) per compilare gli shader
## prima della partita: evita gli scatti alla prima esplosione/abilità.
func warmup() -> void:
	var tmp: Array = []
	for t in ["bolt_0", "bolt_1", "creep_bolt_0", "creep_bolt_1", "tower_0", "tower_1", "fireball_0", "fireball_1", "fountain_0", "fountain_1", "siege_0", "siege_1"]:
		for i in (6 if not t.begins_with("fireball") else 2):
			var n := _take("proj_" + t, _proj_factory(t))
			n.position = Vector3(0, -40, 0)
			tmp.append(n)
	for k in ["blast", "blast_dire", "big_blast", "burst_fire", "burst_violet", "burst_gold", "burst_heal", "burst_dust", "ring", "column", "meteor", "flame_wall", "sparks", "dust", "debris"]:
		var e: Node3D = _take("fx_" + k, _fx_factory(k))
		e.position = Vector3(0, -40, 0)
		_restart(e)
		tmp.append(e)
	# restituisce tutto al pool dopo un paio di frame (il tempo di compilare le pipeline)
	await get_tree().process_frame
	await get_tree().process_frame
	for n in tmp:
		if is_instance_valid(n):
			_give(n)


static func _restart(n: Node3D) -> float:
	var life := 0.0
	var list: Array = [n] if n is GPUParticles3D else n.get_children()
	for c in list:
		if c is GPUParticles3D:
			var p := c as GPUParticles3D
			p.restart()
			p.emitting = true
			life = maxf(life, p.lifetime)
	return life


# --- Proiettili ----------------------------------------------------------------

func _proj_factory(key: String) -> Callable:
	return func() -> Node3D:
		var root := Node3D.new()
		var team := int(key.right(1))
		var kind := key.left(key.length() - 2)
		var fire := Color(1.0, 0.45, 0.1) if team == 0 else Color(0.75, 0.3, 1.0)
		var c: Color
		match kind:
			"bolt", "fireball": c = fire
			"creep_bolt": c = Color(1.0, 0.85, 0.45) if team == 0 else Color(0.65, 0.35, 0.95)
			"tower", "fountain": c = Game.TEAM_COLORS[team].lightened(0.2)
			_: c = Color(0.6, 0.55, 0.5)
		if kind == "siege":
			# roccia lanciata dai creep d'assedio, con una scia di polvere
			var mi := MeshInstance3D.new()
			mi.mesh = MapBuilder.model_mesh("rock_single_B.gltf")
			mi.scale = Vector3.ONE * 0.35
			mi.material_override = MapBuilder.static_material(Color(0.6, 0.52, 0.48) if team == 0 else Color(0.42, 0.36, 0.4), 0.8)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			return root
		var look: Array = PROJ_LOOK.get(kind, [0.3, 1.5, 0.4, false])
		var r: float = look[0]
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 12
		sm.rings = 6
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh = sm
		if look[3]:
			var fm := ShaderMaterial.new()
			fm.shader = load("res://scripts/vfx/fire.gdshader")
			fm.set_shader_parameter("noise_tex", VfxLib.noise_tex())
			fm.set_shader_parameter("color", c)
			fm.set_shader_parameter("intensity", 2.6)
			fm.set_shader_parameter("scroll", 1.6)
			mi.material_override = fm
		else:
			mi.material_override = VfxLib.glow_material(c, 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		# alone luminoso attorno al nucleo (billboard morbido)
		var halo := MeshInstance3D.new()
		var hq := QuadMesh.new()
		hq.size = Vector2.ONE * r * 5.0
		halo.mesh = hq
		halo.material_override = VfxLib.halo_material(c)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(halo)
		# coda continua (orientata ogni frame verso la telecamera)
		var tail := MeshInstance3D.new()
		tail.name = "Tail"
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		tail.mesh = q
		var tm := ShaderMaterial.new()
		tm.shader = load("res://scripts/vfx/tail.gdshader")
		tm.set_shader_parameter("noise_tex", VfxLib.noise_tex())
		tm.set_shader_parameter("color", c)
		tm.set_shader_parameter("intensity", 2.2 if look[3] else 1.8)
		tail.material_override = tm
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tail.set_meta("len", look[1])
		tail.set_meta("wid", look[2])
		root.add_child(tail)
		if look[3] and quality >= 1:
			# poche braci che si staccano dalla coda
			var tr := VfxLib.make_trail(c, r * 0.55)
			tr.amount = 14
			tr.lifetime = 0.5
			tr.name = "Trail"
			root.add_child(tr)
		if kind == "fireball" and quality >= 1:
			var l := OmniLight3D.new()
			l.light_color = c
			l.light_energy = 2.5
			l.omni_range = 7.0
			l.shadow_enabled = false
			root.add_child(l)
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
	var tail: MeshInstance3D = n.get_node_or_null("Tail")
	if tail:
		tail.visible = false     # compare dal secondo frame, quando la direzione è nota
	projectiles[pid] = {"node": n, "type": ptype, "target": target_id, "pos": start, "dir": dir, "speed": speed,
		"dist": 0.0, "max": max_dist if max_dist > 0.0 else 999.0, "tail": tail, "travel": 0.0}


func end_projectile(pid: int) -> void:
	var p: Dictionary = projectiles.get(pid, {})
	if p.is_empty():
		return
	projectiles.erase(pid)
	_give(p.node)


func _update_projectiles(delta: float) -> void:
	var finished: Array = []
	var cam_pos := Vector3.ZERO
	if world and world.cam:
		cam_pos = world.cam.camera.global_position
	for pid in projectiles:
		var p: Dictionary = projectiles[pid]
		var step: float = p.speed * delta
		var prev: Vector3 = p.pos
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
		p.travel += (p.pos - prev).length()
		var tail: MeshInstance3D = p.tail
		if tail and p.pos != prev:
			# quad allungato all'indietro lungo la direzione di volo e girato verso la telecamera
			var v: Vector3 = (p.pos - prev).normalized()
			var side := v.cross(cam_pos - p.pos).normalized()
			if side.length_squared() > 0.5:
				var length: float = minf(float(tail.get_meta("len")), p.travel + 0.3)
				var width: float = tail.get_meta("wid")
				tail.transform = Transform3D(Basis(v * length, side * width, v.cross(side)), -v * length * 0.45)
				tail.visible = true
	for pid in finished:
		end_projectile(pid)


# --- Effetti a tempo -----------------------------------------------------------

func _fx_factory(kind: String) -> Callable:
	return func() -> Node3D:
		match kind:
			"blast": return VfxLib.make_blast(Color(1.0, 0.45, 0.1), 1.0, quality >= 1, true)
			"blast_dire": return VfxLib.make_blast(Color(0.7, 0.3, 1.0), 1.0, quality >= 1, true)
			"big_blast": return VfxLib.make_blast(Color(1.0, 0.5, 0.15), 2.4, true, true)
			"burst_fire": return VfxLib.make_burst(Color(1.0, 0.5, 0.1), 40, 4.0, 0.8)
			"burst_violet": return VfxLib.make_burst(Color(0.7, 0.3, 1.0), 40, 4.0, 0.8)
			"burst_gold": return VfxLib.make_burst(Color(1.0, 0.85, 0.3), 60, 6.0, 1.0)
			"burst_heal": return VfxLib.make_burst(Color(0.4, 1.0, 0.5), 24, 2.0, 0.6)
			"burst_dust": return VfxLib.make_burst(Color(0.75, 0.7, 0.6), 30, 2.0, 0.6)
			"sparks": return VfxLib.make_hit_sparks(Color(1.0, 0.8, 0.45))
			"dust": return VfxLib.make_dust(1.0)
			"debris": return VfxLib.make_debris(1.0)
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
			"flame_wall":
				# muro di fiamme dell'onda d'urto: cilindro aperto con il fuoco che sale
				var mi := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 1.0
				cm.bottom_radius = 1.0
				cm.height = 1.0
				cm.radial_segments = 24
				cm.rings = 1
				cm.cap_top = false
				cm.cap_bottom = false
				mi.mesh = cm
				var m := ShaderMaterial.new()
				m.shader = load("res://scripts/vfx/fire.gdshader")
				m.set_shader_parameter("noise_tex", VfxLib.noise_tex())
				m.set_shader_parameter("wall", 1.0)
				m.set_shader_parameter("scroll", 1.8)
				m.set_shader_parameter("intensity", 2.2)
				m.render_priority = 1
				mi.material_override = m
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				return mi
			"meteor":
				var root := Node3D.new()
				var rock := MeshInstance3D.new()
				rock.mesh = MapBuilder.model_mesh("rock_single_B.gltf")
				rock.scale = Vector3.ONE * 0.9
				rock.material_override = MapBuilder.static_material(Color(0.35, 0.25, 0.22), 0.8)
				root.add_child(rock)
				var shell := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 1.5
				sm.height = 3.0
				sm.radial_segments = 14
				sm.rings = 7
				shell.mesh = sm
				var fm := ShaderMaterial.new()
				fm.shader = load("res://scripts/vfx/fire.gdshader")
				fm.set_shader_parameter("noise_tex", VfxLib.noise_tex())
				fm.set_shader_parameter("color", Color(1.0, 0.45, 0.1))
				fm.set_shader_parameter("intensity", 2.4)
				fm.set_shader_parameter("scroll", 2.5)
				shell.material_override = fm
				shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(shell)
				var tr := VfxLib.make_trail(Color(1.0, 0.5, 0.1), 2.2)
				tr.amount = 64
				root.add_child(tr)
				return root
		return Node3D.new()


func _group(kind: String, pos: Vector3) -> void:
	var n := _take("fx_" + kind, _fx_factory(kind))
	n.position = pos
	var life := _restart(n)
	_active.append({"node": n, "t": 0.0, "dur": life + 0.4, "kind": "particles"})


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


func _flame_wall(pos: Vector3, c: Color, r0: float, r1: float, h: float, dur: float) -> void:
	var mi := _take("fx_flame_wall", _fx_factory("flame_wall")) as MeshInstance3D
	mi.position = pos + Vector3(0, h * 0.5 - 0.1, 0)
	mi.scale = Vector3(r0, h, r0)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("fade", 1.0)
	_active.append({"node": mi, "t": 0.0, "dur": dur, "kind": "wall", "r0": r0, "r1": r1})


## Bruciatura a terra che svanisce lentamente (Decal, solo da qualità media).
func _scorch(pos: Vector3, r: float, dur: float = 6.0) -> void:
	if _decals.is_empty():
		return
	var i := _decal_next
	_decal_next = (_decal_next + 1) % MAX_DECALS
	var d := _decals[i]
	d.position = pos
	d.rotation.y = randf() * TAU
	d.size = Vector3(r * 2.0, 3.0, r * 2.0)
	d.modulate = Color(1, 1, 1, 1)
	d.visible = true
	d.set_meta("dur", dur)
	_decal_t[i] = dur


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
	_restart(m)
	_active.append({"node": m, "t": 0.0, "dur": dur, "kind": "meteor", "from": m.position, "to": pos})


## Scintille di un colpo fisico (limitate: in uno scontro grande non si accumulano).
func hit_sparks(pos: Vector3) -> void:
	if _sparks_active >= MAX_SPARKS or quality < 1:
		return
	_sparks_active += 1
	var n := _take("fx_sparks", _fx_factory("sparks"))
	n.position = pos
	_restart(n)
	_active.append({"node": n, "t": 0.0, "dur": 0.6, "kind": "sparks"})


## Effetti nominati (dagli eventi "fx" del server).
func effect(name: String, pos: Vector3, team: int) -> void:
	var fire := Color(1.0, 0.5, 0.12) if team == 0 else Color(0.7, 0.3, 1.0)
	var burst := "burst_fire" if team == 0 else "burst_violet"
	match name:
		"explosion":
			_group("blast" if team == 0 else "blast_dire", pos + Vector3(0, 0.9, 0))
			_ring(pos, Color(fire, 0.9), 0.5, 3.4, 0.45, 0.2)
			_flash_light(pos, fire, 7.0, 11.0, 0.45)
			_scorch(pos, 1.8, 5.0)
			shake = maxf(shake, 0.18)
		"blink_out":
			_particles(burst, pos)
			_column(pos, Color(fire, 0.8), 0.9, 4.0, 0.35)
			_ring(pos, Color(fire, 0.9), 1.6, 0.2, 0.4, 0.2)
		"blink_in":
			_particles(burst, pos)
			_column(pos, Color(fire, 0.8), 0.6, 4.5, 0.4)
			_ring(pos, Color(fire, 0.9), 0.2, 2.4, 0.4, 0.2)
			_flash_light(pos, fire, 4.0, 7.0, 0.35)
		"shockwave":
			_flame_wall(pos, Color(1.0, 0.5, 0.15), 0.6, 5.0, 1.8, 0.5)
			_ring(pos, Color(0.4, 0.75, 1.0, 1.0), 0.5, 5.2, 0.5, 0.18, 0.15)
			_ring(pos, Color(fire, 1.0), 0.3, 4.6, 0.45, 0.1)
			_particles(burst, pos)
			if quality >= 1:
				_group("dust", pos)
			_flash_light(pos, Color(0.5, 0.75, 1.0), 5.0, 9.0, 0.4)
			_scorch(pos, 4.2, 4.0)
			shake = maxf(shake, 0.2)
		"meteor_hit":
			_group("big_blast", pos + Vector3(0, 1.2, 0))
			_group("debris", pos + Vector3(0, 0.5, 0))
			_flame_wall(pos, Color(1.0, 0.45, 0.1), 1.0, 6.5, 2.6, 0.6)
			_ring(pos, Color(1.0, 0.45, 0.1, 1.0), 1.0, 6.5, 0.6, 0.2, 0.3)
			_flash_light(pos, Color(1.0, 0.5, 0.15), 12.0, 20.0, 0.7)
			_scorch(pos, 6.0, 8.0)
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
		"creep_death":
			if quality >= 1:
				_group("dust", pos)
		"tower_destroyed":
			_group("big_blast", pos + Vector3(0, 4, 0))
			_group("debris", pos + Vector3(0, 2, 0))
			_group("dust", pos)
			_particles("burst_dust", pos)
			_flash_light(pos + Vector3(0, 3, 0), Color(1.0, 0.6, 0.3), 10.0, 20.0, 0.8)
			_scorch(pos, 5.0, 12.0)
			shake = maxf(shake, 0.6)
		"ancient_destroyed":
			# esplosioni scaglionate: più drammatiche e senza sovrapporsi fino a saturare al bianco
			_group("big_blast", pos + Vector3(0, 6, 0))
			_group("debris", pos + Vector3(0, 3, 0))
			for k in 2:
				var off := Vector3(3, 2, 2) if k == 0 else Vector3(-3, 3, -2)
				get_tree().create_timer(0.35 * (k + 1)).timeout.connect(func():
					_group("big_blast", pos + off)
					shake = maxf(shake, 0.6))
			_ring(pos, Color(1.0, 0.6, 0.2, 1.0), 2.0, 20.0, 1.2, 0.1, 0.2)
			_flash_light(pos + Vector3(0, 5, 0), Color(1.0, 0.7, 0.4), 16.0, 40.0, 1.5)
			_scorch(pos, 9.0, 20.0)
			shake = 1.2
		"hit_spark":
			pass


func _particles(kind: String, pos: Vector3) -> void:
	_group(kind, pos)


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
			"wall":
				var r3: float = lerpf(a.r0, a.r1, 1.0 - pow(1.0 - k, 2.5))
				a.node.scale.x = r3
				a.node.scale.z = r3
				(a.node.material_override as ShaderMaterial).set_shader_parameter("fade", 1.0 - k * k)
			"meteor":
				a.node.position = (a.from as Vector3).lerp(a.to, k * k)
		if a.t >= a.dur:
			if a.kind == "sparks":
				_sparks_active -= 1
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
	for j in _decals.size():
		if _decal_t[j] > 0.0:
			_decal_t[j] -= delta
			var d := _decals[j]
			d.modulate.a = clampf(_decal_t[j] / (float(d.get_meta("dur", 5.0)) * 0.6), 0.0, 1.0)
			if _decal_t[j] <= 0.0:
				d.visible = false
	shake = maxf(0.0, shake - delta * 2.0)
