// Fassaden-Shader fuer alle Gebaeude (eine MultiMesh = ein Draw-Call).
// Fenster, Stockwerksbaender und Ladenzeilen werden prozedural aus der
// Weltposition berechnet. Nachts leuchten zufaellig verteilte Fenster.
// Instanzfarbe (MultiMesh COLOR): rgb = Fassadenfarbe, a = Zufallswert.
shader_type spatial;
render_mode cull_back;

uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 window_glow : source_color = vec3(1.0, 0.8, 0.52);
uniform vec3 glass_color : source_color = vec3(0.07, 0.09, 0.12);
uniform vec3 shop_glow : source_color = vec3(1.0, 0.86, 0.62);

varying vec3 world_pos;
varying vec3 world_nrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float seed = COLOR.a * 97.0;
	vec3 n = world_nrm;
	if (n.y > 0.5) {
		// Dach: dunkle Bitumenflaeche mit leichter Struktur
		float g = hash12(floor(world_pos.xz * 0.5));
		ALBEDO = mix(vec3(0.16, 0.16, 0.17), base * 0.35, 0.4) * (0.9 + 0.1 * g);
		ROUGHNESS = 0.95;
	} else if (n.y < -0.5) {
		ALBEDO = base * 0.3;
		ROUGHNESS = 1.0;
	} else {
		float u = abs(n.x) > 0.5 ? world_pos.z : world_pos.x;
		float v = world_pos.y;
		float cell_w = 3.0 + floor(COLOR.a * 3.0) * 0.4;
		float cell_h = 3.2;
		vec2 cell = vec2(floor(u / cell_w), floor(v / cell_h));
		vec2 f = vec2(fract(u / cell_w), fract(v / cell_h));
		float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.30, f.y) * step(f.y, 0.86);
		float frame = (step(0.15, f.x) * step(f.x, 0.85) * step(0.27, f.y) * step(f.y, 0.89)) - win;
		float band = 1.0 - smoothstep(0.0, 0.06, f.y);
		float shop = 0.0;
		vec3 wall = base * (0.88 + 0.12 * hash12(cell * 0.31 + seed));
		if (v < 4.2) {
			frame = 0.0;
			band = step(3.6, v) * step(v, 4.2);
			float shop_cell = hash12(vec2(cell.x, seed));
			if (COLOR.a > 0.45) {
				// Ladenzeile: große Schaufenster, nicht jedes beleuchtet
				win = step(0.06, f.x) * step(f.x, 0.94) * step(0.5, v) * step(v, 3.4);
				shop = win * step(0.3, shop_cell);
			} else {
				// Wohnhaus: Haustüren und kleine Fenster im Erdgeschoss
				float door = step(0.82, shop_cell) * step(0.3, f.x) * step(f.x, 0.7) * step(v, 2.6);
				float small_win = (1.0 - step(0.82, shop_cell)) * step(0.25, f.x) * step(f.x, 0.75) * step(1.2, v) * step(v, 2.6);
				win = small_win;
				wall = mix(wall, vec3(0.18, 0.14, 0.11), door);
			}
		}
		float rnd = hash12(cell + vec2(seed, seed * 1.7) + n.xz * 11.0);
		float lit = step(0.52, rnd);
		wall = mix(wall, wall * 0.72, band);
		wall = mix(wall, vec3(0.82, 0.82, 0.8), frame * 0.8);
		// Leichte Verschmutzung zum Boden hin
		wall *= mix(0.78, 1.0, smoothstep(0.0, 6.0, v));
		vec3 glass = glass_color * (0.8 + 0.4 * rnd);
		ALBEDO = mix(wall, glass, win);
		ROUGHNESS = mix(0.86, 0.22, win);
		METALLIC = mix(0.0, 0.15, win);
		SPECULAR = mix(0.35, 0.55, win);
		// Warme und kühle Wohnungslichter, unterschiedlich hell
		vec3 warm = window_glow * (0.45 + 0.6 * rnd);
		vec3 cool = vec3(0.6, 0.75, 1.0) * (0.35 + 0.4 * rnd);
		vec3 glow = mix(mix(warm, cool, step(0.85, rnd)), shop_glow * 0.9, shop);
		EMISSION = glow * win * mix(lit, shop, step(v, 4.2)) * night_factor * 1.5;
	}
}
