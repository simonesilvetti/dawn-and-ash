shader_type spatial;
// Particella a "sbuffo" (fuoco o fumo) rivolta alla telecamera: un disco morbido eroso dal rumore,
// che si consuma con l'età (INSTANCE_CUSTOM.y). Usata come draw pass delle GPUParticles3D. BLEND_MODE viene
// sostituito da VfxLib (blend_add per il fuoco, blend_mix per il fumo).
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, BLEND_MODE;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 1.0;

varying float seed;
varying float age;

void vertex() {
	// billboard come StandardMaterial3D (BILLBOARD_PARTICLES), con la rotazione della particella
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mat_world = mat_world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	seed = fract(float(INSTANCE_ID) * 0.6180339);
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	// ogni particella ha una forma diversa (seme dall'indice dell'istanza)
	float n = texture(noise_tex, UV * 0.45 + vec2(seed * 7.3, seed * 3.1)).r;
	float shape = 1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * 0.7);
	float a = smoothstep(age * 0.7, age * 0.7 + 0.25, shape * (0.6 + n * 0.6));
	ALBEDO = COLOR.rgb * tint.rgb * intensity * (0.75 + shape * 0.5);
	ALPHA = clamp(a * tint.a * COLOR.a, 0.0, 1.0);
}
