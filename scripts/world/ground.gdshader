shader_type spatial;
// Terreno con texture CC0 (ambientCG) mescolate per zona: erba (verde -> bruciata oltre il fiume), sentiero della
// corsia, basi lastricate, roccia sui pendii, ciottoli nell'alveo. Il rilievo viene dalla mesh (Terrain.gd).
// Varianti: QUALITY_LOW (senza normal map), QUALITY_HIGH (filtro anisotropico e anti-ripetizione). Vedi MapBuilder._build_ground.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
#ifdef QUALITY_HIGH
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebbles_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebbles_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
#else
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D paving_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D paving_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pebbles_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pebbles_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
#endif

uniform vec2 lane_a = vec2(-72.0, 72.0);
uniform vec2 lane_b = vec2(72.0, -72.0);
uniform float lane_w = 15.0;
uniform vec2 base_r = vec2(-77.0, 77.0);
uniform vec2 base_d = vec2(77.0, -77.0);
uniform float base_rad = 26.0;
uniform float river_w = 5.0;
uniform bool clouds = true;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
	// UV = coordinate mondo x,z: tangente lungo +X, binormale lungo +Z
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - (a + ab * t));
}

vec3 sat(vec3 c, float s) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(l), c, s);
}

// Campiona una texture; in qualità alta mescola due scale diverse per nascondere la ripetizione.
vec3 tex2(sampler2D t, vec2 uv, float n) {
#ifdef QUALITY_HIGH
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, uv * 0.37 + vec2(0.31, 0.77)).rgb;
	return mix(a, b, smoothstep(0.35, 0.65, n));
#else
	return texture(t, uv).rgb;
#endif
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_tex, p * 0.012).r;
	float n2 = texture(noise_tex, p * 0.07 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, p * 0.31).r;

	vec2 lane_dir = normalize(lane_b - lane_a);
	float along = dot(p, lane_dir);          // <0 lato Lega, >0 lato Culto
	float ash = smoothstep(10.0, 60.0, along + (n1 - 0.5) * 30.0);

	// --- pesi dei livelli ---
	float d_lane = seg_dist(p, lane_a, lane_b);
	float edge = lane_w - 2.0 + (n2 - 0.5) * 5.0;
	float w_dirt = 1.0 - smoothstep(edge - 2.5, edge, d_lane);
	// solchi consumati al centro del sentiero
	float rut = 1.0 - smoothstep(2.0, 7.0, d_lane + (n2 - 0.5) * 4.0);

	float dr = length(p - base_r);
	float dd = length(p - base_d);
	float w_pave_r = 1.0 - smoothstep(base_rad - 6.0, base_rad - 4.0 + n2 * 2.0, dr);
	float w_pave_d = 1.0 - smoothstep(base_rad - 6.0, base_rad - 4.0 + n2 * 2.0, dd);
	float w_pave = max(w_pave_r, w_pave_d);

	vec2 river_dir = vec2(-lane_dir.y, lane_dir.x);
	float rpos = dot(p, river_dir);
	float rd = abs(along + sin(rpos * 0.045) * 6.0 + sin(rpos * 0.13) * 1.5);
	float w_bed = 1.0 - smoothstep(river_w + 0.5 + n3 * 1.5, river_w + 3.5 + n2 * 2.0, rd);

	float slope = 1.0 - normalize(wnrm).y;
	float w_rock = smoothstep(0.10, 0.22, slope + (n3 - 0.5) * 0.08);

	// --- erba / terra bruciata ---
	vec2 uv_g = p * 0.22;
	vec3 grass = tex2(grass_tex, uv_g, n2);
	grass = sat(grass, 1.3) * mix(vec3(0.82, 1.02, 0.62), vec3(1.12, 1.06, 0.55), smoothstep(0.45, 0.8, n1 * 0.7 + n2 * 0.3));
	vec3 col = grass;
	vec3 nm = vec3(0.5, 0.5, 1.0);
#ifndef QUALITY_LOW
	nm = texture(grass_nrm, uv_g).rgb;
#endif
	if (ash > 0.001) {
		vec3 soil = tex2(soil_tex, p * 0.18, n2) * vec3(0.78, 0.68, 0.66);
		vec3 burnt = mix(grass * vec3(0.75, 0.55, 0.38), soil, smoothstep(0.35, 0.7, n2));
		col = mix(grass, burnt, ash * 0.9);
#ifndef QUALITY_LOW
		nm = mix(nm, texture(soil_nrm, p * 0.18).rgb, ash * 0.6);
#endif
	}

	// --- sentiero della corsia ---
	if (w_dirt > 0.001) {
		vec2 uv_d = p * 0.17;
		vec3 dirt = tex2(dirt_tex, uv_d, n2) * vec3(0.95, 0.80, 0.62);
		dirt = mix(dirt, dirt * vec3(0.82, 0.74, 0.66), rut * 0.6);
		dirt = mix(dirt, dirt * vec3(0.62, 0.55, 0.55), ash * 0.55);
		col = mix(col, dirt, w_dirt);
#ifndef QUALITY_LOW
		nm = mix(nm, texture(dirt_nrm, uv_d).rgb, w_dirt);
#endif
	}

	// --- basi lastricate (pietra chiara / pietra scura) ---
	if (w_pave > 0.001) {
		vec2 uv_p = p * 0.25;
		vec3 pave = texture(paving_tex, uv_p).rgb;
		pave = mix(pave * vec3(1.12, 1.08, 0.96), pave * vec3(0.48, 0.40, 0.44), w_pave_d / max(w_pave, 0.001));
		col = mix(col, pave, w_pave);
#ifndef QUALITY_LOW
		nm = mix(nm, texture(paving_nrm, uv_p).rgb, w_pave);
#endif
		// anello decorativo nel colore della squadra
		float ring_r = smoothstep(1.0, 0.0, abs(dr - (base_rad - 6.5)));
		float ring_d = smoothstep(1.0, 0.0, abs(dd - (base_rad - 6.5)));
		col = mix(col, vec3(0.72, 0.58, 0.28), ring_r * 0.4);
		col = mix(col, vec3(0.34, 0.12, 0.2), ring_d * 0.4);
	}

	// --- alveo e rive: ciottoli ---
	if (w_bed > 0.001) {
		vec2 uv_b = p * 0.35;
		vec3 peb = texture(pebbles_tex, uv_b).rgb * vec3(0.85, 0.82, 0.74);
		// sotto il livello dell'acqua i ciottoli sono bagnati e più scuri
		peb *= mix(1.0, 0.55, smoothstep(-0.05, -0.4, wpos.y));
		col = mix(col, peb, w_bed);
#ifndef QUALITY_LOW
		nm = mix(nm, texture(pebbles_nrm, uv_b).rgb, w_bed);
#endif
	}

	// --- roccia sui pendii (proiezione biplanare: niente stiramento sulle pareti) ---
	if (w_rock > 0.001) {
		vec3 an = abs(normalize(wnrm));
		vec3 rx = texture(rock_tex, wpos.zy * 0.12).rgb;
		vec3 rz = texture(rock_tex, wpos.xy * 0.12).rgb;
		vec3 rock = (rx * an.x + rz * an.z) / max(an.x + an.z, 0.001);
		rock = mix(rock * vec3(1.05, 0.98, 0.88), rock * vec3(0.62, 0.55, 0.56), ash);
		col = mix(col, rock, w_rock);
		nm = mix(nm, vec3(0.5, 0.5, 1.0), w_rock);
	}

	// variazione a grande scala (macchie di luce e d'ombra) per evitare l'effetto "tappeto"
	col *= 0.88 + n1 * 0.24;
	// l'alveo incassato riceve meno luce
	col *= 1.0 + max(wpos.y, -1.8) * 0.12 * step(wpos.y, 0.0);

	if (clouds) {
		float cl = texture(noise_tex, p * 0.0035 + TIME * vec2(0.004, 0.0025)).r;
		col *= mix(1.0, 0.8, smoothstep(0.52, 0.72, cl));
	}
	ALBEDO = col;
#ifndef QUALITY_LOW
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.0;
#endif
	ROUGHNESS = mix(0.92, 0.45, w_bed * smoothstep(-0.05, -0.3, wpos.y));
	SPECULAR = 0.35;
}
