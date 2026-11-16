shader_type spatial;
// Anteprima di mira delle abilità in linea (Spaccaterra, Fenditura): rettangolo steso a terra con bordi
// luminosi e frecce che scorrono verso la punta. UV.x = lungo la linea (0 = eroe), UV.y = di traverso.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.25, 0.85);

void fragment() {
	float y = abs(UV.y - 0.5) * 2.0;
	float edge = smoothstep(0.82, 0.93, y) * (1.0 - smoothstep(0.96, 1.0, y));
	float fill = (1.0 - step(1.0, y)) * 0.12;
	// frecce (chevron) che avanzano verso la punta
	float chev = fract(UV.x * 6.0 + y * 0.6 - TIME * 1.2);
	float arrows = smoothstep(0.0, 0.08, chev) * (1.0 - smoothstep(0.12, 0.22, chev)) * (1.0 - smoothstep(0.55, 0.8, y)) * 0.5;
	float ends = smoothstep(0.0, 0.04, UV.x) * (1.0 - smoothstep(0.96, 1.0, UV.x));
	ALBEDO = color.rgb;
	ALPHA = clamp((edge + fill + arrows) * ends * color.a, 0.0, 1.0);
}
