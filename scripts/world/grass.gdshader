shader_type spatial;
// Vegetazione minuta procedurale (ciuffi d'erba, fiori, cespugli) nelle MultiMesh di Scenery.gd.
// Colore = colore dei vertici × colore dell'istanza; i petali (alfa del vertice < 0.5) usano INSTANCE_CUSTOM.
render_mode diffuse_burley, cull_disabled, specular_disabled;

uniform float sway = 0.12;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform bool clouds = true;

varying vec3 tint;
varying vec2 wpos;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	wpos = origin.xz;
	float h = max(VERTEX.y, 0.0);
	float w = sin(TIME * 1.7 + origin.x * 0.21 + origin.z * 0.17) + 0.45 * sin(TIME * 3.1 + origin.x * 0.6);
	VERTEX.x += w * sway * h * h;
	VERTEX.z += w * sway * 0.6 * h * h;
	// COLOR = colore del vertice × colore dell'istanza (MultiMesh.use_colors)
	tint = COLOR.a < 0.5 ? INSTANCE_CUSTOM.rgb : COLOR.rgb;
	// normali "verso l'alto": l'erba si illumina come il terreno sotto (niente lati scuri)
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	vec3 col = tint;
	if (clouds) {
		float cl = texture(noise_tex, wpos * 0.0035 + TIME * vec2(0.004, 0.0025)).r;
		col *= mix(1.0, 0.8, smoothstep(0.52, 0.72, cl));
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
