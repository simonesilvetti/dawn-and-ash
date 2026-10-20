class_name MapBuilder
extends RefCounted
## Costruisce la parte statica della mappa: ambiente, luci, terreno, vegetazione (MultiMesh), decorazioni.
## Le parti dinamiche (edifici, unità) sono UnitView.

const ENV := "res://assets/models/env/"

static var _mesh_cache: Dictionary = {}
static var _foliage_mats: Dictionary = {}


static func build(root: Node3D, quality: int) -> void:
	_build_environment(root, quality)
	_build_ground(root)
	_build_foliage(root, quality)
	_build_props(root)


# --- Ambiente e luci ---------------------------------------------------------

static func _build_environment(root: Node3D, quality: int) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.85, 0.80, 0.70)
	sm.ground_bottom_color = Color(0.25, 0.22, 0.18)
	sm.ground_horizon_color = Color(0.75, 0.70, 0.60)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_color = Color(0.85, 0.82, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.80, 0.72)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.3
	env.glow_enabled = quality >= 1
	env.glow_intensity = 0.6
	env.glow_strength = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = quality >= 2
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0 if quality < 2 else 110.0
	sun.directional_shadow_blend_splits = quality >= 2
	root.add_child(sun)


# --- Terreno -----------------------------------------------------------------

static func _build_ground(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(Game.MAP_HALF * 2.0 + 60.0, Game.MAP_HALF * 2.0 + 60.0)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ground.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	nt.noise = fn
	mat.set_shader_parameter("noise_tex", nt)
	mat.set_shader_parameter("lane_a", Game.LANE_A)
	mat.set_shader_parameter("lane_b", Game.LANE_B)
	mat.set_shader_parameter("lane_w", Game.LANE_HALF_WIDTH)
	mat.set_shader_parameter("base_r", MapData.BASE_CENTER[0])
	mat.set_shader_parameter("base_d", MapData.BASE_CENTER[1])
	mat.set_shader_parameter("base_rad", Game.BASE_RADIUS)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# --- Vegetazione --------------------------------------------------------------

## Restituisce la prima Mesh contenuta in un modello glTF (cache).
static func model_mesh(file: String) -> Mesh:
	if _mesh_cache.has(file):
		return _mesh_cache[file]
	var ps: PackedScene = load(ENV + file)
	var mesh: Mesh = null
	if ps:
		var n := ps.instantiate()
		for c in n.find_children("*", "MeshInstance3D", true, false):
			mesh = (c as MeshInstance3D).mesh
			break
		n.free()
	_mesh_cache[file] = mesh
	return mesh


static func _foliage_material(tint: Color) -> ShaderMaterial:
	var key := tint.to_html()
	if _foliage_mats.has(key):
		return _foliage_mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/foliage.gdshader")
	mat.set_shader_parameter("albedo_tex", load(ENV + "hexagons_medieval.png"))
	mat.set_shader_parameter("tint", tint)
	_foliage_mats[key] = mat
	return mat


static func _build_foliage(root: Node3D, quality: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var density: float = [0.35, 0.7, 1.0][clampi(quality, 0, 2)]
	var types := ["trees_A_large", "trees_A_medium", "trees_B_large", "trees_B_medium", "trees_A_small", "trees_B_small", "tree_single_A", "tree_single_B"]
	var buckets: Dictionary = {}       # (tipo, cenere) -> Array[Transform3D]
	var placed: Array[Vector2] = []
	var grid: Dictionary = {}
	var cell := 6.0
	var attempts := int(5200 * density)
	var limit := Game.MAP_HALF - 12.0
	for i in attempts:
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		# fuori dall'area percorribile con un margine (la vegetazione fa da "muro")
		if MapData.is_walkable(p, -4.0):
			continue
		var c := Vector2i(floori(p.x / cell), floori(p.y / cell))
		var ok := true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for q in grid.get(c + Vector2i(dx, dy), []):
					if q.distance_to(p) < 5.0:
						ok = false
		if not ok:
			continue
		var arr: Array = grid.get(c, [])
		arr.append(p)
		grid[c] = arr
		placed.append(p)
		# vicino alla corsia alberi singoli e piccoli, lontano boschi fitti
		var dist_lane := p.distance_to(MapData.closest_on_lane(p))
		var t: String
		if dist_lane < Game.LANE_HALF_WIDTH + 8.0:
			t = types[rng.randi_range(4, 7)]
		else:
			t = types[rng.randi_range(0, 5)]
		var ash := p.dot(MapData.lane_dir()) > 25.0 + rng.randf_range(-15.0, 15.0)
		var key := t + ("|ash" if ash else "")
		var s := rng.randf_range(4.2, 5.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		var list: Array = buckets.get(key, [])
		list.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		buckets[key] = list
	# Montagne sul bordo esterno per chiudere la vista
	var mountains := ["mountain_A_grass_trees", "mountain_B_grass_trees", "mountain_C_grass_trees", "hills_A_trees", "hills_B_trees"]
	var steps := 64
	for i in steps:
		var a := TAU * i / steps
		var r := Game.MAP_HALF + rng.randf_range(0.0, 10.0)
		var p := Vector2(cos(a), sin(a)) * r
		p = p.clamp(Vector2(-Game.MAP_HALF - 8, -Game.MAP_HALF - 8), Vector2(Game.MAP_HALF + 8, Game.MAP_HALF + 8))
		var t: String = mountains[rng.randi_range(0, mountains.size() - 1)]
		var ash := p.dot(MapData.lane_dir()) > 20.0
		var s := rng.randf_range(10.0, 15.0)
		var key := t + ("|ash" if ash else "")
		var list: Array = buckets.get(key, [])
		list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(p.x, -0.3, p.y)))
		buckets[key] = list
	# Rocce lungo i bordi della corsia
	for i in int(260 * density):
		var t := rng.randf()
		var lp := Game.LANE_A.lerp(Game.LANE_B, t)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := lp + MapData.lane_normal() * side * (Game.LANE_HALF_WIDTH + rng.randf_range(-0.5, 4.0))
		if MapData.is_walkable(p, -1.0) and p.distance_to(MapData.closest_on_lane(p)) < Game.LANE_HALF_WIDTH - 1.0:
			continue
		var rt: String = "rock_single_" + ["A", "B", "C", "D", "E"][rng.randi_range(0, 4)]
		var s := rng.randf_range(4.0, 9.0)
		var key: String = rt + ("|ash" if p.dot(MapData.lane_dir()) > 25.0 else "")
		var list: Array = buckets.get(key, [])
		list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, -0.05, p.y)))
		buckets[key] = list

	var folder := Node3D.new()
	folder.name = "Foliage"
	root.add_child(folder)
	for key in buckets:
		var parts: PackedStringArray = (key as String).split("|")
		var mesh := model_mesh(parts[0] + ".gltf")
		if mesh == null:
			continue
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var ash: bool = parts.size() > 1
		var is_rock := parts[0].begins_with("rock")
		var tint := Color(1, 1, 1)
		if ash:
			tint = Color(0.72, 0.55, 0.50) if not is_rock else Color(0.6, 0.55, 0.58)
		var mat := _foliage_material(tint)
		if is_rock or parts[0].begins_with("mountain") or parts[0].begins_with("hills"):
			mat = mat.duplicate()
			mat.set_shader_parameter("sway", 0.0)
		mmi.material_override = mat
		# Solo il bosco vicino proietta ombre (costo contenuto)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality >= 1 and not parts[0].begins_with("mountain") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 0.0
		folder.add_child(mmi)


# --- Decorazioni ---------------------------------------------------------------

static func _place(root: Node3D, file: String, p: Vector2, s: float, rot: float, y: float = 0.0) -> Node3D:
	var ps: PackedScene = load(ENV + file)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	n.position = Vector3(p.x, y, p.y)
	n.rotation.y = rot
	n.scale = Vector3.ONE * s
	root.add_child(n)
	return n


static func _build_props(root: Node3D) -> void:
	var folder := Node3D.new()
	folder.name = "Props"
	root.add_child(folder)
	var colors := ["green", "red"]
	for t in [0, 1]:
		var c: Vector2 = MapData.BASE_CENTER[t]
		var dir := MapData.team_dir(t)
		var nrm := MapData.lane_normal()
		var face := -dir.angle() + PI * 0.5
		# caserme e tiro con l'arco ai lati della base
		_place(folder, "building_barracks_%s.gltf" % colors[t], c + nrm * 17.0 - dir * 4.0, 4.0, face)
		_place(folder, "building_archeryrange_%s.gltf" % colors[t], c - nrm * 17.0 - dir * 4.0, 3.6, face)
		# stendardi lungo l'ingresso della base
		for k in [-1, 1]:
			for j in 3:
				_place(folder, "flag_%s.gltf" % colors[t], c + dir * (8.0 + j * 5.0) + nrm * k * 12.0, 5.0, face)
		# tende, barili, casse
		_place(folder, "tent.gltf", c + nrm * 11.0 - dir * 14.0, 4.5, face + 0.4)
		_place(folder, "tent.gltf", c - nrm * 11.0 - dir * 14.0, 4.5, face - 0.4)
		_place(folder, "barrel.gltf", c + nrm * 14.0 + dir * 2.0, 5.0, 0.3)
		_place(folder, "barrel.gltf", c + nrm * 15.0 + dir * 3.0, 5.0, 1.2)
		_place(folder, "crate_A_big.gltf", c - nrm * 14.0 + dir * 2.0, 5.0, 0.5)
		_place(folder, "weaponrack.gltf", c - nrm * 15.5 + dir * 0.0, 5.0, face)
	# ninfee e piante nel fiume
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var rdir := MapData.lane_normal()
	for i in 24:
		var along := rng.randf_range(-110.0, 110.0)
		var p := rdir * along
		var off := -sin(along * 0.045) * 6.0 - sin(along * 0.13) * 1.5
		p += MapData.lane_dir() * (off + rng.randf_range(-3.5, 3.5))
		if p.distance_to(MapData.closest_on_lane(p)) < Game.LANE_HALF_WIDTH:
			continue
		var f: String = ["waterlily_A.gltf", "waterlily_B.gltf", "waterplant_A.gltf", "waterplant_B.gltf"][rng.randi_range(0, 3)]
		_place(folder, f, p, rng.randf_range(4.0, 6.0), rng.randf() * TAU, 0.02)
