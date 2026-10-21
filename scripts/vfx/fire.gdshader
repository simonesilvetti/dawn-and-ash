shader_type spatial;
// Fuoco "vivo" per il nucleo dei proiettili, la meteora e il muro di fiamme dell'onda d'urto:
// rumore che scorre verso l'alto, centro quasi bianco, bordi del colore della fiamma.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float intensity = 2.5;
uniform float fade = 1.0;
uniform float scroll = 1.2;
// 0 = sfera (il centro brilla di più), 1 = parete cilindrica (sfuma verso l'alto)
uniform float wall = 0.0;

varying float vy;   // altezza nella mesh: 0 alla base, 1 in cima (cilindro e sfera di altezza unitaria)

void vertex() {
	vy = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
	// la sfera mostra solo il lato davanti; la parete anche quello interno
	if (!FRONT_FACING && wall < 0.5) {
		discard;
	}
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	vec2 uv = mix(UV, vec2(UV.x, 1.0 - vy), wall) * vec2(2.0, 1.0);
	float n = texture(noise_tex, uv * 0.9 + vec2(0.0, -TIME * scroll)).r;
	n = n * 0.6 + texture(noise_tex, uv * 2.1 + vec2(TIME * 0.3, -TIME * scroll * 1.7)).r * 0.4;
	float core = mix(pow(facing, 1.5), 1.0 - vy, wall);
	float heat = clamp(core * 0.9 + (n - 0.5) * 0.9, 0.0, 1.0);
	vec3 hot = vec3(1.0, 0.95, 0.75);
	vec3 col = mix(color.rgb * 0.6, color.rgb, smoothstep(0.1, 0.5, heat));
	col = mix(col, hot, smoothstep(0.6, 0.95, heat) * (1.0 - wall * 0.6));
	float a = smoothstep(0.05, 0.35, heat);
	if (wall > 0.5) {
		// base piena, lingue di fuoco frastagliate verso l'alto
		a = smoothstep(0.0, 0.06, vy) * (1.0 - smoothstep(0.15, 0.75, vy + (n - 0.5) * 0.8));
	}
	ALBEDO = col * intensity;
	ALPHA = clamp(a * fade * color.a, 0.0, 1.0);
}
