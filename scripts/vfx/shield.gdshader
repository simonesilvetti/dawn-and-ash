shader_type spatial;
// Scudo degli edifici invulnerabili: solo il bordo (fresnel) è visibile, con una leggera pulsazione.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.8, 1.0, 1.0);

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0);
	ALBEDO = color.rgb * 1.5;
	ALPHA = clamp(fres * 0.55 * pulse, 0.0, 1.0);
}
