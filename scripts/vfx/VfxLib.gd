class_name VfxLib
extends RefCounted
## Fabbrica di effetti particellari e materiali condivisi (creati una volta, poi riutilizzati).

static var _cache: Dictionary = {}


static func glow_material(c: Color, intensity: float = 2.5) -> ShaderMaterial:
	var key := "glow_%s_%.2f" % [c.to_html(), intensity]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/vfx/glow.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("intensity", intensity)
	_cache[key] = m
	return m


static func _particle_material(c: Color) -> StandardMaterial3D:
	var key := "pmat_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = _soft_dot()
	_cache[key] = m
	return m


static func _soft_dot() -> Texture2D:
	if _cache.has("dot"):
		return _cache.dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_cache.dot = gt
	return gt


static func quad(size: float, c: Color) -> QuadMesh:
	var key := "quad_%.2f_%s" % [size, c.to_html()]
	if _cache.has(key):
		return _cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _particle_material(c)
	_cache[key] = q
	return q


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / maxf(1.0, colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _make(amount: int, lifetime: float, one_shot: bool, size: float, c: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.draw_pass_1 = quad(size, c)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 14, 16))
	return p


## Fiammella continua (bastone di Kael).
static func make_flame(c: Color) -> GPUParticles3D:
	var p := _make(24, 0.6, false, 0.28, c)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 20.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.0
	m.gravity = Vector3(0, 1.2, 0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color_ramp = _ramp([Color(1, 1, 0.8, 1), c, Color(c, 0.0)])
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.08
	p.process_material = m
	p.local_coords = false
	return p


## Zampillo luminoso della fontana.
static func make_fountain(c: Color) -> GPUParticles3D:
	var p := _make(60, 1.6, false, 0.35, c)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 5.0
	m.gravity = Vector3(0, -6, 0)
	m.color_ramp = _ramp([Color(1, 1, 1, 1), c, Color(c, 0.0)])
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.5
	p.process_material = m
	return p


## Esplosione one-shot (fuoco). scale_mult ingrandisce l'effetto.
static func make_explosion(c: Color, scale_mult: float = 1.0) -> GPUParticles3D:
	var p := _make(int(48 * clampf(scale_mult, 1.0, 3.0)), 0.9, true, 0.9 * scale_mult, c)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 3.0 * scale_mult
	m.initial_velocity_max = 8.0 * scale_mult
	m.gravity = Vector3(0, 2.0, 0)
	m.damping_min = 4.0
	m.damping_max = 8.0
	m.scale_min = 0.5
	m.scale_max = 1.4
	m.color_ramp = _ramp([Color(1, 1, 0.85, 1), c, Color(0.35, 0.3, 0.3, 0.6), Color(0.2, 0.2, 0.2, 0.0)])
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.4 * scale_mult
	p.process_material = m
	return p


## Scintille/braci che salgono (scatto, salita di livello, rinascita).
static func make_burst(c: Color, amount: int = 40, up: float = 4.0, radius: float = 0.8) -> GPUParticles3D:
	var p := _make(amount, 1.0, true, 0.3, c)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = up * 0.5
	m.initial_velocity_max = up
	m.gravity = Vector3(0, -1.0, 0)
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.color_ramp = _ramp([Color(1, 1, 1, 1), c, Color(c, 0.0)])
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = radius
	m.emission_ring_inner_radius = radius * 0.6
	m.emission_ring_height = 0.2
	p.process_material = m
	return p


## Scia per proiettili (coordinate globali).
static func make_trail(c: Color, size: float = 0.35) -> GPUParticles3D:
	var p := _make(32, 0.35, false, size, c)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.5
	m.gravity = Vector3.ZERO
	m.scale_min = 0.6
	m.scale_max = 1.0
	m.color_ramp = _ramp([Color(1, 1, 0.9, 1), c, Color(c, 0.0)])
	p.process_material = m
	p.local_coords = false
	return p


# --- Effetti a strati (Grafica v2) ------------------------------------------------

static func noise_tex() -> Texture2D:
	return MapBuilder.noise_texture()


## Materiale delle particelle "a sbuffo" (puff.gdshader): additivo per il fuoco, normale per il fumo.
static func puff_material(additive: bool, tint: Color = Color(1, 1, 1, 1), intensity: float = 1.0) -> ShaderMaterial:
	var key := "puff_%s_%s_%.2f" % [additive, tint.to_html(), intensity]
	if _cache.has(key):
		return _cache[key]
	var skey := "puff_shader_%s" % additive
	if not _cache.has(skey):
		var sh := Shader.new()
		sh.code = (load("res://scripts/vfx/puff.gdshader") as Shader).code.replace("BLEND_MODE", "blend_add" if additive else "blend_mix")
		_cache[skey] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache[skey]
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("intensity", intensity)
	_cache[key] = m
	return m


static func _puff_quad(size: float, additive: bool, tint: Color = Color(1, 1, 1, 1), intensity: float = 1.0) -> QuadMesh:
	var key := "pquad_%.2f_%s_%s_%.2f" % [size, additive, tint.to_html(), intensity]
	if _cache.has(key):
		return _cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = puff_material(additive, tint, intensity)
	_cache[key] = q
	return q


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _emitter(amount: int, lifetime: float, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-12, -3, -12), Vector3(24, 18, 24))
	return p


## Esplosione a strati: lampo, palle di fuoco, fumo, scintille (s = scala).
static func make_blast(c: Color, s: float, smoke: bool, sparks: bool) -> Node3D:
	var root := Node3D.new()
	# lampo iniziale
	# le esplosioni grandi sovrappongono molte particelle additive: intensità ridotta per non saturare al bianco
	var k := pow(clampf(s, 1.0, 3.0), 1.2)
	var flash := _emitter(1, 0.22, _puff_quad(3.2 * s, true, Color(1, 0.95, 0.8), 3.0 / k))
	var fm := ParticleProcessMaterial.new()
	fm.gravity = Vector3.ZERO
	fm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.2)])
	fm.color_ramp = _ramp([Color(1, 1, 1, 1), Color(1, 0.9, 0.6, 0.6), Color(1, 0.8, 0.5, 0.0)])
	flash.process_material = fm
	root.add_child(flash)
	# fuoco
	var fire := _emitter(int(22 * clampf(s, 1.0, 2.5)), 0.75, _puff_quad(1.5 * s, true, Color(1, 1, 1), 2.2 / k))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35 * s
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 2.0 * s
	m.initial_velocity_max = 5.5 * s
	m.damping_min = 5.0
	m.damping_max = 9.0
	m.gravity = Vector3(0, 2.5, 0)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.scale_min = 0.6
	m.scale_max = 1.3
	m.scale_curve = _curve([Vector2(0, 0.5), Vector2(0.25, 1.0), Vector2(1, 1.25)])
	var hot := Color(1, 0.95, 0.8, 1) if s < 1.5 else Color(1, 0.78, 0.42, 1)
	m.color_ramp = _ramp([hot, Color(c.r, c.g, c.b, 1), c.darkened(0.5), Color(0.25, 0.1, 0.05, 0)])
	fire.process_material = m
	root.add_child(fire)
	if smoke:
		var sm := _emitter(int(10 * clampf(s, 1.0, 2.5)), 1.7, _puff_quad(1.8 * s, false, Color(0.22, 0.2, 0.2, 0.75), 1.0))
		var smm := ParticleProcessMaterial.new()
		smm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		smm.emission_sphere_radius = 0.6 * s
		smm.direction = Vector3.UP
		smm.spread = 60.0
		smm.initial_velocity_min = 1.0 * s
		smm.initial_velocity_max = 2.5 * s
		smm.damping_min = 1.0
		smm.damping_max = 2.0
		smm.gravity = Vector3(0, 1.2, 0)
		smm.angle_min = -180.0
		smm.angle_max = 180.0
		smm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.6)])
		smm.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		sm.process_material = smm
		sm.explosiveness = 0.6
		root.add_child(sm)
	if sparks:
		var sp := _emitter(int(26 * clampf(s, 1.0, 2.0)), 0.7, quad(0.12 * s, Color(1.0, 0.75, 0.35)))
		var spm := ParticleProcessMaterial.new()
		spm.direction = Vector3.UP
		spm.spread = 70.0
		spm.initial_velocity_min = 6.0 * s
		spm.initial_velocity_max = 12.0 * s
		spm.gravity = Vector3(0, -16, 0)
		spm.damping_min = 1.0
		spm.damping_max = 2.0
		spm.color_ramp = _ramp([Color(1, 1, 0.9, 1), Color(1, 0.7, 0.3, 1), Color(1, 0.4, 0.1, 0)])
		sp.process_material = spm
		root.add_child(sp)
	return root


## Scintille dei colpi corpo a corpo.
static func make_hit_sparks(c: Color) -> GPUParticles3D:
	var sp := _emitter(10, 0.35, quad(0.14, c))
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3.UP
	spm.spread = 80.0
	spm.initial_velocity_min = 3.0
	spm.initial_velocity_max = 6.0
	spm.gravity = Vector3(0, -12, 0)
	spm.color_ramp = _ramp([Color(1, 1, 0.95, 1), c, Color(c, 0.0)])
	sp.process_material = spm
	sp.explosiveness = 1.0
	return sp


## Polvere a terra (morte dei creep, crollo).
static func make_dust(s: float) -> GPUParticles3D:
	var p := _emitter(int(10 * s), 1.2, _puff_quad(1.2 * s, false, Color(0.62, 0.55, 0.45, 0.6), 1.0))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 0.6 * s
	m.emission_ring_inner_radius = 0.2 * s
	m.emission_ring_height = 0.1
	m.direction = Vector3.UP
	m.spread = 70.0
	m.initial_velocity_min = 0.6 * s
	m.initial_velocity_max = 1.6 * s
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.gravity = Vector3(0, 0.3, 0)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.5)])
	m.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.process_material = m
	return p


## Frammenti di roccia che schizzano (impatto della meteora, crollo degli edifici).
static func make_debris(s: float) -> GPUParticles3D:
	var rock := MapBuilder.model_mesh("rock_single_C.gltf")
	var mesh: Mesh = rock if rock else BoxMesh.new()
	var p := _emitter(int(14 * s), 1.3, mesh)
	p.material_override = MapBuilder.static_material(Color(0.55, 0.45, 0.42), 0.8)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 45.0
	m.initial_velocity_min = 6.0 * s
	m.initial_velocity_max = 11.0 * s
	m.gravity = Vector3(0, -22, 0)
	m.scale_min = 0.12 * s
	m.scale_max = 0.3 * s
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -360.0
	m.angular_velocity_max = 360.0
	m.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	p.process_material = m
	return p


## Texture della bruciatura a terra (generata una volta: macchia scura irregolare con bordo sfumato).
static func scorch_texture() -> Texture2D:
	if _cache.has("scorch"):
		return _cache.scorch
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	n.fractal_octaves = 3
	var img := Image.create(128, 128, true, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf(1.0 - smoothstep(0.35, 1.0, d + (v - 0.5) * 0.55), 0.0, 1.0)
			var inner := 1.0 - smoothstep(0.0, 0.5, d)
			img.set_pixel(x, y, Color(0.08 + v * 0.06 + inner * 0.05, 0.06 + v * 0.04, 0.05, a * 0.85))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache.scorch = t
	return t


## Alone morbido sempre rivolto alla telecamera (attorno ai proiettili).
static func halo_material(c: Color) -> StandardMaterial3D:
	var key := "halo_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _soft_dot()
	m.albedo_color = Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, 0.55)
	m.no_depth_test = false
	_cache[key] = m
	return m
