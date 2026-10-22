class_name Cursors
extends RefCounted
## Cursori del mouse disegnati via codice con forme a distanza con segno (SDF), calcolati a 4× e ridotti
## con filtro Lanczos: bordi morbidi, sfumature e contorno, senza texture esterne.
##   sword(): spada d'acciaio con elsa dorata e alone rosso (attacco), punta in alto a sinistra;
##   aim(): mirino dorato per la mira delle abilità, centrato.

const SS := 4                     # sovracampionamento


static func _seg_t(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	return clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)


static func _box(p: Vector2, half: Vector2) -> float:
	var q := Vector2(absf(p.x), absf(p.y)) - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


static func _over(dst: Color, src: Color) -> Color:
	var a := src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(src.r, src.g, src.b, 0.0)
	var c := (Color(src.r, src.g, src.b) * src.a + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - src.a)) / a
	return Color(c.r, c.g, c.b, a)


static func _cov(d: float) -> float:
	# copertura antialias di un bordo (d in pixel finali)
	return clampf(0.5 - d * SS * 0.5, 0.0, 1.0)


## Spada: coordinate locali lungo l'asse (t dalla punta, s di traverso), in pixel della dimensione finale.
static func sword(size: int = 46) -> ImageTexture:
	var n := size * SS
	var img := Image.create(n, n, false, Image.FORMAT_RGBAF)
	var tip := Vector2(2.5, 2.5)
	var axis := Vector2(1, 1).normalized()
	var side := Vector2(-axis.y, axis.x)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / SS
			var col := Color(0, 0, 0, 0)
			# ombra portata (stessa forma, spostata e sfumata)
			var ds := _sword_sdf(p - Vector2(1.6, 2.2), tip, axis, side)
			col = _over(col, Color(0, 0, 0, 0.38 * clampf(1.0 - (ds[0] + 0.4) / 2.4, 0.0, 1.0)))
			var dd := _sword_sdf(p, tip, axis, side)
			var d: float = dd[0]
			# alone rosso (segnala l'attacco)
			col = _over(col, Color(1.0, 0.22, 0.15, 0.55 * clampf(1.0 - (d - 1.2) / 2.2, 0.0, 1.0) * float(d > 0.6)))
			# contorno scuro
			col = _over(col, Color(0.07, 0.04, 0.03, _cov(d - 1.2)))
			if d < 0.6:
				var c: Color = dd[1]
				col = _over(col, Color(c.r, c.g, c.b, _cov(d)))
			img.set_pixel(x, y, col)
	return _finish(img, size)


## Restituisce [distanza, colore della parte] per il punto p.
static func _sword_sdf(p: Vector2, tip: Vector2, axis: Vector2, side: Vector2) -> Array:
	var q := p - tip
	var t := q.dot(axis)
	var s := q.dot(side)
	const BLADE := 31.0
	var best := 1e9
	var col := Color()
	# lama: punta affilata, poi larghezza costante
	var hw := minf(3.0, maxf(0.0, t) * 0.55)
	var d_blade := maxf(absf(s) - hw, maxf(-t, t - BLADE))
	if d_blade < best:
		best = d_blade
		var k := clampf(0.5 - s / 7.0, 0.0, 1.0)
		col = Color(0.56, 0.6, 0.7).lerp(Color(0.97, 0.98, 1.0), k)
		# scanalatura centrale e filo luminoso
		if t > 5.0 and t < BLADE - 2.0 and absf(s + 0.3) < 0.55:
			col = col.darkened(0.3)
		if absf(absf(s) - hw) < 0.45 and s < 0.0:
			col = col.lightened(0.5)
	# elsa
	var d_guard := _box(Vector2(t - BLADE - 1.4, s), Vector2(1.4, 7.6)) - 0.6
	if d_guard < best:
		best = d_guard
		col = Color(0.62, 0.4, 0.12).lerp(Color(1.0, 0.86, 0.45), clampf(0.55 - s / 14.0 + (BLADE + 1.4 - t) * 0.12, 0.0, 1.0))
	# impugnatura in cuoio con fasciature
	var d_grip := _box(Vector2(t - BLADE - 7.6, s), Vector2(4.4, 1.9)) - 0.3
	if d_grip < best:
		best = d_grip
		col = Color(0.36, 0.2, 0.1).lerp(Color(0.55, 0.33, 0.17), clampf(0.5 - s / 4.0, 0.0, 1.0))
		if fmod(t - BLADE, 2.2) < 0.7:
			col = col.darkened(0.35)
	# pomo con gemma
	var pc := Vector2(t - BLADE - 14.2, s)
	var d_pommel := pc.length() - 2.9
	if d_pommel < best:
		best = d_pommel
		col = Color(0.7, 0.48, 0.15).lerp(Color(1.0, 0.88, 0.5), clampf(0.5 - (pc.x + pc.y) / 6.0, 0.0, 1.0))
		if pc.length() < 1.4:
			col = Color(0.85, 0.12, 0.1).lerp(Color(1.0, 0.6, 0.5), clampf(-(pc.x + pc.y) / 2.0, 0.0, 1.0))
	return [best, col]


## Mirino: anello spezzato con tacche e punto centrale.
static func aim(size: int = 40) -> ImageTexture:
	var n := size * SS
	var img := Image.create(n, n, false, Image.FORMAT_RGBAF)
	var c := Vector2(size, size) * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / SS - c
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var gap := absf(fmod(ang + TAU + PI * 0.25, PI * 0.5) - PI * 0.25)   # 0 sulle diagonali
			var d_ring := absf(r - 12.5) - 1.3
			d_ring = maxf(d_ring, 0.32 - gap)          # aperture sulle diagonali
			var d_ticks := 1e9
			for k in 4:
				var dir := Vector2.from_angle(k * PI * 0.5)
				var tp := p - dir * 16.5
				d_ticks = minf(d_ticks, _box(Vector2(tp.dot(dir), tp.dot(Vector2(-dir.y, dir.x))), Vector2(2.6, 0.75)))
			var d_dot := r - 1.7
			var d := minf(d_ring, minf(d_ticks, d_dot))
			var col := Color(0, 0, 0, 0)
			col = _over(col, Color(0.06, 0.03, 0.02, _cov(d - 1.1) * 0.9))
			var g := Color(1.0, 0.62, 0.22).lerp(Color(1.0, 0.92, 0.6), clampf(0.5 - p.y / 30.0, 0.0, 1.0))
			col = _over(col, Color(g.r, g.g, g.b, _cov(d)))
			img.set_pixel(x, y, col)
	return _finish(img, size)


static func _finish(img: Image, size: int) -> ImageTexture:
	# i pixel trasparenti prendono il colore del contorno: niente aloni chiari dopo il ridimensionamento
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.004:
				img.set_pixel(x, y, Color(0.07, 0.04, 0.03, 0.0))
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)
