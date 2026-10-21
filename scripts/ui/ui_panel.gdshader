shader_type canvas_item;
// Pannello ornato dell'interfaccia (UiPanel): fondo scuro con grana e vignettatura, doppia cornice dorata
// con riflesso, ornamenti agli angoli. Le misure sono in pixel (size = dimensione del pannello).

uniform vec2 size = vec2(200.0, 100.0);
uniform float radius = 10.0;
uniform float border = 3.0;
uniform vec4 bg_top : source_color = vec4(0.13, 0.11, 0.13, 0.94);
uniform vec4 bg_bottom : source_color = vec4(0.05, 0.045, 0.06, 0.96);
uniform vec4 gold : source_color = vec4(0.92, 0.74, 0.38, 1.0);
uniform vec4 gold_dark : source_color = vec4(0.45, 0.31, 0.14, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform bool ornaments = true;

float rbox(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * size;
	vec2 c = p - size * 0.5;
	float d = rbox(c, size * 0.5, radius);
	float inside = 1.0 - smoothstep(-0.6, 0.6, d);

	// fondo: gradiente verticale, grana, vignettatura
	float n = texture(noise_tex, p / 180.0).r * 0.6 + texture(noise_tex, p / 40.0).r * 0.4;
	vec4 bg = mix(bg_top, bg_bottom, smoothstep(0.0, 1.0, UV.y));
	bg.rgb *= 0.85 + n * 0.3;
	float vig = smoothstep(0.0, 26.0, -d);
	bg.rgb *= mix(0.55, 1.0, vig);
	// riflesso morbido in alto
	bg.rgb += vec3(1.0, 0.85, 0.6) * 0.05 * (1.0 - smoothstep(0.0, 0.35, UV.y));

	// cornice: banda dorata esterna con gradiente e riflesso, filo scuro interno, filo dorato sottile
	float band = 1.0 - smoothstep(border - 0.6, border + 0.6, -d);
	float shine = 0.5 + 0.5 * sin(p.x * 0.035 + p.y * 0.02);
	vec3 g = mix(gold_dark.rgb, gold.rgb, clamp(0.35 + (1.0 - UV.y) * 0.5 + shine * 0.25, 0.0, 1.0));
	float dark_line = smoothstep(border - 0.2, border + 0.8, -d) * (1.0 - smoothstep(border + 1.2, border + 2.2, -d));
	float thin = smoothstep(border + 3.0, border + 3.8, -d) * (1.0 - smoothstep(border + 4.0, border + 4.8, -d));
	vec3 col = bg.rgb;
	col = mix(col, vec3(0.02, 0.015, 0.01), dark_line * 0.8);
	col = mix(col, gold.rgb * 0.75, thin * 0.55);
	col = mix(col, g, band);
	float a = mix(bg.a, 1.0, max(band, dark_line * 0.8));

	// ornamenti: rombi dorati sugli angoli e al centro dei lati lunghi
	if (ornaments) {
		float orn = 0.0;
		vec2 corners[4] = vec2[](vec2(radius + 2.0), vec2(size.x - radius - 2.0, radius + 2.0), vec2(radius + 2.0, size.y - radius - 2.0), size - vec2(radius + 2.0));
		for (int i = 0; i < 4; i++) {
			vec2 q = abs(p - corners[i]);
			orn = max(orn, 1.0 - smoothstep(4.5, 5.5, q.x + q.y));
		}
		vec2 qt = abs(p - vec2(size.x * 0.5, border * 0.5 + 1.0));
		vec2 qb = abs(p - vec2(size.x * 0.5, size.y - border * 0.5 - 1.0));
		orn = max(orn, 1.0 - smoothstep(6.0, 7.0, qt.x * 0.6 + qt.y * 1.4));
		orn = max(orn, 1.0 - smoothstep(6.0, 7.0, qb.x * 0.6 + qb.y * 1.4));
		col = mix(col, mix(gold.rgb, vec3(1.0, 0.95, 0.8), 0.3), orn);
		a = max(a, orn);
	}
	COLOR = vec4(col, a * inside);
}
