// Einfaches, guenstiges Wasser fuer den Hafen-Hintergrund.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep : source_color = vec3(0.03, 0.10, 0.14);
uniform vec3 shallow : source_color = vec3(0.10, 0.22, 0.26);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float w = sin(wp.x * 0.35 + TIME * 0.9) * 0.5 + sin(wp.z * 0.27 - TIME * 0.7) * 0.5;
	ALBEDO = mix(deep, shallow, 0.5 + 0.25 * w);
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.9;
	NORMAL_MAP = normalize(vec3(0.5 + 0.08 * w, 0.5 - 0.06 * w, 1.0));
}
