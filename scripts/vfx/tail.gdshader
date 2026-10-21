shader_type spatial;
// Coda continua dei proiettili: un quad allungato all'indietro lungo la direzione di volo (orientato da Vfx.gd).
// UV.x = 0 in coda, 1 in testa; UV.y attraversa la larghezza.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float intensity = 2.0;
uniform float fade = 1.0;

void fragment() {
	float along = UV.x;
	float across = abs(UV.y - 0.5) * 2.0;
	// la coda si assottiglia andando indietro
	float width = mix(0.15, 1.0, pow(along, 0.7));
	float n = texture(noise_tex, vec2(UV.x * 1.5 - TIME * 2.5, UV.y * 0.8 + TIME * 0.2)).r;
	float body = 1.0 - smoothstep(width * 0.55, width, across + (n - 0.5) * 0.35);
	float a = body * pow(along, 1.4);
	vec3 col = mix(color.rgb, vec3(1.0, 0.95, 0.8), smoothstep(0.75, 1.0, along) * (1.0 - across));
	ALBEDO = col * intensity;
	ALPHA = clamp(a * fade * color.a, 0.0, 1.0);
}
