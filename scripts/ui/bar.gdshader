shader_type canvas_item;
// Velo sopra le barre di vita e mana (Hud): scia chiara del danno appena subito (tra value e trail),
// riflesso vetroso, ombra in basso, luccichio che scorre e cornice interna scura.

uniform float value = 1.0;          // frazione piena (0..1)
uniform float trail = 1.0;          // frazione della scia (>= value)
uniform vec4 trail_color : source_color = vec4(1.0, 0.92, 0.7, 0.75);
uniform vec2 size = vec2(296.0, 19.0);

void fragment() {
	vec2 p = UV * size;
	float aa = 1.0 / size.x;
	vec4 col = vec4(0.0);
	// scia del danno
	float tr = smoothstep(value - aa, value + aa, UV.x) * (1.0 - smoothstep(trail - aa, trail + aa, UV.x));
	col = mix(col, trail_color, tr * trail_color.a);
	float filled = 1.0 - smoothstep(value - aa, value + aa, UV.x);
	// riflesso vetroso in alto e ombra in basso
	float gloss = (1.0 - smoothstep(0.05, 0.45, UV.y)) * 0.22;
	float shade = smoothstep(0.65, 1.0, UV.y) * 0.25;
	col = mix(col, vec4(1.0, 1.0, 1.0, 1.0), gloss * max(filled, tr) * (1.0 - col.a * 0.5));
	col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), shade * filled);
	// luccichio che scorre lentamente sulla parte piena
	float sh = fract(TIME * 0.12);
	float sheen = 1.0 - smoothstep(0.0, 0.035, abs(UV.x - sh * 1.4 + 0.2 + (UV.y - 0.5) * 0.04));
	col = mix(col, vec4(1.0, 1.0, 1.0, 1.0), sheen * filled * 0.12);
	// filo luminoso sulla punta della barra
	col = mix(col, vec4(1.0, 1.0, 0.9, 1.0), (1.0 - smoothstep(0.0, 1.5, abs(p.x - value * size.x))) * 0.35 * step(0.002, value) * step(value, 0.998));
	// cornice interna scura
	float edge = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), (1.0 - smoothstep(0.0, 1.5, edge)) * 0.6);
	COLOR = col;
}
