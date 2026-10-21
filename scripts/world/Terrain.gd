class_name Terrain
extends RefCounted
## Rilievo puramente visivo della mappa: colline fuori dall'area percorribile, alveo del fiume con un guado basso
## dentro la corsia. La simulazione resta sul piano (MapData): qui si calcola solo l'altezza da mostrare.

const RIVER_W := 5.0          # semilarghezza dell'acqua (uguale a ground.gdshader)
const WATER_Y := -0.16        # quota della superficie dell'acqua
const FORD_DEPTH := 0.42      # profondità del guado nella corsia (le unità ci camminano dentro)
const BED_DEPTH := 1.8        # profondità dell'alveo fuori dalla corsia
const SIZE := 360.0           # lato della mesh del terreno
const STEP := 1.5             # passo della griglia

static var _noise: FastNoiseLite
static var _mesh: ArrayMesh


static func _hill_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1717
		_noise.frequency = 0.018
		_noise.fractal_octaves = 3
	return _noise


static func river_dist(p: Vector2) -> float:
	var ld := MapData.lane_dir()
	var along := p.dot(ld)
	var rpos := p.dot(Vector2(-ld.y, ld.x))
	return absf(along + sin(rpos * 0.045) * 6.0 + sin(rpos * 0.13) * 1.5)


## Distanza dal bordo dell'area percorribile (≤ 0 dentro).
static func walk_out(p: Vector2) -> float:
	var d := p.distance_to(MapData.closest_on_lane(p)) - Game.LANE_HALF_WIDTH
	for c in MapData.BASE_CENTER:
		d = minf(d, p.distance_to(c) - Game.BASE_RADIUS)
	return d


## Altezza visiva del terreno nel punto p (piano x,z).
static func height(p: Vector2) -> float:
	var h := 0.0
	var out := walk_out(p)
	var rd := river_dist(p)
	if out > 1.0:
		var n := _hill_noise().get_noise_2d(p.x, p.y) * 0.5 + 0.5
		# argine ripido vicino alla corsia (come le scogliere di Dota), poi colline morbide
		var ridge := smoothstep(1.0, 7.0, out) * (2.0 + n * 2.0)
		var hills := smoothstep(6.0, 40.0, out) * n * 8.0
		var edge := smoothstep(118.0, 150.0, maxf(absf(p.x), absf(p.y))) * 7.0
		# attorno alle basi il terreno resta piano per il villaggio
		var bd := minf(p.distance_to(MapData.BASE_CENTER[0]), p.distance_to(MapData.BASE_CENTER[1]))
		var flat := smoothstep(Game.BASE_RADIUS + 20.0, Game.BASE_RADIUS + 32.0, bd)
		h = (ridge + hills * flat + edge) * smoothstep(RIVER_W + 1.0, RIVER_W + 16.0, rd)
		h *= lerpf(0.25, 1.0, flat)
	if rd < RIVER_W + 4.0:
		var in_lane := 1.0 - smoothstep(Game.LANE_HALF_WIDTH - 4.0, Game.LANE_HALF_WIDTH + 6.0, p.distance_to(MapData.closest_on_lane(p)))
		var depth := lerpf(BED_DEPTH, FORD_DEPTH, in_lane)
		var c := 1.0 - smoothstep(RIVER_W - 2.0, RIVER_W + 4.0, rd)
		h = lerpf(h, -depth, c)
	return h


## Mesh a griglia del terreno (calcolata una volta e riutilizzata tra menu e partite).
static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var n := int(SIZE / STEP) + 1
	var half := SIZE * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(Vector2(-half + i * STEP, -half + j * STEP))
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	verts.resize(n * n)
	nrms.resize(n * n)
	for j in n:
		for i in n:
			var h: float = hs[j * n + i]
			verts[j * n + i] = Vector3(-half + i * STEP, h, -half + j * STEP)
			var hl: float = hs[j * n + maxi(i - 1, 0)]
			var hr: float = hs[j * n + mini(i + 1, n - 1)]
			var hd: float = hs[maxi(j - 1, 0) * n + i]
			var hu: float = hs[mini(j + 1, n - 1) * n + i]
			nrms[j * n + i] = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + n
			idx[k + 3] = a + 1; idx[k + 4] = a + n + 1; idx[k + 5] = a + n
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_INDEX] = idx
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _mesh


## Superficie dell'acqua: un rettangolo piatto lungo il fiume; il terreno più alto la nasconde,
## quindi la riva nasce dal test di profondità.
static func build_water(root: Node3D, quality: int, noise: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(340.0, 2.0 * (RIVER_W + 10.0))
	mi.mesh = pm
	var ld := MapData.lane_dir()
	mi.rotation.y = -ld.angle() - PI * 0.5      # asse X del piano lungo il fiume
	mi.position = Vector3(0.0, WATER_Y, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = MapBuilder.shader_variant("res://scripts/world/water.gdshader", quality)
	var nm := NoiseTexture2D.new()
	nm.width = 256
	nm.height = 256
	nm.seamless = true
	nm.as_normal_map = true
	nm.bump_strength = 6.0
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	fn.fractal_octaves = 3
	nm.noise = fn
	mat.set_shader_parameter("normal_tex", nm)
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("use_depth", quality >= 1)
	mat.set_shader_parameter("lane_dir", ld)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
