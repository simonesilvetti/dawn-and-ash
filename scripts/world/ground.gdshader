shader_type spatial;
// Terreno procedurale: erba (verde -> cenere oltre il fiume), corsia di terra, basi lastricate, fiume animato.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 lane_a = vec2(-72.0, 72.0);
uniform vec2 lane_b = vec2(72.0, -72.0);
uniform float lane_w = 15.0;
uniform vec2 base_r = vec2(-77.0, 77.0);
uniform vec2 base_d = vec2(77.0, -77.0);
uniform float base_rad = 26.0;
uniform float river_w = 5.0;
uniform bool clouds = true;

uniform vec3 grass_a : source_color = vec3(0.30, 0.55, 0.20);
uniform vec3 grass_b : source_color = vec3(0.46, 0.68, 0.26);
uniform vec3 ash_a : source_color = vec3(0.30, 0.25, 0.22);
uniform vec3 ash_b : source_color = vec3(0.42, 0.33, 0.27);
uniform vec3 dirt_a : source_color = vec3(0.62, 0.48, 0.32);
uniform vec3 dirt_b : source_color = vec3(0.74, 0.60, 0.42);
uniform vec3 stone_r : source_color = vec3(0.72, 0.70, 0.62);
uniform vec3 stone_d : source_color = vec3(0.30, 0.26, 0.28);
uniform vec3 water_a : source_color = vec3(0.10, 0.42, 0.55);
uniform vec3 water_b : source_color = vec3(0.30, 0.70, 0.78);

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	float n1 = texture(noise_tex, wpos * 0.012).r;
	float n2 = texture(noise_tex, wpos * 0.07 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, wpos * 0.31).r;

	vec2 lane_dir = normalize(lane_b - lane_a);
	float along = dot(wpos, lane_dir);          // <0 lato Lega, >0 lato Culto
	// Erba: verde rigoglioso -> cenere bruciata oltre il fiume
	float ash = smoothstep(10.0, 60.0, along + (n1 - 0.5) * 30.0);
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4));
	vec3 ashc = mix(ash_a, ash_b, smoothstep(0.3, 0.7, n2));
	vec3 col = mix(grass, ashc, ash * 0.85);
	col *= 0.9 + n3 * 0.2;
	float rough = 0.95;

	// Corsia di terra con bordo irregolare
	float d = seg_dist(wpos, lane_a, lane_b);
	float edge = lane_w - 2.0 + (n2 - 0.5) * 5.0;
	float path = 1.0 - smoothstep(edge - 2.5, edge, d);
	vec3 dirt = mix(dirt_a, dirt_b, n3);
	dirt = mix(dirt, dirt * 0.8, smoothstep(0.55, 0.75, n2));   // macchie
	dirt = mix(dirt, mix(dirt_a, ash_a, 0.5), ash * 0.5);
	col = mix(col, dirt, path);

	// Basi lastricate (pietra chiara / pietra scura)
	float dr = length(wpos - base_r);
	float dd = length(wpos - base_d);
	float tiles = step(0.5, fract((wpos.x + wpos.y) * 0.25)) * 0.06 + step(0.5, fract((wpos.x - wpos.y) * 0.25)) * 0.06;
	float br = 1.0 - smoothstep(base_rad - 6.0, base_rad - 4.0 + n2 * 2.0, dr);
	float bd = 1.0 - smoothstep(base_rad - 6.0, base_rad - 4.0 + n2 * 2.0, dd);
	col = mix(col, stone_r * (0.9 + tiles + n3 * 0.1), br);
	col = mix(col, stone_d * (0.9 + tiles + n3 * 0.15), bd);
	// Anello decorativo nel colore della squadra
	float ring_r = smoothstep(1.0, 0.0, abs(dr - (base_rad - 6.5)));
	float ring_d = smoothstep(1.0, 0.0, abs(dd - (base_rad - 6.5)));
	col = mix(col, vec3(0.85, 0.70, 0.30), ring_r * 0.6);
	col = mix(col, vec3(0.45, 0.18, 0.30), ring_d * 0.6);

	// Fiume perpendicolare alla corsia, con meandri
	vec2 river_dir = vec2(-lane_dir.y, lane_dir.x);
	float rpos = dot(wpos, river_dir);
	float rd = abs(along + sin(rpos * 0.045) * 6.0 + sin(rpos * 0.13) * 1.5);
	float bank = 1.0 - smoothstep(river_w, river_w + 3.0, rd);
	float water = 1.0 - smoothstep(river_w - 1.0, river_w, rd);
	col = mix(col, vec3(0.55, 0.50, 0.38), bank * 0.8);
	vec2 flow = wpos * 0.08 + river_dir * TIME * 0.05;
	float ripple = texture(noise_tex, flow).r * 0.6 + texture(noise_tex, flow * 2.3 - river_dir * TIME * 0.08).r * 0.4;
	vec3 wc = mix(water_a, water_b, smoothstep(0.35, 0.75, ripple));
	wc += smoothstep(0.72, 0.8, ripple) * 0.25;
	col = mix(col, wc, water);
	rough = mix(rough, 0.08, water);

	// ombre delle nuvole che scorrono lentamente
	if (clouds) {
		float cl = texture(noise_tex, wpos * 0.0035 + TIME * vec2(0.004, 0.0025)).r;
		col *= mix(1.0, 0.8, smoothstep(0.52, 0.72, cl));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.3, 0.8, water);
}
