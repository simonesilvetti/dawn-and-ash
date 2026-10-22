shader_type canvas_item;
// Console in basso (Hud): fondo di bronzo scuro con grana e incisioni a rombi, cornice metallica smussata
// con rivetti, angoli ornati con gemme, separatori incisi tra le sezioni (ritratto | abilità | oggetti | statistiche)
// e stemma con una gemma del colore della squadra sopra le abilità. Misure in pixel.

uniform vec2 size = vec2(744.0, 146.0);
uniform float radius = 12.0;
uniform vec3 dividers = vec3(-100.0);      // x dei separatori verticali (negativo = assente)
uniform float crest_x = -100.0;            // x dello stemma (negativo = assente)
uniform vec4 team_color : source_color = vec4(0.25, 0.85, 0.75, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float rbox(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 rbox_normal(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	vec2 n = (q.x > 0.0 && q.y > 0.0) ? normalize(q) : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	return n * sign(p + 1e-4);
}

vec3 metal(float lit) {
	return mix(vec3(0.3, 0.19, 0.08), vec3(1.0, 0.85, 0.52), clamp(lit, 0.0, 1.0));
}

float band(float x, float a, float b) {
	return smoothstep(a - 0.7, a + 0.7, x) * (1.0 - smoothstep(b - 0.7, b + 0.7, x));
}

void fragment() {
	vec2 p = UV * size;
	vec2 c = p - size * 0.5;
	float d = rbox(c, size * 0.5, radius);
	float inside = 1.0 - smoothstep(-0.7, 0.7, d);
	float di = -d;                                          // distanza dal bordo verso l'interno
	vec2 n = rbox_normal(c, size * 0.5, radius);
	float lit_edge = 0.5 + 0.5 * dot(n, normalize(vec2(-0.5, -1.0)));

	// --- fondo: gradiente, grana, incisioni a rombi molto leggere, vignettatura, riflesso in alto
	float g1 = texture(noise_tex, p / 220.0).r;
	float g2 = texture(noise_tex, p / 37.0).r;
	vec3 col = mix(vec3(0.125, 0.1, 0.088), vec3(0.05, 0.043, 0.048), smoothstep(0.0, 1.0, UV.y));
	col *= 0.82 + g1 * 0.28 + (g2 - 0.5) * 0.1;
	float la = abs(fract((p.x + p.y) / 26.0) - 0.5);
	float lb = abs(fract((p.x - p.y) / 26.0) - 0.5);
	float lattice = max(1.0 - smoothstep(0.0, 0.03, la), 1.0 - smoothstep(0.0, 0.03, lb));
	col *= 1.0 - lattice * 0.07;
	col += vec3(1.0, 0.8, 0.55) * lattice * 0.012 * step(0.5, fract((p.x + p.y) / 52.0));
	col *= mix(0.6, 1.0, smoothstep(0.0, 34.0, di));
	col += vec3(1.0, 0.85, 0.6) * 0.045 * (1.0 - smoothstep(0.0, 0.3, UV.y));

	// --- separatori incisi tra le sezioni, con un rombo al centro
	for (int i = 0; i < 3; i++) {
		float x = dividers[i];
		if (x < 0.0) continue;
		float dx = p.x - x;
		float vis = smoothstep(14.0, 24.0, p.y) * (1.0 - smoothstep(size.y - 24.0, size.y - 14.0, p.y));
		col = mix(col, vec3(0.015, 0.01, 0.01), band(dx, -1.2, 0.3) * vis * 0.85);
		col = mix(col, vec3(0.62, 0.48, 0.3), band(dx, 0.3, 1.2) * vis * 0.35);
		vec2 q = abs(vec2(dx, p.y - size.y * 0.5));
		float dia = q.x + q.y * 0.7;
		col = mix(col, metal(0.85 - (p.y - size.y * 0.5) * 0.08), 1.0 - smoothstep(4.0, 5.0, dia));
		col = mix(col, vec3(0.05, 0.03, 0.02), (1.0 - smoothstep(0.5, 1.2, abs(dia - 5.0))) * 0.8);
	}

	// --- cornice: filo scuro, fascia di metallo smussata con rivetti, scanalatura, filetto dorato
	float ridge = 1.0 - abs(clamp((di - 1.0) / 5.0, 0.0, 1.0) - 0.4) * 1.5;
	vec3 frame_col = metal(lit_edge * 0.8 + ridge * 0.3);
	frame_col *= 0.9 + texture(noise_tex, p / 9.0).r * 0.2;
	col = mix(col, frame_col, band(di, 1.0, 6.0));
	// rivetti lungo i lati lunghi
	float rx = mod(p.x - 28.0, 56.0) - 28.0;
	for (int s = 0; s < 2; s++) {
		float ry = s == 0 ? 3.5 : size.y - 3.5;
		vec2 rp = vec2(rx, p.y - ry);
		float rv = length(rp);
		float on = step(30.0, p.x) * step(p.x, size.x - 30.0);
		col = mix(col, vec3(0.08, 0.05, 0.02), (1.0 - smoothstep(1.6, 2.4, rv)) * on);
		col = mix(col, metal(0.9 - rp.y * 0.25 - rp.x * 0.15), (1.0 - smoothstep(1.0, 1.7, rv)) * on);
	}
	col = mix(col, vec3(0.012, 0.008, 0.006), band(di, 6.0, 7.6) * 0.95);
	col = mix(col, vec3(0.85, 0.66, 0.36), band(di, 9.0, 9.9) * 0.45);
	col = mix(col, vec3(0.02, 0.015, 0.01), (1.0 - smoothstep(0.0, 1.1, di)) * 0.9);

	// --- angoli ornati: staffa a L sopra la cornice e gemma della squadra
	vec2 corner_p = vec2(size.x * 0.5 - abs(c.x), size.y * 0.5 - abs(c.y));    // distanza dall'angolo più vicino
	// staffa: ispessimento della cornice che si assottiglia allontanandosi dall'angolo
	float thick_x = mix(10.0, 6.0, clamp(corner_p.y / 26.0, 0.0, 1.0));
	float thick_y = mix(10.0, 6.0, clamp(corner_p.x / 26.0, 0.0, 1.0));
	float bracket = max(band(corner_p.x, 1.0, thick_x) * step(corner_p.y, 26.0), band(corner_p.y, 1.0, thick_y) * step(corner_p.x, 26.0));
	float bl = 0.55 + 0.45 * dot(n, normalize(vec2(-0.5, -1.0)));
	col = mix(col, metal(bl * 0.8 + 0.2), bracket * inside);
	// filo scuro che contorna la staffa
	float b_edge = max(band(corner_p.x, thick_x - 0.6, thick_x + 0.6) * step(corner_p.y, 26.0) * step(6.5, corner_p.y),
		band(corner_p.y, thick_y - 0.6, thick_y + 0.6) * step(corner_p.x, 26.0) * step(6.5, corner_p.x));
	col = mix(col, vec3(0.03, 0.02, 0.01), b_edge * 0.8);
	vec2 gp = corner_p - vec2(10.0);
	float gem = length(gp);
	col = mix(col, vec3(0.04, 0.02, 0.01), 1.0 - smoothstep(4.2, 5.2, gem));
	vec3 gem_col = team_color.rgb * (0.55 + 0.9 * (1.0 - smoothstep(0.0, 4.0, length(gp + vec2(1.2)))));
	col = mix(col, gem_col, 1.0 - smoothstep(3.2, 4.0, gem));

	// --- stemma sopra le abilità: placca a mezzaluna con gemma luminosa
	if (crest_x > 0.0) {
		vec2 cp = vec2(p.x - crest_x, p.y);
		float plate = length(cp * vec2(1.0 / 46.0, 1.0 / 14.0)) - 1.0;
		float plate_in = 1.0 - smoothstep(-0.02, 0.02, plate);
		vec3 pc = metal(0.95 - cp.y * 0.04 - abs(cp.x) * 0.006);
		col = mix(col, vec3(0.02, 0.012, 0.008), (1.0 - smoothstep(-0.02, 0.1, plate)) * 0.9);
		col = mix(col, pc, plate_in);
		col = mix(col, vec3(0.05, 0.03, 0.015), band(plate, -0.16, -0.1) * plate_in * 0.8);
		vec2 gq = cp - vec2(0.0, 5.5);
		float dg = abs(gq.x) / 7.0 + abs(gq.y) / 5.0 - 1.0;
		float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
		col = mix(col, vec3(0.03, 0.02, 0.01), 1.0 - smoothstep(0.0, 0.25, dg));
		vec3 gc = team_color.rgb * (0.7 + 0.8 * (1.0 - smoothstep(-1.0, 0.2, dg + gq.y * 0.08))) * pulse;
		col = mix(col, gc, 1.0 - smoothstep(-0.25, -0.05, dg));
		col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 1.2, length(gq - vec2(-2.0, -1.5)))) * 0.7);
	}

	COLOR = vec4(col, inside);
}
