// Boden-Shader: Asphalt, Fahrbahnmarkierungen, Zebrastreifen, Gehwegplatten
// und Bordsteine werden aus der Weltposition berechnet (keine Texturen noetig).
// Strassenraster: Mittellinien bei -180, -90, 0, 90, 180 m.
shader_type spatial;

uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

varying vec3 wp;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float road_dist(float c) {
	return abs(mod(c + 225.0, 90.0) - 45.0);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float dx = road_dist(p.x);
	float dz = road_dist(p.y);
	bool inside = abs(p.x) < 200.0 && abs(p.y) < 200.0;
	bool road_a = dx < 7.0 && abs(p.y) < 187.0;   // Strasse in Nord-Sued-Richtung
	bool road_b = dz < 7.0 && abs(p.x) < 187.0;   // Strasse in Ost-West-Richtung
	float n1 = vnoise(p * 0.35);
	float n2 = vnoise(p * 3.1);
	vec3 col;
	float rough = 0.9;
	float spec = 0.4;
	if (!inside) {
		col = mix(vec3(0.20, 0.25, 0.14), vec3(0.28, 0.30, 0.18), n1);
		rough = 1.0;
	} else if (road_a || road_b) {
		col = vec3(0.075, 0.078, 0.085) * (0.85 + 0.25 * n1 + 0.1 * n2);
		rough = mix(0.78, 0.35, wetness);
		bool crossing = road_a && road_b;
		float paint = 0.0;
		vec3 paint_col = vec3(0.88, 0.88, 0.84);
		if (!crossing) {
			float d = road_a ? dx : dz;
			float along = road_a ? p.y : p.x;
			// Mittellinie (gestrichelt) und Randlinien
			paint += step(d, 0.12) * step(fract(along / 6.0), 0.5);
			paint += step(6.25, d) * step(d, 6.42);
			// Zebrastreifen vor Kreuzungen
			float cross_d = road_a ? dz : dx;
			if (cross_d > 8.0 && cross_d < 11.5 && d < 6.0) {
				paint += step(fract(d / 1.0), 0.5);
			}
			// Haltelinie
			if (cross_d > 11.8 && cross_d < 12.3 && d > 0.3 && d < 6.0) {
				paint += 1.0;
			}
		}
		paint = clamp(paint, 0.0, 1.0) * (0.75 + 0.25 * n2);
		col = mix(col, paint_col, paint);
		rough = mix(rough, 0.6, paint);
	} else {
		bool sidewalk = dx < 11.0 || dz < 11.0 || abs(p.x) > 187.0 || abs(p.y) > 187.0;
		if (sidewalk) {
			vec2 t = fract(p / 1.2);
			float seam = step(t.x, 0.04) + step(t.y, 0.04);
			col = vec3(0.50, 0.49, 0.47) * (0.9 + 0.12 * hash12(floor(p / 1.2)));
			col *= 1.0 - 0.25 * clamp(seam, 0.0, 1.0);
			if ((dx < 7.35 || dz < 7.35)) {
				col = vec3(0.62, 0.62, 0.6);
			}
			rough = 0.85;
		} else {
			col = vec3(0.36, 0.355, 0.34) * (0.85 + 0.2 * n1 + 0.08 * n2);
			rough = 0.92;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
