shader_type spatial;
// Vegetazione low-poly con ondeggiamento al vento (usata nelle MultiMesh).
render_mode diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float sway = 0.035;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform bool clouds = false;
// dettaglio di roccia proiettato (biplanare) per sassi e montagne: lega i modelli KayKit al terreno con texture
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail = 0.0;
// variazione per istanza (tinta e luminosità da un hash della posizione) e ombra finta alla base, in metri
uniform float vary = 0.0;
uniform float base_ao = 0.0;
varying vec2 wpos;
varying float hgt;
varying vec3 wp3;
varying vec3 wn;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	wpos = origin.xz;
	float h = max(VERTEX.y, 0.0);
	float w = sin(TIME * 1.4 + origin.x * 0.13 + origin.z * 0.11) + 0.5 * sin(TIME * 2.3 + origin.x * 0.31);
	VERTEX.x += w * sway * h * h;
	VERTEX.z += w * sway * 0.6 * h * h;
	wp3 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hgt = wp3.y - origin.y;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint;
	if (vary > 0.0) {
		vec3 q = fract(vec3(wpos.x, wpos.y, wpos.x + wpos.y) * 0.1031);
		q += dot(q, q.yzx + 33.33);
		float h = fract((q.x + q.y) * q.z);
		float h2 = fract((q.x + q.z) * q.y);
		// verdi più profondi e caldi dell'atlante KayKit (troppo color menta), con alberi più scuri o più gialli
		vec3 v = mix(vec3(0.50, 0.66, 0.42), vec3(1.05, 0.98, 0.42), h * h) * (0.8 + h2 * 0.35);
		col *= mix(vec3(1.0), v, vary);
	}
	if (base_ao > 0.0) {
		col *= mix(0.55, 1.0, smoothstep(0.0, base_ao, hgt));
	}
	if (detail > 0.0) {
		vec3 an = abs(wn);
		vec3 d = (texture(detail_tex, wp3.zy * 0.35).rgb * an.x + texture(detail_tex, wp3.xz * 0.35).rgb * an.y
			+ texture(detail_tex, wp3.xy * 0.35).rgb * an.z) / (an.x + an.y + an.z);
		col *= mix(vec3(1.0), d * 2.2, detail);
	}
	if (clouds) {
		float cl = texture(noise_tex, wpos * 0.0035 + TIME * vec2(0.004, 0.0025)).r;
		col *= mix(1.0, 0.8, smoothstep(0.52, 0.72, cl));
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
