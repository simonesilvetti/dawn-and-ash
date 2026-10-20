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


static func _quad(size: float, c: Color) -> QuadMesh:
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
	p.draw_pass_1 = _quad(size, c)
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
