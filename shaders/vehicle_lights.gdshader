// Scheinwerfer und Rückleuchten entfernter Verkehrsautos in EINER Oberfläche:
// Farbe kommt aus den Vertex-Farben (weiß vorne, rot hinten).
shader_type spatial;

uniform float energy = 0.4;

void fragment() {
	ALBEDO = COLOR.rgb * 0.6;
	EMISSION = COLOR.rgb * energy;
}
