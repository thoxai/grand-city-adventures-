class_name TrafficManager
extends Node
## Straßenverkehr: CityFlitzer-Carsharing-Autos fahren mit KI durch das Raster.
##
## - Rechtsverkehr: Spur 3,5 m rechts der Straßenmitte.
## - An jeder Kreuzung zufällig geradeaus, links oder rechts (nie aus dem Viertel).
## - Abbiegen entlang einer quadratischen Bézierkurve durch den Schnittpunkt der Spuren.
## - Abstandsregel: bremst vor Autos, dem Spielerauto und Fußgängern (auch dem Spieler)
##   in der eigenen Fahrspur. KI-Autos kollidieren physikalisch nicht untereinander;
##   blockieren sie sich länger als 4 s, ignorieren sie sich kurz (löst Patt-Situationen).
## - Festgefahrene Autos werden außerhalb des Sichtfelds neu eingesetzt.
## - Der Spieler kann jedes CityFlitzer-Auto übernehmen; verlässt er es und ist weit
##   genug weg, kehrt es in den Verkehr zurück.

const LANE_OFFSET := 3.5
const STOP_BACK := 13.0  # Fahrzeugmitte; Front steht an der Haltelinie vor dem Zebrastreifen
const SEGMENT := 90.0
const CRUISE_SPEED := 12.5
const TURN_SPEED := 6.5
const RESPAWN_MIN_DIST := 55.0
const RETURN_DIST := 75.0
const DENSITY := {"low": 16, "medium": 28, "high": 36}
const BUS_CRUISE := 9.5
## Geparkte Carsharing-Autos (Position, Blickrichtung, Typ) – eines direkt vor der Haustür.
## 6 m von der Straßenmitte: außerhalb der Fahrspur, der Verkehr fährt vorbei.
const PARKED := [
	[Vector3(-134, 0, 6.0), -PI / 2.0, "city_hatch"],
	[Vector3(-58, 0, 6.0), -PI / 2.0, "city_sedan"],
	[Vector3(6.0, 0, -66), 0.0, "city_hatch"],
]

var world: Node
var lights: TrafficLights
var cars: Array[Car] = []
var red_light_warnings := 0
var _last_red_node := Vector2i(-1, -1)
var agents: Dictionary = {}   # Car -> Zustand
var active := true
var rng := RandomNumberGenerator.new()
var _check_timer := 0.0


func setup(p_world: Node, count: int = 36) -> void:
	world = p_world
	rng.seed = 4242
	var CarScene: PackedScene = load("res://scenes/vehicles/car.tscn")
	var buses := TuningData.BUS_COUNT
	for i in count + buses + PARKED.size():
		var car: Car = CarScene.instantiate()
		var parked := i >= count + buses
		var is_bus := i >= count and not parked
		if parked:
			car.car_id = PARKED[i - count - buses][2]
		elif is_bus:
			car.car_id = "city_bus"
		else:
			car.car_id = TuningData.SHARED_TYPES[i % TuningData.SHARED_TYPES.size()]
		car.color_index = rng.randi_range(0, 9)
		car.name = "Flitzer_%d" % i
		world.add_child(car)
		cars.append(car)
		agents[car] = {"parked": parked, "used": false, "bus": is_bus}
	reset_all()


## Setzt alle Autos neu (Spielstart/Laden).
func reset_all() -> void:
	for car in cars:
		var a: Dictionary = agents[car]
		if a["parked"] and not a.get("joined", false):
			var spot: Array = PARKED[cars.find(car) - (cars.size() - PARKED.size())]
			car.set_ai(false)
			car.reset_to(spot[0], spot[1])
			a["used"] = false
		else:
			_spawn(car, true)
	set_density(DENSITY.get(GameState.quality, 20))


## Anzahl aktiver Verkehrsautos (Qualitätsstufe). Überzählige werden geparkt/ausgeblendet.
func set_density(n: int) -> void:
	var i := 0
	for car in cars:
		var a: Dictionary = agents[car]
		if a["parked"]:
			continue
		if a.get("bus", false):
			_set_car_enabled(car, active)
			continue
		var on := i < n and active
		_set_car_enabled(car, on)
		i += 1


func set_active(v: bool) -> void:
	active = v
	for car in cars:
		if not agents[car]["parked"]:
			_set_car_enabled(car, v)
	if v:
		set_density(DENSITY.get(GameState.quality, 20))


func _set_car_enabled(car: Car, on: bool) -> void:
	if world and world.get("current_car") == car:
		return
	car.visible = on
	car.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	car.collision_layer = 4 if on else 0
	agents[car]["disabled"] = not on


func driving_cars() -> Array:
	var out: Array = []
	for car in cars:
		if car.ai_driving and not agents[car].get("disabled", false):
			out.append(car)
	return out


# ------------------------------------------------------------------ Geometrie (statisch, testbar)

static func node_pos(n: Vector2i) -> Vector3:
	return Vector3(CityLayout.ROAD_CENTERS[n.x], 0, CityLayout.ROAD_CENTERS[n.y])


static func dir3(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0, d.y)


static func right_of(d: Vector2i) -> Vector2i:
	return Vector2i(-d.y, d.x)


static func left_of(d: Vector2i) -> Vector2i:
	return Vector2i(d.y, -d.x)


static func valid_node(n: Vector2i) -> bool:
	var m := CityLayout.ROAD_CENTERS.size() - 1
	return n.x >= 0 and n.y >= 0 and n.x <= m and n.y <= m


## Punkt auf der rechten Fahrspur des Segments ab Kreuzung a in Richtung d.
static func lane_point(a: Vector2i, d: Vector2i, along: float) -> Vector3:
	return node_pos(a) + dir3(d) * along + dir3(right_of(d)) * LANE_OFFSET


## Mögliche Richtungen an Kreuzung b, wenn man in Richtung d ankommt.
static func turn_options(b: Vector2i, d: Vector2i) -> Array:
	var out: Array = []
	for nd in [d, left_of(d), right_of(d)]:
		if valid_node(b + nd):
			out.append(nd)
	if out.is_empty():
		out.append(-d)
	return out


## Kontrollpunkt der Abbiegekurve: Schnittpunkt von Ein- und Ausfahrspur.
static func turn_control(b: Vector2i, d: Vector2i, nd: Vector2i) -> Vector3:
	if nd == -d:
		return node_pos(b)
	if nd == d:
		return node_pos(b) + dir3(right_of(d)) * LANE_OFFSET
	return node_pos(b) + dir3(right_of(d)) * LANE_OFFSET + dir3(right_of(nd)) * LANE_OFFSET


## Im Kreuzungsbereich (nur dort sind gegenseitige Blockaden möglich)?
static func in_junction(p: Vector3) -> bool:
	for rx in CityLayout.ROAD_CENTERS:
		for rz in CityLayout.ROAD_CENTERS:
			if absf(p.x - rx) < 13.0 and absf(p.z - rz) < 13.0:
				return true
	return false


static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u + p1 * 2.0 * u * t + p2 * t * t


static func yaw_for(d: Vector2i) -> float:
	# Vorwärts ist -Z: (-sin y, -cos y) = (d.x, d.y)
	return atan2(-float(d.x), -float(d.y))


# ------------------------------------------------------------------ Einsetzen

func _spawn(car: Car, initial: bool = false) -> bool:
	var cam := _camera_pos()
	for attempt in 30:
		var n := Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4))
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var d: Vector2i = dirs[rng.randi() % 4]
		if not valid_node(n + d):
			continue
		var along := rng.randf_range(STOP_BACK + 4.0, SEGMENT - STOP_BACK - 12.0)
		var p := lane_point(n, d, along)
		if not initial and p.distance_to(cam) < RESPAWN_MIN_DIST:
			continue
		if p.distance_to(_player_pos()) < 15.0:
			continue
		var crowded := false
		for other in cars:
			if other != car and other.visible and other.global_position.distance_to(p) < 14.0:
				crowded = true
				break
		if crowded:
			continue
		car.reset_to(p, yaw_for(d))
		car.set_ai(true)
		var a: Dictionary = agents[car]
		a["node"] = n
		a["dir"] = d
		a["next"] = _pick_next(n + d, d)
		a["phase"] = "drive"
		a["stuck"] = 0.0
		a["blocked"] = 0.0
		a["ignore_ai"] = 0.0
		a["offroad"] = 0.0
		a["used"] = false
		a["spawns"] = int(a.get("spawns", 0)) + 1
		return true
	return false


func _pick_next(b: Vector2i, d: Vector2i) -> Vector2i:
	var opts := turn_options(b, d)
	# Geradeaus etwas wahrscheinlicher
	if opts.has(d) and rng.randf() < 0.45:
		return d
	return opts[rng.randi() % opts.size()]


# ------------------------------------------------------------------ Übernahme durch Spieler

## Spieler steigt ein: KI aus, Auto steht sofort.
func take_over(car: Car) -> void:
	if not agents.has(car):
		return
	car.set_ai(false)
	car.velocity = Vector3.ZERO
	car.speed = 0.0
	agents[car]["used"] = true


func is_traffic_car(car: Car) -> bool:
	return agents.has(car)


# ------------------------------------------------------------------ KI

func _camera_pos() -> Vector3:
	if world and world.get("camera_rig"):
		return world.camera_rig.get_camera_position()
	return Vector3.ZERO


func _player_pos() -> Vector3:
	if world and world.has_method("get_player_position"):
		return world.get_player_position()
	return Vector3(9999, 0, 9999)


func _physics_process(delta: float) -> void:
	if not active or world == null:
		return
	var obstacles := _collect_obstacles()
	var night: bool = world.get("day_night") != null and world.day_night.night_factor > 0.4
	for car in cars:
		var a: Dictionary = agents[car]
		if a.get("disabled", false):
			continue
		car.headlights_on = night
		if car.ai_driving:
			_drive(car, a, obstacles, delta)
	_check_red_light()
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		_return_unused_cars()


## Hindernisse: [Knoten, Position, ist_KI (darf bei Patt ignoriert werden), ist_Spieler, halbe Länge]
func _collect_obstacles() -> Array:
	var obs: Array = []
	var mine = world.get("current_car")
	for car in cars:
		if car.visible and not agents[car].get("disabled", false):
			obs.append([car, car.global_position, car.ai_driving, car == mine, car.spec["size"].z * 0.5])
	if world.has_method("get_cars"):
		for c in world.get_cars():
			if not agents.has(c):
				obs.append([c, c.global_position, false, c == mine, c.spec["size"].z * 0.5])
	# Passanten auf der Fahrbahn (z. B. auf dem Zebrastreifen)
	if world.get("npcs"):
		for npc in world.npcs.values():
			if npc.visible and npc.on_road:
				obs.append([npc, npc.global_position, false, false, 0.4])
	var player = world.get("player")
	if player and player.visible:
		obs.append([player, player.global_position, false, true, 0.4])
	return obs


func _drive(car: Car, a: Dictionary, obstacles: Array, delta: float) -> void:
	var pos := car.global_position
	var n: Vector2i = a["node"]
	var d: Vector2i = a["dir"]
	var nd: Vector2i = a["next"]
	var b := n + d
	var cruise := BUS_CRUISE if a.get("bus", false) else CRUISE_SPEED
	var target_speed := cruise
	var aim: Vector3
	a["at_red"] = false
	if a["phase"] == "drive":
		var t := (pos - node_pos(n)).dot(dir3(d))
		var stop_at := SEGMENT - STOP_BACK
		aim = lane_point(n, d, clampf(t + 9.0, 0.0, stop_at + 2.0))
		if nd != d:
			target_speed = minf(cruise, TURN_SPEED + maxf(0.0, stop_at - t) * 0.3)
		# Ampel: bei Rot (oder Gelb mit genug Bremsweg) an der Haltelinie halten
		var to_stop := stop_at - t
		var go := true
		if lights:
			var light := lights.state(b, TrafficLights.axis_of(d))
			go = light == "green" or (light == "yellow" and to_stop < maxf(car.speed * 0.8, 3.0))
		if not go and to_stop > -1.0:
			target_speed = minf(target_speed, maxf(0.0, (to_stop - 1.0) * 0.7))
			if to_stop < 1.5:
				target_speed = 0.0
			a["at_red"] = to_stop < 25.0
		if go and t >= stop_at - 1.5:
			a["phase"] = "turn"
			a["p0"] = lane_point(n, d, stop_at)
			a["p1"] = turn_control(b, d, nd)
			a["p2"] = lane_point(b, nd, STOP_BACK)
			a["u"] = 0.0
	if a["phase"] == "turn":
		var p0: Vector3 = a["p0"]
		var p1: Vector3 = a["p1"]
		var p2: Vector3 = a["p2"]
		# Nächsten Kurvenparameter suchen und vorausschauend anpeilen
		var best_u: float = a["u"]
		var best_d := INF
		for k in 9:
			var u := clampf(float(a["u"]) + k * 0.05, 0.0, 1.0)
			var dd := bezier(p0, p1, p2, u).distance_squared_to(pos)
			if dd < best_d:
				best_d = dd
				best_u = u
		a["u"] = best_u
		aim = bezier(p0, p1, p2, minf(1.0, best_u + 0.3))
		if best_u > 0.9:
			aim = p2 + dir3(nd) * 6.0
		target_speed = TURN_SPEED if nd != d else cruise * 0.9
		if best_u >= 0.97 or pos.distance_to(p2) < 3.0:
			a["node"] = b
			a["dir"] = nd
			a["next"] = _pick_next(b + nd, nd)
			a["phase"] = "drive"

	# Abstandsregel
	var fwd := -car.global_transform.basis.z
	var right := car.global_transform.basis.x
	# Abstand wird zwischen den Fahrzeugenden gemessen (Busse sind 10,5 m lang)
	var my_half: float = car.spec["size"].z * 0.5
	var look := 5.0 + maxf(car.speed, 0.0) * 1.4
	var min_ahead := INF
	var only_ai := true
	var by_player := false
	a["ignore_ai"] = maxf(0.0, float(a["ignore_ai"]) - delta)
	for o in obstacles:
		if o[0] == car:
			continue
		if o[2] and a["ignore_ai"] > 0.0:
			continue
		var rel: Vector3 = o[1] - pos
		var center_ahead := rel.dot(fwd)
		if center_ahead < 0.5:
			continue
		var ahead: float = center_ahead - my_half - float(o[4])
		if ahead > look:
			continue
		if absf(rel.dot(right)) > 2.4:
			continue
		if ahead < min_ahead:
			min_ahead = ahead
			only_ai = o[2]
			by_player = o[3]
	var blocked := min_ahead < INF
	if blocked:
		target_speed = 0.0 if min_ahead < 2.5 else minf(target_speed, (min_ahead - 2.0) * 0.9)
		a["blocked"] = float(a["blocked"]) + delta
		if only_ai and a["blocked"] > 4.0 and not a["at_red"] and in_junction(pos):
			a["ignore_ai"] = 2.5
			a["blocked"] = 0.0
		# Vom Spieler blockiert: kurz hupen (höchstens alle 5 s)
		a["horn_cd"] = maxf(0.0, float(a.get("horn_cd", 0.0)) - delta)
		if by_player and a["blocked"] > 2.5 and a["horn_cd"] <= 0.0:
			car.honk(0.4)
			a["horn_cd"] = 5.0
	else:
		a["blocked"] = 0.0

	# Lenken und Gas
	var to := aim - pos
	to.y = 0.0
	var local := car.global_transform.basis.inverse() * to
	var angle := atan2(local.x, -local.z)
	var steer := clampf(angle * 2.2, -1.0, 1.0)
	var diff := target_speed - car.speed
	var throttle := clampf(diff * 0.35, -1.0, 1.0)
	var hold := target_speed < 0.1 and absf(car.speed) < 0.6
	car.external_input = {"throttle": 0.0 if hold else throttle, "steer": steer, "handbrake": hold}

	# Festgefahren oder von der Straße abgekommen => außerhalb der Sicht neu einsetzen
	if not blocked and not a["at_red"] and target_speed > 3.0 and absf(car.speed) < 1.0:
		a["stuck"] = float(a["stuck"]) + delta
	else:
		a["stuck"] = 0.0
	if not CityLayout.is_on_road(pos):
		a["offroad"] = float(a["offroad"]) + delta
	else:
		a["offroad"] = 0.0
	if a["stuck"] > 6.0 or a["offroad"] > 4.0 or pos.y < -2.0:
		if pos.distance_to(_camera_pos()) > 35.0 or pos.y < -2.0:
			_spawn(car)
		else:
			a["stuck"] = 3.0


## Vom Spieler benutzte und zurückgelassene Autos kehren in den Verkehr zurück,
## sobald sie außer Sichtweite sind.
func _return_unused_cars() -> void:
	var cam := _camera_pos()
	for car in cars:
		var a: Dictionary = agents[car]
		if car.ai_driving or not a.get("used", false) or world.get("current_car") == car:
			continue
		if car.global_position.distance_to(cam) > RETURN_DIST:
			a["parked"] = false
			a["joined"] = true
			_spawn(car)


## Hinweis (ohne Strafe), wenn der Spieler bei Rot in eine Kreuzung fährt.
func _check_red_light() -> void:
	var car = world.get("current_car")
	if lights == null or car == null or absf(car.speed) < 4.0:
		return
	var v: Vector3 = car.velocity
	var axis := 0 if absf(v.x) > absf(v.z) else 1
	for n in lights.nodes:
		var c := node_pos(n)
		var dist := Vector2(car.global_position.x - c.x, car.global_position.z - c.z).length()
		if dist < 7.0:
			if n != _last_red_node and lights.state(n, axis) == "red":
				_last_red_node = n
				red_light_warnings += 1
				if world.get("hud"):
					world.hud.toast("Rote Ampel! Bitte an der Haltelinie warten.", 2.5)
			return
	_last_red_node = Vector2i(-1, -1)
