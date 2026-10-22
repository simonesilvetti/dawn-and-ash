shader_type spatial;
// Crepa incandescente della Spaccaterra: linea frastagliata luminosa su un quad steso a terra lungo il colpo.
// UV.x = lungo la crepa, UV.y = di traverso. fade 1 -> 0 durante la vita dell'effetto.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float fade = 1.0;
uniform float seed = 0.0;

void fragment() {
	float n = texture(noise_tex, vec2(UV.x * 0.9 + seed, 0.3)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 2.6 + seed * 2.0, 0.7)).r;
	float center = 0.5 + (n - 0.5) * 0.35 + (n2 - 0.5) * 0.08;
	float d = abs(UV.y - center);
	// più larga al centro del colpo, sottile alle estremità; bordi rotti dal rumore
	float rough = texture(noise_tex, UV * vec2(6.0, 2.0) + seed).r;
	float w = mix(0.035, 0.12, sin(UV.x * 3.14159)) * (0.55 + 0.45 * fade) * (0.75 + rough * 0.5);
	float core = 1.0 - smoothstep(w * 0.4, w, d);
	float halo = exp(-d * 11.0) * 0.55;
	float ends = smoothstep(0.0, 0.06, UV.x) * smoothstep(1.0, 0.94, UV.x);
	// il calore si spegne prima ai bordi della crepa
	float heat = core + halo * fade;
	ALBEDO = mix(color.rgb, vec3(1.0, 0.92, 0.7), core * fade);
	ALPHA = clamp(heat * ends * fade * 1.4, 0.0, 1.0);
}
