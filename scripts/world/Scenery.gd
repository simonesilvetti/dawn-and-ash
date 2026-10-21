class_name Scenery
extends RefCounted
## Dettagli dell'ambiente (Grafica v2, vedi wiki/concepts/piano-grafica-v2.md): vegetazione minuta a blocchi
## (ciuffi d'erba, fiori, cespugli, sassi), basi fortificate con un villaggio attorno, oggetti di scena lungo la
## corsia, falò e braci. Tutto puramente visivo e costruito una volta sola.

const ENV := "res://assets/models/env/"
const CELL := 40.0                     # lato dei blocchi delle MultiMesh (culling per blocco)

static var _meshes: Dictionary = {}
static var _grass_mat: ShaderMaterial
static var _bush_mat: ShaderMaterial


static func build(root: Node3D, quality: int) -> void:
	_quality = quality
	var folder := Node3D.new()
	folder.name = "Scenery"
	root.add_child(folder)
	if quality >= 1:
		_build_small_vegetation(folder, quality)
	_build_bases(folder, quality)
	_build_lane_props(folder, quality)


## Zona attorno alle basi riservata al villaggio (niente alberi).
static func in_village(p: Vector2) -> bool:
	for c in MapData.BASE_CENTER:
		if p.distance_to(c) < Game.BASE_RADIUS + 22.0:
			return true
	return false


# --- Mesh procedurali ------------------------------------------------------------

static func _tuft_mesh(blades: int, h_min: float, h_max: float, flowers: bool) -> ArrayMesh:
	var key := "tuft_%d_%s" % [blades, flowers]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + blades
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_c := Color(0.20, 0.33, 0.09, 1.0)
	var mid_c := Color(0.38, 0.55, 0.16, 1.0)
	var tip_c := Color(0.62, 0.78, 0.30, 1.0)
	for i in blades:
		var a := TAU * float(i) / blades + rng.randf_range(-0.4, 0.4)
		var u := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-u.z, 0, u.x)
		var b := u * rng.randf_range(0.0, 0.22)
		var h := rng.randf_range(h_min, h_max)
		var w := rng.randf_range(0.035, 0.06)
		var lean := rng.randf_range(0.15, 0.45)
		# un filo = 2 triangoli (base larga e punta piegata): pochi triangoli sottili, che sulla GPU costano
		var bl := b - side * w
		var br := b + side * w
		var mid := b + Vector3.UP * h * 0.55 + u * h * lean * 0.35
		var tip := b + Vector3.UP * h + u * h * lean
		for tri in [[bl, base_c, br, base_c, mid, mid_c], [mid - side * w * 0.7, mid_c, mid + side * w * 0.7, mid_c, tip, tip_c]]:
			for k in 3:
				st.set_color(tri[k * 2 + 1])
				st.set_normal(Vector3.UP)
				st.add_vertex(tri[k * 2])
	if flowers:
		# tre corolle a stella sopra gli steli più alti; alfa 0 = colore dei petali dall'istanza
		for f in 3:
			var a := TAU * f / 3.0 + 0.4
			var c := Vector3(cos(a) * 0.12, h_max * rng.randf_range(0.9, 1.15), sin(a) * 0.12)
			var petal := Color(1, 1, 1, 0.0)
			for k in 5:
				var a0 := TAU * k / 5.0
				var a1 := TAU * (k + 0.5) / 5.0
				for v in [c, c + Vector3(cos(a0), 0.02, sin(a0)) * 0.085, c + Vector3(cos(a1), 0.0, sin(a1)) * 0.04]:
					st.set_color(petal)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
	var m := st.commit()
	_meshes[key] = m
	return m


static func _bush_mesh(variant: int) -> ArrayMesh:
	var key := "bush_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 5
	var arr := sphere.get_mesh_arrays()
	var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var blobs := 4 + variant % 2
	for bi in blobs:
		var a := rng.randf() * TAU
		var off := Vector3(cos(a) * rng.randf_range(0.1, 0.38), rng.randf_range(0.25, 0.45), sin(a) * rng.randf_range(0.1, 0.38))
		var r := rng.randf_range(0.3, 0.46)
		var tone := rng.randf_range(0.85, 1.12)
		for idx in si:
			var v: Vector3 = sv[idx] * r
			v.y *= 0.85
			var p := v + off
			var n := (p - Vector3(0, 0.25, 0)).normalized().lerp(Vector3.UP, 0.35).normalized()
			var shade := clampf(0.55 + p.y * 0.7, 0.55, 1.15) * tone
			st.set_color(Color(0.24 * shade, 0.42 * shade, 0.13 * shade, 1.0))
			st.set_normal(n)
			st.add_vertex(p)
	var m := st.commit()
	_meshes[key] = m
	return m


static func _veg_material(sway: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/world/grass.gdshader")
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("noise_tex", MapBuilder.noise_texture())
	return m


## Distribuisce le istanze in blocchi CELL×CELL: ogni blocco è una MultiMesh con culling e distanza massima.
static func _scatter(folder: Node3D, mesh: Mesh, mat: Material, items: Array, vis_end: float, shadows: bool, custom: bool = false) -> void:
	var cells: Dictionary = {}
	for it in items:
		var t: Transform3D = it[0]
		var key := Vector2i(floori(t.origin.x / CELL), floori(t.origin.z / CELL))
		var list: Array = cells.get(key, [])
		list.append(it)
		cells[key] = list
	for key in cells:
		var list: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = custom
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
			if custom:
				mm.set_instance_custom_data(i, list[i][2])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vis_end
		folder.add_child(mmi)


# --- Vegetazione minuta -----------------------------------------------------------

static func _build_small_vegetation(folder: Node3D, quality: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var mult := 1.0 if quality >= 2 else 0.3
	var tufts: Array = []
	var flowers: Array = []
	var bushes: Array = [[], []]
	var pebbles: Array = []
	var reeds: Array = []
	var petal_cols := [Color(1.0, 0.95, 0.85), Color(1.0, 0.85, 0.25), Color(0.75, 0.55, 1.0), Color(1.0, 0.55, 0.6), Color(0.55, 0.75, 1.0)]
	var attempts := int(60000 * mult)
	for i in attempts:
		# più densità vicino alla corsia (dove guarda la telecamera)
		var t := rng.randf()
		var lp := Game.LANE_A.lerp(Game.LANE_B, t) + MapData.lane_dir() * rng.randf_range(-30.0, 30.0)
		var off := rng.randf_range(-1.0, 1.0)
		off = signf(off) * pow(absf(off), 1.6) * 60.0
		var p := lp + MapData.lane_normal() * off
		if rng.randf() < 0.25:
			p = Vector2(rng.randf_range(-130, 130), rng.randf_range(-130, 130))
		var out := Terrain.walk_out(p)
		var rd := Terrain.river_dist(p)
		var lane_d := p.distance_to(MapData.closest_on_lane(p))
		var base_d := minf(p.distance_to(MapData.BASE_CENTER[0]), p.distance_to(MapData.BASE_CENTER[1]))
		if base_d < Game.BASE_RADIUS - 3.0:
			continue
		var y := Terrain.height(p)
		var ash := smoothstep(10.0, 60.0, p.dot(MapData.lane_dir()))
		if rd < Terrain.RIVER_W + 0.3:
			continue
		if rd < Terrain.RIVER_W + 3.5:
			# canne lungo le rive (non nel guado)
			if lane_d > Game.LANE_HALF_WIDTH + 1.0 and rng.randf() < 0.5:
				var s := rng.randf_range(1.6, 2.6)
				reeds.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.4, s)), Vector3(p.x, y - 0.05, p.y)), Color(0.85, 0.95, 0.75)])
			continue
		# dentro la corsia solo ai bordi e radi
		if lane_d < Game.LANE_HALF_WIDTH - 1.0 and out < 0.0:
			if lane_d < Game.LANE_HALF_WIDTH - 5.0 or rng.randf() < 0.7:
				if rng.randf() < 0.03 and lane_d < Game.LANE_HALF_WIDTH - 3.0:
					var s := rng.randf_range(0.25, 0.6)
					pebbles.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), Vector3(p.x, y - 0.05, p.y)), Color(1, 1, 1)])
				continue
		var burnt := Color(1.0, 1.0, 1.0).lerp(Color(0.95, 0.62, 0.38), ash)
		var r := rng.randf()
		if r < 0.035 and out > 1.5:
			var s := rng.randf_range(1.3, 2.4)
			var bush_col := Color(1, 1, 1).lerp(Color(0.85, 0.6, 0.42), ash)
			bushes[rng.randi_range(0, 1)].append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s)), Vector3(p.x, y - 0.1, p.y)), bush_col])
		elif r < 0.06:
			var s := rng.randf_range(0.3, 0.9)
			pebbles.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), Vector3(p.x, y - 0.08, p.y)), Color(1, 1, 1)])
		elif r < 0.06 + 0.12 * (1.0 - ash):
			var s := rng.randf_range(0.9, 1.4)
			flowers.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, y, p.y)), burnt, petal_cols[rng.randi_range(0, petal_cols.size() - 1)]])
		else:
			var s := rng.randf_range(0.8, 1.6)
			var tone := rng.randf_range(0.85, 1.1)
			tufts.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(p.x, y, p.y)), Color(burnt.r * tone, burnt.g * tone, burnt.b * tone)])
	if _grass_mat == null:
		_grass_mat = _veg_material(0.12)
		_bush_mat = _veg_material(0.025)
	var near := 70.0 if quality >= 2 else 52.0
	_scatter(folder, _tuft_mesh(6, 0.35, 0.7, false), _grass_mat, tufts, near, false)
	_scatter(folder, _tuft_mesh(3, 0.3, 0.5, true), _grass_mat, flowers, near, false, true)
	_scatter(folder, _tuft_mesh(7, 0.5, 0.9, false), _grass_mat, reeds, near + 10.0, false)
	_scatter(folder, _bush_mesh(0), _bush_mat, bushes[0], 110.0, quality >= 2)
	_scatter(folder, _bush_mesh(1), _bush_mat, bushes[1], 110.0, quality >= 2)
	var rock := MapBuilder.model_mesh("rock_single_C.gltf")
	if rock:
		_scatter(folder, rock, MapBuilder.static_material(Color(0.95, 0.92, 0.88), 0.85), pebbles, 80.0, false)


# --- Basi fortificate e villaggi ---------------------------------------------------

static func _model_aabb(file: String) -> AABB:
	var mesh := MapBuilder.model_mesh(file)
	return mesh.get_aabb() if mesh else AABB(Vector3.ZERO, Vector3.ONE)


static var _quality := 1


static func _place(folder: Node3D, file: String, p: Vector2, s: float, rot: float, team: int = -1, y_off: float = 0.0) -> Node3D:
	var n := MapBuilder.place(folder, file, p, s, rot, Terrain.height(p) + y_off)
	if n == null:
		return null
	if team == 1:
		_darken(n)
	# ombre solo per edifici e mura; i piccoli oggetti di scena le proiettano solo in qualità alta
	if _quality < 2 and not file.begins_with("building") and not file.begins_with("wall"):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## La pietra del Culto è più scura (stesso atlante di colori KayKit, tinta diversa).
static func _darken(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = MapBuilder.static_material(Color(0.62, 0.52, 0.56))


static func _build_bases(folder: Node3D, quality: int) -> void:
	var colors := ["green", "red"]
	for t in [0, 1]:
		var c: Vector2 = MapData.BASE_CENTER[t]
		var dir := MapData.team_dir(t)
		var face := -dir.angle() + PI * 0.5
		# mura: anello attorno alla base con un varco verso la corsia
		var wr := Game.BASE_RADIUS + 2.5
		var wall_len := _model_aabb("wall_straight.gltf").size.x
		var ws := 4.0
		var seg := wall_len * ws
		var gate := asin((Game.LANE_HALF_WIDTH + 3.0) / wr)
		var arc := TAU - gate * 2.0
		var n := int(ceil(arc * wr / seg))
		var walls: Array = []
		for i in n:
			var a := dir.angle() + gate + arc * (i + 0.5) / n
			var p := c + Vector2(cos(a), sin(a)) * wr
			# il lato lungo del muro è tangente alla circonferenza; lunghezza adattata al passo dell'anello
			var basis := Basis(Vector3.UP, -a + PI * 0.5).scaled(Vector3((arc * wr / n) / wall_len, ws, ws))
			walls.append([Transform3D(basis, Vector3(p.x, Terrain.height(p), p.y)), Color(1, 1, 1)])
		var wmesh := MapBuilder.model_mesh("wall_straight.gltf")
		if wmesh:
			var mat: Material = MapBuilder.static_material(Color(1, 1, 1) if t == 0 else Color(0.62, 0.52, 0.56))
			_scatter(folder, wmesh, mat, walls, 0.0, true)
		# torri ai lati del varco
		for k in [-1, 1]:
			var a := dir.angle() + gate * float(k)
			var p := c + Vector2(cos(a), sin(a)) * (wr + 0.5)
			_place(folder, "building_tower_catapult_%s.gltf" % colors[t], p, 3.4, face, t)
		# villaggio dietro le mura (lontano dalla corsia)
		var village := [["building_windmill_%s", 150.0, 40.0, 3.6], ["building_church_%s", 115.0, 37.0, 3.6],
			["building_market_%s", 200.0, 36.0, 3.4], ["building_blacksmith_%s", 245.0, 36.0, 3.4],
			["building_tavern_%s", 175.0, 47.0, 3.4], ["building_home_A_%s", 95.0, 44.0, 3.4],
			["building_home_B_%s", 130.0, 50.0, 3.4], ["building_home_A_%s", 222.0, 48.0, 3.4],
			["building_lumbermill_%s", 265.0, 44.0, 3.4], ["building_home_B_%s", 75.0, 36.0, 3.4]]
		for v in village:
			var a: float = dir.angle() + deg_to_rad(v[1])
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * float(v[2])
			_place(folder, (v[0] as String) % colors[t] + ".gltf", p, v[3], -a + PI * 0.5 + PI, t)
		# stendardi lungo le mura
		for k in 8:
			var a := dir.angle() + gate + arc * (k + 0.5) / 8.0
			var p := c + Vector2(cos(a), sin(a)) * (wr - 1.2)
			_place(folder, "flag_%s.gltf" % colors[t], p, 4.0, -a + PI * 0.5)
		# oggetti di scena dentro la base
		var nrm := MapData.lane_normal()
		var props := [["crate_long_A.gltf", nrm * 19.0 - dir * 10.0], ["crate_open.gltf", nrm * 20.5 - dir * 8.0],
			["resource_lumber.gltf", -nrm * 19.0 - dir * 10.0], ["bucket_arrows.gltf", -nrm * 13.0 + dir * 4.0],
			["wheelbarrow.gltf", nrm * 9.0 - dir * 18.0], ["pallet.gltf", -nrm * 9.0 - dir * 19.0]]
		if t == 0:
			props.append(["target.gltf", -nrm * 21.0 - dir * 2.0])
		for pr in props:
			_place(folder, pr[0], c + pr[1], 4.0, face + 0.3 * (pr[1] as Vector2).x, t)
		if t == 1:
			_braziers(folder, c, dir, quality)


## Bracieri del Culto: fuoco viola-arancio con luce (solo da qualità media in su).
static func _braziers(folder: Node3D, c: Vector2, dir: Vector2, quality: int) -> void:
	var nrm := MapData.lane_normal()
	for k in [-1, 1]:
		for j in 2:
			var p := c + dir * (6.0 + j * 10.0) + nrm * float(k) * 9.5
			_campfire(folder, p, quality, Color(1.0, 0.45, 0.2), true)


# --- Corsia ------------------------------------------------------------------------

static func _build_lane_props(folder: Node3D, quality: int) -> void:
	var ld := MapData.lane_dir()
	var nrm := MapData.lane_normal()
	var hw := Game.LANE_HALF_WIDTH
	# [t lungo la corsia (-1..1 → da base a base), lato, distanza oltre il bordo, file, scala, rotazione]
	var items := [
		[-0.62, 1, 2.5, "building_scaffolding.gltf", 3.2, 0.3], [-0.55, -1, 3.0, "building_destroyed.gltf", 3.4, 1.1],
		[-0.42, 1, 1.5, "fence_wood_straight.gltf", 3.5, 0.0], [-0.38, 1, 1.8, "fence_wood_straight.gltf", 3.5, 0.15],
		[-0.30, -1, 2.0, "crate_B_big.gltf", 4.0, 0.4], [-0.28, -1, 3.2, "crate_A_small.gltf", 4.0, 1.0],
		[-0.18, 1, 4.0, "building_grain.gltf", 3.4, 0.6], [-0.12, -1, 2.0, "wheelbarrow.gltf", 4.0, 2.2],
		[0.12, 1, 2.5, "building_destroyed.gltf", 3.4, 2.4], [0.18, -1, 1.5, "fence_wood_straight.gltf", 3.5, 0.1],
		[0.22, -1, 1.8, "fence_wood_straight.gltf", 3.5, -0.2], [0.33, 1, 2.0, "resource_lumber.gltf", 4.0, 0.7],
		[0.45, -1, 3.0, "building_destroyed.gltf", 3.4, 0.2], [0.52, 1, 2.0, "crate_open.gltf", 4.0, 0.9],
		[0.60, -1, 2.5, "building_scaffolding.gltf", 3.2, 2.0]]
	for it in items:
		var t: float = it[0]
		var center := Game.LANE_A.lerp(Game.LANE_B, (t + 1.0) * 0.5)
		var p: Vector2 = center + nrm * float(it[1]) * (hw + float(it[2]))
		var team := 1 if t > 0.0 else 0
		_place(folder, it[3], p, it[4], -ld.angle() + float(it[5]), team, -0.05)
	# ponte in rovina sul fiume, fuori dalla corsia
	for side in [-1.0, 1.0]:
		var rpos: float = side * 38.0
		var along := -(sin(rpos * 0.045) * 6.0 + sin(rpos * 0.13) * 1.5)
		var p := nrm * rpos + ld * along
		_place(folder, "building_bridge_B.gltf", p, 4.2, -ld.angle() + PI * 0.5, -1, 0.15)
	# falò vicino alle torri esterne
	if quality >= 1:
		for t in [0, 1]:
			var tp: Vector2 = MapData.T1[t]
			_campfire(folder, tp + nrm * (hw + 3.0) * (1 if t == 0 else -1), quality, Color(1.0, 0.55, 0.2), false)
	# braci che salgono nella metà del Culto
	if quality >= 1:
		var em := _embers()
		em.position = Vector3(45, 1, -45)
		folder.add_child(em)


static func _campfire(folder: Node3D, p: Vector2, quality: int, col: Color, brazier: bool) -> void:
	var root := Node3D.new()
	root.position = Vector3(p.x, Terrain.height(p), p.y)
	folder.add_child(root)
	var stone := MapBuilder.model_mesh("rock_single_A.gltf")
	if brazier:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.35
		cyl.height = 1.2
		cyl.radial_segments = 8
		mi.mesh = cyl
		mi.position.y = 0.6
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.18, 0.15, 0.17)
		m.roughness = 0.7
		m.metallic = 0.5
		mi.material_override = m
		root.add_child(mi)
	elif stone:
		for k in 7:
			var a := TAU * k / 7.0
			var mi := MeshInstance3D.new()
			mi.mesh = stone
			mi.material_override = MapBuilder.static_material(Color(0.9, 0.88, 0.85), 0.85)
			mi.position = Vector3(cos(a) * 0.75, -0.05, sin(a) * 0.75)
			mi.scale = Vector3.ONE * 0.45
			mi.rotation.y = a * 2.3
			root.add_child(mi)
		for k in 2:
			var log_mi := MeshInstance3D.new()
			var lc := CylinderMesh.new()
			lc.top_radius = 0.09
			lc.bottom_radius = 0.09
			lc.height = 1.1
			lc.radial_segments = 6
			log_mi.mesh = lc
			log_mi.rotation = Vector3(PI * 0.5, k * 1.4, 0.25)
			log_mi.position.y = 0.12
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(0.32, 0.2, 0.12)
			log_mi.material_override = lm
			root.add_child(log_mi)
	var flame := VfxLib.make_flame(col)
	flame.amount = 40
	flame.lifetime = 0.9
	flame.draw_pass_1 = VfxLib.quad(0.7, col)
	flame.position.y = 1.25 if brazier else 0.25
	(flame.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.3
	root.add_child(flame)
	if quality >= 1:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position.y = 1.8 if brazier else 1.0
		l.shadow_enabled = false
		root.add_child(l)
		# tremolio della fiamma con un tween infinito (niente script per nodo)
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "light_energy", 2.1, 0.13)
		tw.tween_property(l, "light_energy", 1.3, 0.21)
		tw.tween_property(l, "light_energy", 1.8, 0.09)


static func _embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.visibility_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 20, 120))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(50, 0.5, 50)
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0.2, 0.15, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.8
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 0.5, 0.1, 0), Color(1, 0.55, 0.15, 1), Color(0.9, 0.25, 0.1, 0.8), Color(0.5, 0.1, 0.1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m
	p.draw_pass_1 = VfxLib.quad(0.16, Color(2.2, 1.2, 0.5))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
