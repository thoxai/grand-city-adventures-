// Pflaster-/Plattenbelag für Plätze, Wege und Werkstatthof (prozedural).
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.62, 0.58, 0.52);
uniform float tile_size = 1.6;
uniform float seam = 0.05;
uniform float variation = 0.12;
uniform float roughness_value = 0.85;

varying vec3 wp;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz / tile_size;
	// Versetzter Verband (jede zweite Reihe um eine halbe Platte verschoben)
	p.x += step(0.5, fract(floor(p.y) * 0.5)) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float s = step(f.x, seam) + step(f.y, seam);
	vec3 col = base_color * (1.0 - variation * 0.5 + variation * hash12(cell));
	col *= 1.0 - 0.28 * clamp(s, 0.0, 1.0);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
