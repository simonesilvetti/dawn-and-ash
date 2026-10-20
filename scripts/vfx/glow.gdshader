shader_type spatial;
// Materiale emissivo additivo con fresnel: cristalli, proiettili, colonne di luce.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float intensity = 2.0;
uniform float fade = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = color.rgb * intensity * (0.35 + fres);
	ALPHA = clamp(color.a * fade * (0.5 + fres), 0.0, 1.0);
}
