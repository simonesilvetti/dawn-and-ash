shader_type spatial;
// Acqua del fiume: colore secondo la profondità, schiuma a riva, increspature e scie che scorrono, scintillii del sole.
// La profondità viene da una mappa del fondo calcolata una volta (Terrain.build_water): niente copia del depth buffer.
// QUALITY_HIGH legge invece il depth buffer (schiuma anche attorno alle unità) e aggiunge finte caustiche.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;

#ifdef QUALITY_HIGH
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
#endif
uniform sampler2D bed_tex : filter_linear, repeat_disable;   // profondità del fondo (0..bed_scale metri)
uniform float bed_scale = 2.0;
uniform vec2 plane_size = vec2(340.0, 30.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 lane_dir = vec2(0.7071, -0.7071);
uniform vec3 shallow : source_color = vec3(0.24, 0.62, 0.58);
uniform vec3 deep : source_color = vec3(0.03, 0.20, 0.34);
// direzione "artistica" della luce che crea gli scintillii: davanti alla telecamera (il sole vero è alle sue spalle)
uniform vec3 glint_dir = vec3(-0.3, 0.55, -0.78);

varying vec3 wpos;
varying vec2 bed_uv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	bed_uv = VERTEX.xz / plane_size + 0.5;
}

void fragment() {
	vec2 river_dir = vec2(-lane_dir.y, lane_dir.x);
	vec2 p = wpos.xz;
	vec2 flow = river_dir * TIME;
	vec3 n1 = texture(normal_tex, p * 0.045 + flow * 0.020).rgb;
	vec3 n2 = texture(normal_tex, p * 0.083 - flow * 0.013 + vec2(0.37, 0.61)).rgb;
	vec3 nt = normalize(n1 + n2 - 1.0);
	NORMAL_MAP = nt * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;

#ifdef QUALITY_HIGH
	float raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	v.xyz /= v.w;
	// distanza lungo il raggio tra la superficie e il fondo, ridotta a profondità verticale approssimata
	float depth = max(0.0, (VERTEX.z - v.z)) * 0.75;
#else
	float depth = texture(bed_tex, bed_uv).r * bed_scale;
#endif
	float d = clamp(depth / 1.3, 0.0, 1.0);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, d));

	// scie della corrente: rumore stirato lungo il fiume che scorre (linee chiare sottili)
	float across = dot(p, lane_dir);
	float along = dot(p, river_dir);
	float st = texture(noise_tex, vec2(along * 0.012 - TIME * 0.035, across * 0.16)).r;
	float streak = smoothstep(0.6, 0.66, st) * (1.0 - smoothstep(0.66, 0.74, st));
	col += vec3(0.75, 0.9, 0.95) * streak * mix(0.22, 0.10, d);

	// schiuma lungo la riva e attorno a ciò che emerge, spezzata dal rumore: una linea piena e una fascia rotta
	float nz = texture(noise_tex, p * 0.35 + flow * 0.05).r;
	float line = 1.0 - smoothstep(0.0, 0.025 + nz * 0.03, depth);
	float band = (1.0 - smoothstep(0.03, 0.12 + nz * 0.08, depth)) * smoothstep(0.52, 0.62, nz);
	float foam = max(line * smoothstep(0.3, 0.45, nz + 0.12), band * 0.75);

	// scintillii del sole: riflesso speculare finto con la normale perturbata (indipendente dalle luci)
	vec3 nw = normalize(vec3(nt.x * 0.9, 1.0, nt.y * 0.9));
	vec3 vw = normalize(CAMERA_POSITION_WORLD - wpos);
	float spec = pow(max(dot(reflect(-normalize(glint_dir), nw), vw), 0.0), 160.0);
	col += vec3(1.0, 0.95, 0.8) * smoothstep(0.55, 0.9, spec) * smoothstep(0.5, 0.7, nz) * 0.6;

#ifdef QUALITY_HIGH
	// riflessi di luce sul fondo nell'acqua bassa (finte caustiche)
	float caus = texture(noise_tex, p * 0.5 + flow * 0.08).r * texture(noise_tex, p * 0.37 - flow * 0.05 + vec2(0.5)).r;
	col += vec3(0.6, 0.85, 0.8) * smoothstep(0.32, 0.45, caus) * (1.0 - d) * 0.18;
#endif
	col = mix(col, vec3(0.92, 0.97, 1.0), foam * 0.8);
	ALBEDO = col;
	// acqua bassa quasi trasparente (si vede il fondo), profonda più coprente
	ALPHA = clamp(mix(0.2, 0.92, smoothstep(0.05, 0.9, d)) + foam * 0.7 + streak * 0.1, 0.0, 1.0);
	ROUGHNESS = 0.12;
	SPECULAR = 0.4;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.55, 0.75, 0.85) * fres * 0.25;
}
