class_name TuningData
extends RefCounted
## Fahrzeugdaten und Tuning-Regeln (rein datengetrieben, gut testbar).
## Alle Namen sind frei erfunden.

const CARS := {
	"car_compact": {
		"name": "Lumen K2",
		"desc": "Wendiger Kompaktwagen – ideal für enge Gassen.",
		"top_speed": 31.0,      # m/s (~112 km/h)
		"accel": 9.5,           # m/s^2
		"brake": 24.0,
		"reverse": 8.0,
		"drag": 3.0,
		"grip": 6.5,            # Querhaftung (hoeher = weniger Drift)
		"steer_rate": 2.0,      # rad/s bei vollem Lenkeinschlag
		"size": Vector3(1.8, 1.45, 4.0),
		"style": "hatch",
		"colors": [Color(0.85, 0.85, 0.82), Color(0.12, 0.35, 0.62), Color(0.75, 0.12, 0.1), Color(0.15, 0.15, 0.16), Color(0.95, 0.65, 0.1), Color(0.2, 0.5, 0.35)],
	},
	"car_sport": {
		"name": "Vireo RS",
		"desc": "Leichtes Sportcoupé – schnell, aber anspruchsvoll.",
		"top_speed": 40.0,
		"accel": 12.5,
		"brake": 27.0,
		"reverse": 9.0,
		"drag": 2.6,
		"grip": 7.2,
		"steer_rate": 2.1,
		"size": Vector3(1.95, 1.22, 4.5),
		"style": "coupe",
		"colors": [Color(0.8, 0.1, 0.08), Color(0.08, 0.08, 0.09), Color(0.9, 0.9, 0.92), Color(0.1, 0.55, 0.75), Color(0.55, 0.85, 0.2), Color(0.45, 0.2, 0.6)],
	},
	# --- CityFlitzer-Carsharing: fahren als Verkehr durch die Stadt, jederzeit nutzbar ---
	"city_hatch": {
		"name": "CityFlitzer Mini",
		"desc": "Carsharing-Kleinwagen – einsteigen und losfahren.",
		"shared": true,
		"top_speed": 27.0, "accel": 8.0, "brake": 22.0, "reverse": 7.0, "drag": 3.0,
		"grip": 6.5, "steer_rate": 2.0,
		"size": Vector3(1.75, 1.5, 3.8),
		"style": "hatch",
		"colors": [Color(0.92, 0.92, 0.9), Color(0.75, 0.77, 0.8), Color(0.15, 0.22, 0.38), Color(0.55, 0.12, 0.12), Color(0.85, 0.75, 0.35)],
	},
	"city_sedan": {
		"name": "CityFlitzer Komfort",
		"desc": "Carsharing-Limousine – ruhig und bequem.",
		"shared": true,
		"top_speed": 32.0, "accel": 8.5, "brake": 23.0, "reverse": 7.0, "drag": 2.8,
		"grip": 6.3, "steer_rate": 1.85,
		"size": Vector3(1.85, 1.45, 4.6),
		"style": "sedan",
		"colors": [Color(0.1, 0.1, 0.11), Color(0.5, 0.52, 0.55), Color(0.9, 0.9, 0.88), Color(0.2, 0.3, 0.25), Color(0.35, 0.2, 0.15)],
	},
	"city_van": {
		"name": "CityFlitzer Transporter",
		"desc": "Carsharing-Transporter – viel Platz, wenig Tempo.",
		"shared": true,
		"top_speed": 24.0, "accel": 6.5, "brake": 20.0, "reverse": 6.0, "drag": 3.2,
		"grip": 5.8, "steer_rate": 1.6,
		"size": Vector3(2.0, 2.1, 5.0),
		"style": "van",
		"colors": [Color(0.95, 0.95, 0.95), Color(0.85, 0.85, 0.8), Color(0.25, 0.4, 0.6)],
	},
	"city_taxi": {
		"name": "CityFlitzer Taxi",
		"desc": "Taxi im Carsharing – heute fährst du selbst.",
		"shared": true,
		"stripe": Color(0.1, 0.1, 0.1),
		"sign": Color(1.0, 0.95, 0.75),
		"top_speed": 31.0, "accel": 8.5, "brake": 23.0, "reverse": 7.0, "drag": 2.8,
		"grip": 6.4, "steer_rate": 1.9,
		"size": Vector3(1.85, 1.45, 4.6),
		"style": "sedan",
		"colors": [Color(0.98, 0.78, 0.12)],
	},
	# Stadtbus: fährt im Verkehr mit, ist aber nicht für Spieler nutzbar
	"city_bus": {
		"name": "Stadtbus Linie 7",
		"desc": "Der Bus durchs Hafenviertel.",
		"shared": true,
		"usable": false,
		"stripe": Color(0.95, 0.95, 0.95),
		"sign": Color(1.0, 0.6, 0.1),
		"top_speed": 16.0, "accel": 4.5, "brake": 16.0, "reverse": 4.0, "drag": 3.0,
		"grip": 6.0, "steer_rate": 1.5,
		"size": Vector3(2.5, 3.1, 10.5),
		"style": "bus",
		"colors": [Color(0.12, 0.35, 0.7), Color(0.75, 0.15, 0.12)],
	},
}

const SHARED_TYPES := ["city_hatch", "city_hatch", "city_sedan", "city_sedan", "city_van", "city_taxi", "city_hatch", "city_taxi"]
const BUS_COUNT := 2

const MAX_LEVEL := {"engine": 3, "tires": 3, "nitro": 2}
const COSTS := {
	"engine": [250, 450, 750],
	"tires": [150, 300, 500],
	"nitro": [400, 700],
}
const PAINT_COST := 60
const CATEGORY_NAMES := {"engine": "Motor", "tires": "Reifen & Fahrwerk", "nitro": "Nitro-System"}


static func base_spec(car_id: String) -> Dictionary:
	return CARS.get(car_id, CARS["car_compact"])


## Effektive Fahrwerte nach Tuning.
static func compute_stats(car_id: String, t: Dictionary) -> Dictionary:
	var b := base_spec(car_id)
	var e: int = clampi(int(t.get("engine", 0)), 0, MAX_LEVEL["engine"])
	var ti: int = clampi(int(t.get("tires", 0)), 0, MAX_LEVEL["tires"])
	var n: int = clampi(int(t.get("nitro", 0)), 0, MAX_LEVEL["nitro"])
	return {
		"top_speed": b["top_speed"] * (1.0 + 0.08 * e),
		"accel": b["accel"] * (1.0 + 0.12 * e),
		"brake": b["brake"] * (1.0 + 0.05 * ti),
		"reverse": b["reverse"],
		"drag": b["drag"],
		"grip": b["grip"] * (1.0 + 0.12 * ti),
		"steer_rate": b["steer_rate"] * (1.0 + 0.05 * ti),
		"nitro_capacity": [0.0, 3.0, 5.0][n],   # Sekunden Boost
		"nitro_boost": 1.0 + 0.18 * n,
	}


## Kosten der naechsten Stufe, -1 wenn bereits maximal.
static func upgrade_cost(category: String, current_level: int) -> int:
	if not COSTS.has(category):
		return -1
	if current_level >= MAX_LEVEL[category]:
		return -1
	return COSTS[category][current_level]


static func is_shared(car_id: String) -> bool:
	return bool(base_spec(car_id).get("shared", false))


static func paint_color(car_id: String, index: int) -> Color:
	var cols: Array = base_spec(car_id)["colors"]
	return cols[posmod(index, cols.size())]


static func kmh(ms: float) -> int:
	return int(round(ms * 3.6))
