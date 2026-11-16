shader_type canvas_item;
// Icone procedurali di abilità e oggetti (niente texture esterne): forme SDF con sfumature, bagliori e rumore.
// icon: 0 Palla di fuoco, 1 Scatto, 2 Onda d'urto, 3 Meteora; 4-7 Peppino (Fendente, Carica, Scudo di ferro, Spaccaterra);
// Gorm: 8 Fenditura, 9 Totem del sisma, 19 Scossa di ritorno, 20 Eco del sisma; 10-18 oggetti (vedi IconRect.IDS).
// dim > 0 = icona spenta (abilità non imparata o oggetto non acquistabile).

uniform int icon = 0;
uniform float dim = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float fill(float d) {
	float aa = fwidth(d) * 0.8 + 0.002;
	return 1.0 - smoothstep(-aa, aa, d);
}
float glow(float d, float k) { return exp(-max(d, 0.0) * k); }
float sd_circle(vec2 p, float r) { return length(p) - r; }
float sd_box(vec2 p, vec2 b) { vec2 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); }
float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
// punta di roccia: triangolo con la base centrata in b, larga 2w e alta h
float sd_spike(vec2 p, vec2 b, float w, float h) {
	vec2 q = p - b;
	return max(-q.y, (abs(q.x) * h + w * q.y - w * h) / sqrt(h * h + w * w));
}
float seg_t(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a, ba = b - a; return clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); }
mat2 rot(float a) { return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))); }
vec3 over(vec3 base, vec3 c, float a) { return mix(base, c, clamp(a, 0.0, 1.0)); }

vec3 bg_radial(vec2 p, vec3 inner, vec3 outer) {
	return mix(inner, outer, smoothstep(0.0, 1.4, length(p)));
}

vec3 potion(vec2 p, vec3 liquid) {
	vec3 col = bg_radial(p, liquid * 0.35, vec3(0.03));
	float body = sd_circle(p - vec2(0.0, -0.22), 0.5);
	float neck = sd_box(p - vec2(0.0, 0.38), vec2(0.13, 0.2));
	float flask = min(body, neck);
	col = over(col, vec3(0.75, 0.85, 0.9) * 0.35, fill(flask));
	float level = -0.12 + sin(p.x * 9.0 + TIME * 3.0) * 0.025;
	float liq = max(body + 0.05, p.y - level);
	col = over(col, mix(liquid * 0.6, liquid * 1.3, 0.5 - p.y), fill(liq));
	col += liquid * 0.5 * glow(liq, 9.0) * 0.4;
	col = over(col, vec3(0.55, 0.36, 0.2), fill(sd_box(p - vec2(0.0, 0.6), vec2(0.15, 0.08))));
	col = over(col, vec3(1.0), fill(sd_circle(p - vec2(-0.2, -0.05), 0.08)) * 0.7);
	// contorno del vetro
	col = over(col, vec3(0.9, 0.95, 1.0), (1.0 - smoothstep(0.0, 0.03, abs(flask))) * 0.6);
	return col;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float n = texture(noise_tex, UV * 0.6 + vec2(0.0, -TIME * 0.15)).r;
	float n2 = texture(noise_tex, UV * 1.7 + vec2(TIME * 0.05, -TIME * 0.4)).r;
	vec3 col = vec3(0.05);

	if (icon == 0) {
		// Palla di fuoco: cometa con nucleo incandescente
		col = bg_radial(p - vec2(0.2), vec3(0.35, 0.08, 0.03), vec3(0.04, 0.01, 0.01));
		vec2 a = vec2(0.2, 0.2), b = vec2(-0.85, -0.85);
		float t = seg_t(p, a, b);
		float tail = sd_seg(p, a, b) - mix(0.36, 0.04, t) - (n2 - 0.5) * 0.18;
		vec3 tc = mix(vec3(1.0, 0.8, 0.3), vec3(0.8, 0.15, 0.03), t);
		col += tc * glow(tail, 6.0) * 0.6;
		col = over(col, tc, fill(tail) * (1.0 - t * 0.6));
		float core = sd_circle(p - a, 0.38) - (n - 0.5) * 0.12;
		col += vec3(1.0, 0.5, 0.1) * glow(core, 5.0) * 0.7;
		col = over(col, mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.97, 0.75), smoothstep(0.0, -0.3, core)), fill(core));
	} else if (icon == 1) {
		// Scatto: spirale arcana con scintille
		col = bg_radial(p, vec3(0.3, 0.1, 0.4), vec3(0.03, 0.01, 0.05));
		float r = length(p);
		float ang = atan(p.y, p.x) / 6.2831853;
		float arms = abs(fract(ang * 2.0 + r * 1.4 - TIME * 0.25) - 0.5);
		float band = (1.0 - smoothstep(0.08, 0.2, arms)) * smoothstep(0.12, 0.25, r) * (1.0 - smoothstep(0.7, 0.92, r));
		col = over(col, mix(vec3(1.0, 0.55, 0.25), vec3(0.75, 0.35, 1.0), r), band);
		col += vec3(1.0, 0.85, 1.0) * glow(sd_circle(p, 0.12), 8.0) * 0.9;
		for (int i = 0; i < 3; i++) {
			vec2 c = vec2(cos(float(i) * 2.1 + 0.6), sin(float(i) * 2.1 + 0.6)) * 0.62;
			vec2 q = abs(p - c);
			float star = q.x * q.y * 60.0 + max(q.x, q.y) * 3.0;
			col += vec3(1.0, 0.9, 1.0) * (1.0 - smoothstep(0.1, 0.45, star));
		}
	} else if (icon == 2) {
		// Onda d'urto: bastone piantato a terra e anelli di energia
		col = bg_radial(p - vec2(0.0, -0.4), vec3(0.08, 0.2, 0.35), vec3(0.01, 0.02, 0.05));
		vec2 q = (p - vec2(0.0, -0.5)) * vec2(1.0, 2.6);
		float r = length(q);
		col += vec3(0.4, 0.75, 1.0) * (1.0 - smoothstep(0.0, 0.07, abs(r - 0.55 - fract(TIME * 0.6) * 0.1))) * 0.9;
		col += vec3(1.0, 0.55, 0.15) * (1.0 - smoothstep(0.0, 0.05, abs(r - 0.85))) * 0.8;
		col += vec3(0.4, 0.75, 1.0) * (1.0 - smoothstep(0.0, 0.04, abs(r - 1.1))) * 0.4;
		float staff = sd_seg(p, vec2(0.0, -0.55), vec2(0.0, 0.45)) - 0.06;
		col = over(col, vec3(0.5, 0.32, 0.18), fill(staff));
		float orb = sd_circle(p - vec2(0.0, 0.55), 0.17);
		col += vec3(0.5, 0.8, 1.0) * glow(orb, 6.0) * 0.8;
		col = over(col, vec3(0.85, 0.95, 1.0), fill(orb));
	} else if (icon == 3) {
		// Meteora: masso infuocato che precipita
		col = mix(vec3(0.3, 0.06, 0.04), vec3(0.04, 0.02, 0.05), UV.y * 0.3 + (1.0 - UV.y) * 0.9);
		vec2 c = vec2(-0.15, -0.2);
		vec2 a = c, b = vec2(0.95, 0.95);
		float t = seg_t(p, a, b);
		float tail = sd_seg(p, a, b) - mix(0.5, 0.05, t) - (n2 - 0.5) * 0.2;
		vec3 tc = mix(vec3(1.0, 0.75, 0.25), vec3(0.7, 0.1, 0.03), t);
		col += tc * glow(tail, 5.0) * 0.5;
		col = over(col, tc, fill(tail) * (1.0 - t * 0.5));
		float rock = sd_circle(p - c, 0.42) + (texture(noise_tex, UV * 2.5).r - 0.5) * 0.12;
		col += vec3(1.0, 0.45, 0.1) * glow(rock, 7.0) * 0.8;
		float crater = texture(noise_tex, (p - c) * 0.9 + vec2(0.3)).r;
		vec3 rc = mix(vec3(0.22, 0.14, 0.12), vec3(0.45, 0.3, 0.24), smoothstep(0.3, 0.7, crater));
		rc += vec3(1.0, 0.4, 0.05) * smoothstep(0.62, 0.72, crater) * 0.8;
		col = over(col, rc, fill(rock));
	} else if (icon == 4) {
		// Fendente rotante: lama al centro e scia circolare d'acciaio
		col = bg_radial(p, vec3(0.28, 0.12, 0.06), vec3(0.03, 0.02, 0.02));
		float r = length(p);
		float ang = fract(atan(p.y, p.x) / 6.2831853 + TIME * 0.35);
		float arc = abs(r - 0.62) - mix(0.02, 0.16, ang);
		vec3 sc = mix(vec3(0.5, 0.3, 0.15), vec3(1.0, 0.95, 0.85), ang);
		col += sc * glow(arc, 10.0) * 0.5 * ang;
		col = over(col, sc, fill(arc) * smoothstep(0.05, 0.6, ang));
		vec2 q = rot(-0.785398) * p;
		float blade = max(sd_box(q - vec2(0.0, 0.12), vec2(0.075, 0.48)), q.y - 0.62 + abs(q.x) * 2.0);
		col = over(col, mix(vec3(0.6, 0.64, 0.72), vec3(0.98, 0.98, 1.0), step(0.0, q.x)), fill(blade));
		col = over(col, vec3(0.92, 0.72, 0.3), fill(sd_box(q - vec2(0.0, -0.38), vec2(0.24, 0.05))));
		col = over(col, vec3(0.4, 0.22, 0.12), fill(sd_box(q - vec2(0.0, -0.53), vec2(0.05, 0.12))));
	} else if (icon == 5) {
		// Carica: scudo lanciato in avanti con linee di velocità e polvere
		col = bg_radial(p - vec2(0.3, 0.0), vec3(0.3, 0.22, 0.12), vec3(0.03, 0.02, 0.02));
		for (int i = 0; i < 4; i++) {
			float y = 0.45 - float(i) * 0.3;
			float l = sd_seg(p, vec2(-0.95, y), vec2(-0.25 - float(i % 2) * 0.15, y)) - 0.035;
			col = over(col, vec3(1.0, 0.9, 0.7), fill(l) * (0.5 + 0.5 * fract(p.x * 0.7 + TIME * 1.5)));
		}
		vec2 q = p - vec2(0.25, 0.05);
		float top = max(abs(q.x) - 0.42, q.y - 0.5);
		float wedge = (abs(q.x) * 0.75 - 0.42 * (q.y + 0.7)) / 0.93;
		float sh = max(top, wedge);
		col += vec3(1.0, 0.8, 0.4) * glow(sh, 7.0) * 0.35;
		col = over(col, mix(vec3(0.55, 0.58, 0.66), vec3(0.85, 0.88, 0.95), 0.5 + q.y * 0.5 - q.x * 0.4), fill(sh));
		col = over(col, vec3(0.95, 0.75, 0.3), 1.0 - smoothstep(0.0, 0.06, abs(sh + 0.04)));
		col = over(col, vec3(0.75, 0.15, 0.1), fill(sd_circle(q - vec2(0.0, 0.08), 0.13)));
		float dust = texture(noise_tex, UV * 1.3 + vec2(TIME * 0.3, 0.0)).r;
		col = over(col, vec3(0.6, 0.5, 0.38), smoothstep(0.55, 0.8, dust) * (1.0 - smoothstep(-0.9, -0.5, p.y)) * 0.8);
	} else if (icon == 6) {
		// Scudo di ferro: scudo dorato con aura
		col = bg_radial(p, vec3(0.32, 0.24, 0.08), vec3(0.03, 0.02, 0.01));
		vec2 q = p - vec2(0.0, 0.05);
		float top = max(abs(q.x) - 0.55, q.y - 0.62);
		float wedge = (abs(q.x) * 0.75 - 0.55 * (q.y + 0.8)) / 0.93;
		float sh = max(top, wedge);
		float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
		col += vec3(1.0, 0.8, 0.35) * glow(sh, 5.0) * 0.6 * pulse;
		col = over(col, mix(vec3(0.45, 0.47, 0.55), vec3(0.88, 0.9, 0.96), 0.5 + q.y * 0.45 - q.x * 0.35), fill(sh));
		col = over(col, mix(vec3(0.6, 0.42, 0.15), vec3(1.0, 0.88, 0.5), 0.5 + q.y * 0.5), 1.0 - smoothstep(0.0, 0.08, abs(sh + 0.05)));
		float cross_d = min(sd_box(q - vec2(0.0, 0.05), vec2(0.07, 0.38)), sd_box(q - vec2(0.0, 0.18), vec2(0.28, 0.07)));
		col = over(col, mix(vec3(0.85, 0.6, 0.2), vec3(1.0, 0.92, 0.6), 0.5 + q.y), fill(cross_d));
		col = over(col, vec3(1.0), fill(sd_circle(p - vec2(-0.28, 0.45), 0.05)) * 0.7);
	} else if (icon == 7) {
		// Spaccaterra: spada piantata e crepa incandescente nel terreno
		col = mix(vec3(0.12, 0.06, 0.04), vec3(0.03, 0.02, 0.03), UV.y);
		float ground = p.y + 0.15;
		col = over(col, mix(vec3(0.32, 0.22, 0.15), vec3(0.18, 0.12, 0.08), -p.y), 1.0 - smoothstep(-0.01, 0.01, ground));
		float zig = abs(p.x - sin(p.y * 9.0) * 0.08 - (p.y + 0.15) * 0.25);
		float crack = max(zig - mix(0.015, 0.09, clamp(-(p.y + 0.15), 0.0, 1.0)), ground);
		col += vec3(1.0, 0.45, 0.08) * glow(crack, 9.0) * 0.9 * (1.0 - smoothstep(-0.02, 0.05, ground));
		col = over(col, vec3(1.0, 0.85, 0.4), fill(crack));
		for (int i = 0; i < 3; i++) {
			vec2 c = vec2(-0.45 + float(i) * 0.42, -0.02 + fract(TIME * 0.5 + float(i) * 0.33) * 0.35);
			col = over(col, vec3(0.45, 0.33, 0.25), fill(sd_box(rot(float(i)) * (p - c), vec2(0.06, 0.05))));
		}
		col = over(col, mix(vec3(0.6, 0.64, 0.72), vec3(0.98, 0.98, 1.0), step(0.0, p.x)), fill(sd_box(p - vec2(0.0, 0.42), vec2(0.07, 0.42))));
		col = over(col, vec3(0.92, 0.72, 0.3), fill(sd_box(p - vec2(0.0, 0.82), vec2(0.24, 0.05))));
	} else if (icon == 8) {
		// Fenditura: crepa incandescente che corre verso l'orizzonte tra due file di punte di roccia
		col = mix(vec3(0.16, 0.08, 0.05), vec3(0.04, 0.03, 0.05), UV.y * 0.2 + (1.0 - UV.y) * 0.8);
		float horizon = p.y - 0.25;
		col = over(col, mix(vec3(0.36, 0.25, 0.16), vec3(0.2, 0.13, 0.08), clamp(-p.y, 0.0, 1.0)), 1.0 - smoothstep(-0.01, 0.01, horizon));
		float depth = clamp((0.25 - p.y) / 1.25, 0.0, 1.0);          // 0 all'orizzonte, 1 in primo piano
		float cx = sin(p.y * 14.0) * 0.04 * depth;
		float crack = max(abs(p.x - cx) - mix(0.01, 0.1, depth), horizon);
		col += vec3(1.0, 0.5, 0.12) * glow(crack, 10.0) * 0.9 * (1.0 - smoothstep(-0.02, 0.04, horizon));
		col = over(col, vec3(1.0, 0.86, 0.45), fill(crack));
		for (int i = 0; i < 4; i++) {
			float k = float(i) / 3.0;                                   // 0 lontano, 1 vicino
			float y = mix(0.2, -0.75, k);
			float sz = mix(0.12, 0.42, k);
			float xo = mix(0.1, 0.36, k);
			for (int side = -1; side <= 1; side += 2) {
				vec2 bp = vec2(float(side) * (xo + sz * 0.5), y);
				float sp = sd_spike(p, bp, sz * 0.55, sz * 1.5);
				vec3 rc = mix(vec3(0.42, 0.37, 0.33), vec3(0.72, 0.66, 0.6), step(0.0, (p.x - bp.x) * float(-side)));
				col = over(col, rc * (0.75 + 0.25 * k), fill(sp));
				col += vec3(1.0, 0.45, 0.1) * glow(sp, 16.0) * 0.25 * (1.0 - step(0.0, -sp));
			}
		}
	} else if (icon == 9) {
		// Totem del sisma: totem di pietra in diagonale con la fascia di rune accesa e le braci
		col = bg_radial(p - vec2(0.3, 0.3), vec3(0.35, 0.16, 0.05), vec3(0.03, 0.02, 0.02));
		vec2 q = rot(0.62) * (p - vec2(0.05, 0.0));
		float shaft = sd_box(q - vec2(0.0, -0.3), vec2(0.055, 0.62));
		col = over(col, mix(vec3(0.35, 0.2, 0.1), vec3(0.55, 0.36, 0.2), step(0.0, q.x)), fill(shaft));
		col = over(col, vec3(0.2, 0.1, 0.05), fill(sd_box(q - vec2(0.0, -0.55), vec2(0.075, 0.035))));
		float head = sd_box(q - vec2(0.0, 0.48), vec2(0.27 - (q.y - 0.48) * 0.12, 0.3)) - 0.03;
		float pulse = 0.8 + 0.2 * sin(TIME * 4.0);
		col += vec3(1.0, 0.5, 0.12) * glow(head, 6.0) * 0.55 * pulse;
		vec3 stone = mix(vec3(0.45, 0.41, 0.37), vec3(0.72, 0.67, 0.6), step(0.0, q.x) * 0.6 + (q.y - 0.2) * 0.4);
		col = over(col, stone, fill(head));
		float band = max(head, abs(q.y - 0.42) - 0.05);
		col = over(col, mix(vec3(1.0, 0.55, 0.12), vec3(1.0, 0.95, 0.7), 0.5 + 0.5 * sin(q.x * 30.0)) * pulse, fill(band));
		col = over(col, vec3(1.0, 0.85, 0.5), fill(sd_box(q - vec2(-0.1, 0.62), vec2(0.035, 0.035))) * pulse);
		col = over(col, vec3(1.0, 0.85, 0.5), fill(sd_box(q - vec2(0.1, 0.62), vec2(0.035, 0.035))) * pulse);
		for (int i = 0; i < 4; i++) {
			vec2 c = vec2(0.25 + float(i) * 0.12 - 0.2, 0.35 + fract(TIME * 0.6 + float(i) * 0.27) * 0.6);
			col += vec3(1.0, 0.6, 0.2) * glow(sd_circle(p - c, 0.02), 30.0) * 0.8;
		}
	} else if (icon == 19) {
		// Scossa di ritorno: anelli di terra schiacciati attorno al punto d'impatto, sassi e stelline
		col = bg_radial(p - vec2(0.0, -0.3), vec3(0.28, 0.18, 0.08), vec3(0.03, 0.02, 0.02));
		vec2 q = (p - vec2(0.0, -0.3)) * vec2(1.0, 2.4);
		float r = length(q);
		float wave = fract(TIME * 0.7);
		for (int i = 0; i < 3; i++) {
			float rr = 0.3 + float(i) * 0.3 + wave * 0.3;
			float a = (1.0 - smoothstep(0.0, 0.06, abs(r - rr))) * (1.0 - float(i) * 0.25) * (1.0 - wave * 0.5);
			col = over(col, vec3(0.95, 0.72, 0.42), a);
		}
		col += vec3(1.0, 0.6, 0.25) * glow(sd_circle(q, 0.12), 6.0) * 0.7;
		for (int i = 0; i < 3; i++) {
			float ang = float(i) * 2.1 + 0.5;
			vec2 c = vec2(cos(ang) * 0.6, -0.25 + abs(sin(ang)) * 0.25 + 0.15);
			col = over(col, vec3(0.5, 0.42, 0.36), fill(sd_box(rot(ang) * (p - c), vec2(0.07, 0.055))));
		}
		for (int i = 0; i < 3; i++) {
			float ang = TIME * 2.5 + float(i) * 2.094;
			vec2 c = vec2(cos(ang) * 0.38, 0.5 + sin(ang) * 0.1);
			vec2 sq = abs(p - c);
			float star = sq.x * sq.y * 70.0 + max(sq.x, sq.y) * 4.0;
			col += vec3(1.0, 0.92, 0.5) * (1.0 - smoothstep(0.15, 0.45, star));
		}
	} else if (icon == 20) {
		// Eco del sisma: impatto centrale e onde che rimbalzano da più punti
		col = bg_radial(p, vec3(0.3, 0.12, 0.3), vec3(0.03, 0.01, 0.04));
		float t = fract(TIME * 0.5);
		vec2 srcs[4] = vec2[](vec2(0.0, 0.0), vec2(-0.55, 0.4), vec2(0.6, 0.35), vec2(0.15, -0.6));
		for (int i = 0; i < 4; i++) {
			float tt = fract(t + float(i) * 0.25);
			float rr = tt * (i == 0 ? 1.2 : 0.7);
			float a = (1.0 - smoothstep(0.0, 0.05, abs(length(p - srcs[i]) - rr))) * (1.0 - tt);
			vec3 c = i == 0 ? vec3(1.0, 0.75, 0.4) : vec3(0.85, 0.5, 1.0);
			col = over(col, c, a);
			if (i > 0) {
				col += vec3(0.85, 0.5, 1.0) * glow(sd_circle(p - srcs[i], 0.07), 12.0) * 0.8;
			}
		}
		float core = sd_circle(p, 0.2) + (n - 0.5) * 0.1;
		col += vec3(1.0, 0.6, 0.25) * glow(core, 5.0) * 0.8;
		col = over(col, vec3(1.0, 0.9, 0.65), fill(core));
	} else if (icon == 10 || icon == 18) {
		// Spada lunga / Lama del vampiro
		bool vamp = icon == 18;
		col = bg_radial(p, vamp ? vec3(0.3, 0.03, 0.06) : vec3(0.18, 0.2, 0.26), vec3(0.03));
		vec2 q = rot(-0.785398) * p;
		float blade = max(sd_box(q - vec2(0.0, 0.18), vec2(0.1, 0.62)), q.y - 0.85 + abs(q.x) * 2.0);
		vec3 steel = vamp ? mix(vec3(0.5, 0.05, 0.08), vec3(0.95, 0.3, 0.3), step(0.0, q.x)) : mix(vec3(0.55, 0.6, 0.68), vec3(0.95, 0.97, 1.0), step(0.0, q.x));
		col += (vamp ? vec3(1.0, 0.1, 0.15) : vec3(0.7, 0.8, 1.0)) * glow(blade, 9.0) * 0.35;
		col = over(col, steel, fill(blade));
		col = over(col, vec3(0.92, 0.72, 0.3), fill(sd_box(q - vec2(0.0, -0.46), vec2(0.34, 0.06))));
		col = over(col, vec3(0.4, 0.22, 0.12), fill(sd_box(q - vec2(0.0, -0.66), vec2(0.06, 0.16))));
		col = over(col, vec3(0.95, 0.75, 0.3), fill(sd_circle(q - vec2(0.0, -0.85), 0.09)));
		if (vamp) {
			col = over(col, vec3(0.7, 0.02, 0.05), fill(sd_circle(p - vec2(0.35, -0.45), 0.08)));
			col = over(col, vec3(0.7, 0.02, 0.05), fill(sd_circle(p - vec2(0.5, -0.7), 0.05)));
		}
	} else if (icon == 11) {
		// Armatura di cuoio: scudo
		col = bg_radial(p, vec3(0.25, 0.16, 0.08), vec3(0.03));
		vec2 q = p - vec2(0.0, 0.05);
		float top = max(abs(q.x) - 0.55, q.y - 0.62);
		float wedge = (abs(q.x) * 0.75 - 0.55 * (q.y + 0.8)) / 0.93;
		float sh = max(top, wedge);
		col = over(col, mix(vec3(0.42, 0.25, 0.12), vec3(0.65, 0.42, 0.22), 0.5 + q.y * 0.5 - q.x * 0.3), fill(sh));
		col = over(col, mix(vec3(0.55, 0.38, 0.15), vec3(1.0, 0.85, 0.45), 0.5 + q.y * 0.5), 1.0 - smoothstep(0.0, 0.07, abs(sh + 0.04)));
		float cross_d = min(sd_box(q - vec2(0.0, 0.1), vec2(0.06, 0.35)), sd_box(q - vec2(0.0, 0.2), vec2(0.25, 0.06)));
		col = over(col, vec3(0.95, 0.78, 0.35), fill(cross_d));
	} else if (icon == 12) {
		// Stivali della velocità
		col = bg_radial(p, vec3(0.12, 0.2, 0.28), vec3(0.03));
		float leg = sd_box(p - vec2(-0.12, 0.15), vec2(0.24, 0.45)) - 0.04;
		float foot = sd_box(p - vec2(0.12, -0.42), vec2(0.48, 0.16)) - 0.06;
		float boot = min(leg, foot);
		col = over(col, mix(vec3(0.4, 0.24, 0.12), vec3(0.62, 0.4, 0.22), 0.5 + p.y * 0.4), fill(boot));
		col = over(col, vec3(0.8, 0.62, 0.35), fill(sd_box(p - vec2(-0.12, 0.55), vec2(0.3, 0.08))));
		for (int i = 0; i < 3; i++) {
			float w = sd_seg(p, vec2(-0.4, 0.2 - float(i) * 0.16), vec2(-0.85, 0.35 - float(i) * 0.12)) - 0.045;
			col = over(col, vec3(0.6, 0.9, 1.0), fill(w));
		}
	} else if (icon == 13) {
		// Gemma della vitalità
		col = bg_radial(p, vec3(0.35, 0.05, 0.08), vec3(0.03));
		float gem = (abs(p.x) / 0.55 + abs(p.y) / 0.78) - 1.0;
		col += vec3(1.0, 0.2, 0.25) * glow(gem * 0.5, 8.0) * 0.6;
		vec3 g = p.x < 0.0 ? (p.y > 0.0 ? vec3(1.0, 0.55, 0.6) : vec3(0.75, 0.1, 0.15)) : (p.y > 0.0 ? vec3(0.95, 0.3, 0.35) : vec3(0.55, 0.05, 0.1));
		col = over(col, g, fill(gem * 0.5));
		col = over(col, vec3(1.0), fill(sd_circle(p - vec2(-0.15, 0.25), 0.06)) * 0.8);
	} else if (icon == 14) {
		col = potion(p, vec3(0.95, 0.15, 0.2));
	} else if (icon == 17) {
		col = potion(p, vec3(0.2, 0.45, 1.0));
	} else if (icon == 15) {
		// Cristallo arcano
		col = bg_radial(p, vec3(0.08, 0.15, 0.4), vec3(0.02));
		vec2 q = abs(p);
		float hexd = max(q.x - 0.34, q.x * 0.6 + q.y * 0.5 - 0.48);
		col += vec3(0.3, 0.6, 1.0) * glow(hexd, 7.0) * 0.7;
		vec3 c = p.x < -0.1 ? vec3(0.55, 0.8, 1.0) : (p.x > 0.1 ? vec3(0.15, 0.35, 0.85) : vec3(0.35, 0.6, 1.0));
		col = over(col, c, fill(hexd));
		col = over(col, vec3(0.9, 0.97, 1.0), fill(sd_seg(p, vec2(-0.2, 0.3), vec2(-0.2, -0.1)) - 0.025) * 0.8);
	} else if (icon == 16) {
		// Anello di rigenerazione
		col = bg_radial(p, vec3(0.1, 0.25, 0.1), vec3(0.02));
		float ring = abs(sd_circle(p - vec2(0.0, -0.12), 0.42)) - 0.1;
		col = over(col, mix(vec3(0.6, 0.42, 0.12), vec3(1.0, 0.85, 0.4), 0.5 + p.y * 0.6 - p.x * 0.3), fill(ring));
		float gem = sd_circle(p - vec2(0.0, 0.36), 0.17);
		col += vec3(0.3, 1.0, 0.4) * glow(gem, 7.0) * 0.7;
		col = over(col, vec3(0.35, 1.0, 0.5), fill(gem));
		col = over(col, vec3(1.0), fill(sd_circle(p - vec2(-0.05, 0.42), 0.05)) * 0.8);
	}
	// cornice interna e luce morbida dall'alto
	col *= 0.85 + (1.0 - UV.y) * 0.3;
	col *= 1.0 - smoothstep(0.75, 1.45, length(p)) * 0.5;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l) * 0.55, dim);
	COLOR = vec4(col, 1.0);
}
