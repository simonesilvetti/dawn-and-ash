class_name MapData
extends RefCounted
## Geometria logica della mappa (piano x,z come Vector2).
## Area percorribile = capsula della corsia ∪ cerchi delle due basi: forme convesse,
## quindi il movimento diretto + proiezione sul bordo non incastra mai le unità.

const BASE_CENTER := [Vector2(-77, 77), Vector2(77, -77)]
const FOUNTAIN := [Vector2(-88, 88), Vector2(88, -88)]
const ANCIENT := [Vector2(-70, 70), Vector2(70, -70)]
const T2 := [Vector2(-52, 52), Vector2(52, -52)]
const T1 := [Vector2(-27, 27), Vector2(27, -27)]
const CREEP_SPAWN := [Vector2(-63, 63), Vector2(63, -63)]


static func lane_dir() -> Vector2:
	return (Game.LANE_B - Game.LANE_A).normalized()


## Direzione di marcia dei creep di una squadra.
static func team_dir(team: int) -> Vector2:
	return lane_dir() if team == Game.Team.RADIANT else -lane_dir()


static func lane_normal() -> Vector2:
	var d := lane_dir()
	return Vector2(-d.y, d.x)


static func closest_on_lane(p: Vector2) -> Vector2:
	return Geometry2D.get_closest_point_to_segment(p, Game.LANE_A, Game.LANE_B)


static func lane_t(p: Vector2) -> float:
	var ab := Game.LANE_B - Game.LANE_A
	return clampf((p - Game.LANE_A).dot(ab) / ab.length_squared(), 0.0, 1.0)


static func is_walkable(p: Vector2, r: float = 0.0) -> bool:
	if p.distance_to(closest_on_lane(p)) <= Game.LANE_HALF_WIDTH - r:
		return true
	for c in BASE_CENTER:
		if p.distance_to(c) <= Game.BASE_RADIUS - r:
			return true
	return false


## Riporta un punto dentro l'area percorribile (proiezione sulla forma più vicina).
static func clamp_walkable(p: Vector2, r: float = 0.0) -> Vector2:
	if is_walkable(p, r):
		return p
	var best := p
	var best_d := INF
	var lp := closest_on_lane(p)
	var lw := Game.LANE_HALF_WIDTH - r
	var cand := lp + (p - lp).limit_length(lw)
	var d := cand.distance_squared_to(p)
	if d < best_d:
		best_d = d
		best = cand
	for c in BASE_CENTER:
		var br: float = Game.BASE_RADIUS - r
		cand = c + (p - c).limit_length(br)
		d = cand.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = cand
	return best


## Muro a segmento (Fenditura di Gorm): spinge fuori dal muro un cerchio di raggio r che lo attraversa.
## dir = direzione di marcia (serve solo se il centro è esattamente sulla linea: torna dal lato da cui arriva).
## Usata dalla simulazione e dalla predizione del client (stesse regole).
static func push_from_wall(p: Vector2, r: float, dir: Vector2, a: Vector2, b: Vector2, half_w: float) -> Vector2:
	var c := Geometry2D.get_closest_point_to_segment(p, a, b)
	var d := p - c
	var min_d := half_w + r
	var l2 := d.length_squared()
	if l2 >= min_d * min_d:
		return p
	var n: Vector2
	var l := sqrt(l2)
	if l > 0.001:
		n = d / l
	else:
		n = (b - a).normalized().orthogonal()
		if n.dot(dir) > 0.0:
			n = -n
	return c + n * min_d


## Aggiramento dei muri: se il tragitto diretto da p a goal attraversa un muro, restituisce una tappa
## all'angolo oltre l'estremità più conveniente, dal lato della meta (percorso p -> angolo -> meta più corto);
## altrimenti goal. Dall'angolo la linea verso la meta è libera; per arrivarci la spinta del muro fa
## scivolare l'unità lungo il fianco e attorno alla punta. walls: Array di {a, b, w}; nessuna memoria.
static func wall_detour(p: Vector2, goal: Vector2, r: float, walls: Array) -> Vector2:
	for w in walls:
		var a: Vector2 = w.a
		var b: Vector2 = w.b
		var clear: float = w.w + r
		var cp := Geometry2D.get_closest_points_between_segments(p, goal, a, b)
		if cp[0].distance_to(cp[1]) >= clear - 0.02:
			continue
		# meta dentro il muro: ci si ferma contro il muro (lo gestisce chi muove l'unità)
		if Geometry2D.get_closest_point_to_segment(goal, a, b).distance_to(goal) < clear:
			continue
		var t := (b - a).normalized()
		var n := t.orthogonal()
		var side := signf((goal - a).dot(n))
		if side == 0.0:
			side = signf((p - a).dot(n)) if (p - a).dot(n) != 0.0 else 1.0
		var off := n * side * (clear + 0.35)
		var ea := a - t * (clear + 0.35) + off
		var eb := b + t * (clear + 0.35) + off
		var da := p.distance_to(ea) + ea.distance_to(goal)
		var db := p.distance_to(eb) + eb.distance_to(goal)
		return ea if da < db else eb
	return goal


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func to2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
