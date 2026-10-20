shader_type spatial;
// Vegetazione low-poly con ondeggiamento al vento (usata nelle MultiMesh).
render_mode diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float sway = 0.035;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float w = sin(TIME * 1.4 + origin.x * 0.13 + origin.z * 0.11) + 0.5 * sin(TIME * 2.3 + origin.x * 0.31);
	VERTEX.x += w * sway * h * h;
	VERTEX.z += w * sway * 0.6 * h * h;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * tint;
	ROUGHNESS = 0.9;
}
