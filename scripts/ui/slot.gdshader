shader_type canvas_item;
// Alloggiamento di un'abilità o di un oggetto (AbilityButton), disegnato sopra l'icona.
// Il rettangolo è più grande del pulsante di `margin` px per lato: fuori c'è l'incasso nella console
// (ombra) e il bagliore al passaggio del mouse; poi la cornice di metallo smussata, la scanalatura interna,
// l'ombra interna sull'icona, la ricarica a spicchio con il bordo luminoso, il velo blu senza mana,
// il riflesso vetroso e il lampo quando l'abilità torna pronta.

uniform vec2 size = vec2(72.0, 72.0);       // dimensione del rettangolo (pulsante + margini)
uniform float margin = 5.0;
uniform float bevel = 3.0;                 // spessore della cornice
uniform float radius = 4.0;
uniform float cooldown = 0.0;              // frazione di ricarica rimanente (0 = pronta)
uniform float hovered = 0.0;
uniform float learned = 1.0;               // 0 = abilità non imparata (cornice d'acciaio spento)
uniform float no_mana = 0.0;
uniform float flash = 0.0;                 // lampo "di nuovo pronta" (0..1)
uniform float can_learn = 0.0;
uniform float empty = 0.0;                 // casella oggetto vuota
uniform vec4 metal_lo : source_color = vec4(0.36, 0.24, 0.11, 1.0);
uniform vec4 metal_hi : source_color = vec4(1.0, 0.86, 0.5, 1.0);

float rbox(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// normale (2D) del bordo più vicino del rettangolo arrotondato
vec2 rbox_normal(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	vec2 n = (q.x > 0.0 && q.y > 0.0) ? normalize(q) : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	return n * sign(p + 1e-4);
}

// composizione "sopra" in spazio premoltiplicato
vec4 over(vec4 acc, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	return vec4(c * a + acc.rgb * (1.0 - a), a + acc.a * (1.0 - a));
}

void fragment() {
	vec2 p = UV * size;
	vec2 c = p - size * 0.5;
	vec2 half_btn = size * 0.5 - margin;
	float d = rbox(c, half_btn, radius);               // < 0 dentro il pulsante
	float aa = 0.75;
	vec4 acc = vec4(0.0);

	// --- fuori: incasso (ombra morbida verso il basso) e bagliore al passaggio del mouse
	float outside = smoothstep(-aa, aa, d);
	float recess = (1.0 - smoothstep(0.0, margin, rbox(c - vec2(0.0, 1.5), half_btn, radius))) * outside;
	acc = over(acc, vec3(0.0), recess * 0.55);
	float glow = (1.0 - smoothstep(0.0, margin, d)) * outside;
	acc = over(acc, vec3(1.0, 0.82, 0.4), glow * (hovered * 0.55 + can_learn * 0.35 * (0.6 + 0.4 * sin(TIME * 6.0))));

	float inside = 1.0 - outside;
	float d_in = -d;                                   // distanza dal bordo verso l'interno
	float frame = inside * (1.0 - smoothstep(bevel - aa, bevel + aa, d_in));
	float icon_area = inside * smoothstep(bevel + 1.0 - aa, bevel + 1.0 + aa, d_in);

	if (empty < 0.5) {
		// --- ombra interna sull'icona (profondità) e vignettatura agli angoli
		float ishadow = (1.0 - smoothstep(0.0, 7.0, d_in - bevel)) * 0.5;
		acc = over(acc, vec3(0.0), icon_area * ishadow);

		// --- ricarica: spicchio scuro in senso orario dall'alto, con il bordo luminoso
		if (cooldown > 0.0) {
			float ang = atan(c.x, -c.y);                   // 0 in alto, cresce in senso orario
			ang = ang < 0.0 ? ang + 6.2831853 : ang;
			float done = 1.0 - cooldown;
			float sweep = step(done * 6.2831853, ang);
			acc = over(acc, vec3(0.0), icon_area * sweep * 0.62);
			float edge_ang = done * 6.2831853;
			vec2 ed = vec2(sin(edge_ang), -cos(edge_ang));
			float line_d = abs(dot(c, vec2(-ed.y, ed.x)));
			float on_ray = step(0.0, dot(c, ed));
			acc = over(acc, vec3(1.0, 0.85, 0.5), icon_area * on_ray * (1.0 - smoothstep(0.0, 1.4, line_d)) * 0.8);
		}
		// --- mana insufficiente: velo blu
		acc = over(acc, vec3(0.1, 0.22, 0.75), icon_area * no_mana * 0.42);
		// --- riflesso vetroso in alto e filo di luce diagonale
		float gloss = (1.0 - smoothstep(0.0, 0.55, UV.y)) * 0.14 + (1.0 - smoothstep(0.0, 0.05, abs(UV.x + UV.y - 0.62))) * 0.05;
		acc = over(acc, vec3(1.0), icon_area * gloss);
		// --- lampo quando torna pronta: banda che attraversa l'icona
		if (flash > 0.0) {
			float band = 1.0 - smoothstep(0.0, 0.12, abs(UV.x + UV.y - (1.0 - flash) * 2.4));
			acc = over(acc, vec3(1.0, 0.95, 0.75), icon_area * (band * 0.75 + flash * 0.25));
		}
	} else {
		// casella vuota: fondo incassato scuro con grana
		acc = over(acc, vec3(0.045, 0.04, 0.045), icon_area * 0.92);
		acc = over(acc, vec3(0.0), icon_area * (1.0 - smoothstep(0.0, 9.0, d_in - bevel)) * 0.55);
	}

	// --- scanalatura scura tra cornice e icona
	float groove = inside * (1.0 - smoothstep(0.0, 1.0, abs(d_in - bevel - 0.4)));
	acc = over(acc, vec3(0.02, 0.015, 0.01), groove * 0.9);

	// --- cornice metallica smussata: luce da in alto a sinistra
	vec2 n = rbox_normal(c, half_btn, radius);
	float lit = clamp(0.5 + 0.5 * dot(n, normalize(vec2(-0.6, -1.0))), 0.0, 1.0);
	float bev_k = clamp(d_in / bevel, 0.0, 1.0);          // 0 sul bordo esterno, 1 su quello interno
	float ridge = 1.0 - abs(bev_k - 0.45) * 1.6;          // cresta al centro della cornice
	vec3 lo = metal_lo.rgb;
	vec3 hi = metal_hi.rgb;
	if (learned < 0.5) {
		lo = vec3(0.16, 0.16, 0.17);
		hi = vec3(0.55, 0.55, 0.57);
	}
	vec3 metal = mix(lo, hi, clamp(lit * 0.75 + ridge * 0.35, 0.0, 1.0));
	metal *= 1.0 + hovered * 0.25 + flash * 0.4;
	acc = over(acc, metal, frame);
	// filo scuro sul bordo esterno
	acc = over(acc, vec3(0.03, 0.02, 0.01), inside * (1.0 - smoothstep(0.0, 0.9, d_in)) * 0.85);

	COLOR = acc.a > 0.0001 ? vec4(acc.rgb / acc.a, acc.a) : vec4(0.0);
}
