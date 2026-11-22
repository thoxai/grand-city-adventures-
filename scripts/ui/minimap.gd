class_name Minimap
extends Control
## Spielerzentrierte Minikarte (Norden oben). Zeigt Straßen, Gebäude, Parks,
## Fahrzeuge, das Missionsziel (am Rand als Pfeil, falls außerhalb) und den Spieler.

var city: CityBuilder
var world: Object          # liefert get_player_position(), get_player_heading(), cars
var missions: MissionManager
var view_range := 170.0     # Meter über die Kartenbreite
var _frame := 0
var _map_tex: ImageTexture
const MAP_EXTENT := 260.0   # Textur deckt -260..260 m ab (1 Pixel = 1 m)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % 2 == 0:
		queue_redraw()


## Zeichnet die statische Karte EINMAL in eine Textur (1 Draw-Call statt ~200).
func bake() -> void:
	var px := int(MAP_EXTENT * 2.0)
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.13, 0.14))
	var h := CityLayout.HALF_SIZE
	_fill(img, Rect2(-h, -h, h * 2, h * 2), Color(0.26, 0.26, 0.27))
	_fill(img, Rect2(-MAP_EXTENT, h + 2, MAP_EXTENT * 2, MAP_EXTENT), Color(0.1, 0.22, 0.3))
	var rw := CityLayout.ROAD_HALF_WIDTH
	var ext := CityLayout.ROAD_EXTENT
	for rc in CityLayout.ROAD_CENTERS:
		_fill(img, Rect2(rc - rw, -ext, rw * 2, ext * 2), Color(0.55, 0.55, 0.56))
		_fill(img, Rect2(-ext, rc - rw, ext * 2, rw * 2), Color(0.55, 0.55, 0.56))
	if city:
		for entry in city.minimap_rects:
			_fill(img, entry[0], entry[1])
	_map_tex = ImageTexture.create_from_image(img)


func _fill(img: Image, r: Rect2, col: Color) -> void:
	var rr := Rect2i(Vector2i((r.position + Vector2(MAP_EXTENT, MAP_EXTENT)).floor()), Vector2i(r.size.ceil()))
	rr = rr.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if rr.size.x > 0 and rr.size.y > 0:
		img.fill_rect(rr, col)


func _w2m(p: Vector2, center: Vector2, s: float) -> Vector2:
	return (p - center) * s + size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.14, 0.92))
	if world == null:
		return
	var pp: Vector3 = world.get_player_position()
	var center := Vector2(pp.x, pp.z)
	var s := size.x / view_range
	if _map_tex == null:
		bake()
	var tl := _w2m(Vector2(-MAP_EXTENT, -MAP_EXTENT), center, s)
	draw_texture_rect(_map_tex, Rect2(tl, Vector2(MAP_EXTENT, MAP_EXTENT) * 2.0 * s), false)
	# Fahrzeuge
	if world.has_method("get_cars"):
		for car in world.get_cars():
			if car == world.get("current_car"):
				continue
			var cp := _w2m(Vector2(car.global_position.x, car.global_position.z), center, s)
			if car.shared:
				# Carsharing: grün (frei nutzbar), fahrender Verkehr kleiner
				# Rechtecke statt Kreise: lassen sich von Godot zu einem Draw-Call bündeln
				var r := 2.5 if car.ai_driving else 4.0
				var col2 := Color(0.95, 0.8, 0.2) if car.car_id == "city_bus" else Color(0.3, 0.95, 0.5, 0.9)
				draw_rect(Rect2(cp - Vector2(r, r), Vector2(r, r) * 2.0), col2)
				continue
			var col := Color(0.35, 0.7, 1.0) if GameState.is_car_unlocked(car.car_id) else Color(0.6, 0.6, 0.65)
			draw_rect(Rect2(cp - Vector2(4, 4), Vector2(8, 8)), col)
	# Missionsziel
	if missions:
		var t = missions.target_position()
		if t != null:
			_draw_target(_w2m(Vector2(t.x, t.z), center, s), Color(1.0, 0.85, 0.2))
		var n = missions.next_checkpoint_position()
		if n != null:
			var np := _w2m(Vector2(n.x, n.z), center, s)
			if Rect2(Vector2.ZERO, size).has_point(np):
				draw_circle(np, 4.0, Color(1.0, 0.85, 0.2, 0.5))
	# Spieler-Pfeil
	var heading: float = world.get_player_heading()
	var c := size * 0.5
	var fwd := Vector2(0, -1).rotated(-heading)
	var right := Vector2(fwd.y * -1, fwd.x)
	var pts := PackedVector2Array([c + fwd * 11.0, c - fwd * 7.0 + right * 7.0, c - fwd * 3.5, c - fwd * 7.0 - right * 7.0])
	draw_colored_polygon(pts, Color(1, 1, 1))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.6), 1.5, true)
	# Rahmen + Nordpfeil
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 2.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x * 0.5 - 6, 18), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.8))


func _draw_target(p: Vector2, col: Color) -> void:
	var rect := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	if rect.has_point(p):
		draw_circle(p, 8.0, Color(0, 0, 0, 0.6))
		draw_circle(p, 6.0, col)
		return
	# Außerhalb: Pfeil am Rand
	var c := size * 0.5
	var d := (p - c).normalized()
	var k := minf(absf((rect.size.x * 0.5) / maxf(absf(d.x), 0.001)), absf((rect.size.y * 0.5) / maxf(absf(d.y), 0.001)))
	var e := c + d * k
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([e + d * 8.0, e - d * 6.0 + side * 7.0, e - d * 6.0 - side * 7.0]), col)
