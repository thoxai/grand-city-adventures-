class_name CityLayout
extends RefCounted
## Reine Layout-Daten und Geometrie-Helfer fuer das Stadtviertel (400 x 400 m).
##
## Koordinaten: X = Ost, Z = Sued (Norden ist -Z), Y = oben.
## Strassen liegen in einem 90-m-Raster. Zwischen ihnen liegen 4 x 4 Blocks,
## jeder Block besitzt einen 4 m breiten Gehweg-Ring.

const HALF_SIZE := 200.0
const ROAD_CENTERS := [-180.0, -90.0, 0.0, 90.0, 180.0]
const ROAD_HALF_WIDTH := 7.0
const SIDEWALK_WIDTH := 4.0
const ROAD_EXTENT := 187.0  # Strassen enden am Aussenring

## BLOCK_TYPES[iz][ix]
const BLOCK_TYPES := [
	["industrial", "residential", "downtown", "downtown"],
	["residential", "park", "workshop", "downtown"],
	["residential", "plaza", "residential", "residential"],
	["industrial", "residential", "residential", "harbor"],
]

const DISTRICT_NAMES := {
	"industrial": "Gewerbehof",
	"residential": "Wohnviertel",
	"downtown": "City-Ring",
	"park": "Lindenpark",
	"workshop": "Kenjis Werkstatt",
	"plaza": "Rathausplatz",
	"harbor": "Alter Hafen",
}

## Benannte Orte (alle auf Strasse, Gehweg oder freier Flaeche).
const POIS := {
	"home": Vector3(-135, 0, 9.5),
	"garage": Vector3(22, 0, -45),
	"garage_tuning": Vector3(40, 0, -45),
	"car_compact_spawn": Vector3(26, 0, -36),
	"car_sport_spawn": Vector3(26, 0, -56),
	"kenji": Vector3(30, 0, -48),
	"jonas": Vector3(-36, 0, -33),
	"plaza": Vector3(-45, 0, 30),
	"brandt": Vector3(-58, 0, 28),
	"city_hall": Vector3(-45, 0, 46),
	"okafor": Vector3(-45, 0, 49),
	"fusebox_a": Vector3(60, 0, 9.0),
	"fusebox_b": Vector3(130, 0, -9.0),
	"race_start": Vector3(0, 0, -30),
	"radio_gate": Vector3(-135, 0, -99),
	"radio_tower": Vector3(-135, 0, -122),
	"delivery_1": Vector3(-90, 0, -150),
	"delivery_2": Vector3(135, 0, 180),
	"delivery_3": Vector3(-180, 0, 60),
	"kiosk": Vector3(-80, 0, 100),
	"cafe": Vector3(100, 0, -100),
	"harbor_pier": Vector3(135, 0, 135),
}

const RACE_CHECKPOINTS := [
	Vector3(0, 0, -86), Vector3(86, 0, -90), Vector3(90, 0, -4), Vector3(176, 0, 0),
	Vector3(180, 0, 86), Vector3(94, 0, 90), Vector3(4, 0, 90), Vector3(0, 0, 4),
	Vector3(0, 0, -40),
]

const COLLECTIBLES := [
	Vector3(-160, 0, -160), Vector3(-45, 0, -70), Vector3(45, 0, -135),
	Vector3(135, 0, -135), Vector3(135, 0, -45), Vector3(-135, 0, -45),
	Vector3(-75, 0, 70), Vector3(45, 0, 45), Vector3(135, 0, 45),
	Vector3(-135, 0, 135), Vector3(45, 0, 135), Vector3(165, 0, 165),
]


static func poi(poi_name: String) -> Vector3:
	return POIS.get(poi_name, Vector3.ZERO)


static func block_rect(ix: int, iz: int) -> Rect2:
	var x0: float = ROAD_CENTERS[ix] + ROAD_HALF_WIDTH
	var x1: float = ROAD_CENTERS[ix + 1] - ROAD_HALF_WIDTH
	var z0: float = ROAD_CENTERS[iz] + ROAD_HALF_WIDTH
	var z1: float = ROAD_CENTERS[iz + 1] - ROAD_HALF_WIDTH
	return Rect2(x0, z0, x1 - x0, z1 - z0)


static func lot_rect(ix: int, iz: int) -> Rect2:
	return block_rect(ix, iz).grow(-SIDEWALK_WIDTH)


static func block_type(ix: int, iz: int) -> String:
	return BLOCK_TYPES[iz][ix]


static func block_count() -> int:
	return ROAD_CENTERS.size() - 1


## Liefert den Block-Index (ix, iz) oder (-1, -1), wenn p auf keiner Blockflaeche liegt.
static func block_index_at(p: Vector3) -> Vector2i:
	for iz in block_count():
		for ix in block_count():
			if block_rect(ix, iz).has_point(Vector2(p.x, p.z)):
				return Vector2i(ix, iz)
	return Vector2i(-1, -1)


static func _dist_to_nearest_center(c: float) -> float:
	var best := INF
	for rc in ROAD_CENTERS:
		best = min(best, absf(c - rc))
	return best


static func is_on_road(p: Vector3) -> bool:
	var along_z := _dist_to_nearest_center(p.x) <= ROAD_HALF_WIDTH and absf(p.z) <= ROAD_EXTENT
	var along_x := _dist_to_nearest_center(p.z) <= ROAD_HALF_WIDTH and absf(p.x) <= ROAD_EXTENT
	return along_z or along_x


static func is_inside_bounds(p: Vector3) -> bool:
	return absf(p.x) < HALF_SIZE and absf(p.z) < HALF_SIZE


## "road", "sidewalk", "lot" oder "outside".
static func surface_at(p: Vector3) -> String:
	if not is_inside_bounds(p):
		return "outside"
	if is_on_road(p):
		return "road"
	var b := block_index_at(p)
	if b.x < 0:
		return "sidewalk"  # Aussenring jenseits der Randstrassen
	if lot_rect(b.x, b.y).has_point(Vector2(p.x, p.z)):
		return "lot"
	return "sidewalk"


static func intersections() -> Array:
	var out: Array = []
	for x in ROAD_CENTERS:
		for z in ROAD_CENTERS:
			out.append(Vector3(x, 0, z))
	return out


## Rundweg auf dem Gehweg eines Blocks (4 Ecken, 2 m vom Strassenrand).
static func sidewalk_loop(ix: int, iz: int, inset: float = 2.0) -> Array:
	var r := block_rect(ix, iz).grow(-inset)
	return [
		Vector3(r.position.x, 0, r.position.y),
		Vector3(r.end.x, 0, r.position.y),
		Vector3(r.end.x, 0, r.end.y),
		Vector3(r.position.x, 0, r.end.y),
	]


## Naechste Strassenmitte zu p (fuer Respawn von Fahrzeugen).
static func nearest_road_point(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for rc in ROAD_CENTERS:
		var a := Vector3(rc, 0, clampf(p.z, -ROAD_EXTENT + 7, ROAD_EXTENT - 7))
		var b := Vector3(clampf(p.x, -ROAD_EXTENT + 7, ROAD_EXTENT - 7), 0, rc)
		for c in [a, b]:
			var d := p.distance_to(c)
			if d < best_d:
				best_d = d
				best = c
	return best
