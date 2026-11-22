class_name JobManager
extends Node
## Nebenjobs zwischen den Story-Missionen – eine wiederholbare Geldquelle.
##
## Taxi-Job:   startet automatisch im CityFlitzer-Taxi. Fahrgast am Straßenrand
##             abholen (anhalten), zum Ziel bringen (anhalten). Lohn nach Strecke,
##             Trinkgeld für schnelle und unfallfreie Fahrt.
## Lieferjob:  am Paket-Depot im Hafen mit einem beliebigen Auto starten, drei
##             Pakete der Reihe nach ausliefern, bevor die Zeit abläuft.
## Während einer Story-Mission gibt es keine Jobs (die Story hat Vorrang).

signal job_changed

const STOP_SPEED := 2.5
const PICKUP_RADIUS := 7.0
const DROP_RADIUS := 8.0
const DEPOT_RADIUS := 9.0
const DELIVERY_COUNT := 3
const PACKAGE_PAY := 60

var world: Node
var kind := ""            # "", "taxi", "delivery"
var phase := ""           # taxi: "pickup" / "ride"; delivery: "deliver"
var target := Vector3.ZERO
var targets: Array = []
var timer := -1.0
var ride_start_time := 0.0
var ride_distance := 0.0
var impacts := 0
var delivered := 0
var rng := RandomNumberGenerator.new()
var fare: HumanoidModel
var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _next_fare_in := 0.0
var _taxi_car: Car


func setup(p_world: Node) -> void:
	world = p_world
	rng.seed = 99
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.3, 0.95, 0.5, 0.35)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.4
	cm.height = 30.0
	cm.cap_top = false
	cm.cap_bottom = false
	_beam.mesh = cm
	_beam.material_override = mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.0
	tm.outer_radius = 3.4
	_ring.mesh = tm
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	fare = HumanoidModel.new()
	fare.name = "TaxiFare"
	add_child(fare)
	fare.build(NpcData.generate_pedestrians(1, 4711)["ped_0"]["look"])
	fare.waving = true
	_hide_marker()
	fare.visible = false
	_build_depot()


func _build_depot() -> void:
	var p := CityLayout.poi("depot")
	var crate := MeshFactory.material(Color(0.62, 0.45, 0.25), 0.9)
	for i in 3:
		MeshFactory.box(Vector3(0.9, 0.7, 0.9), crate, p + Vector3(-2.5 + i * 1.0, 0.35, 1.6), self)
	var l := Label3D.new()
	l.text = "PAKET-DEPOT"
	l.font_size = 72
	l.pixel_size = 0.01
	l.outline_size = 8
	l.modulate = Color(1.0, 0.8, 0.3)
	l.position = p + Vector3(0, 3.2, 1.8)
	add_child(l)


func is_active() -> bool:
	return kind != ""


## Darf gerade ein Job laufen? (keine Story-Mission aktiv)
func jobs_allowed() -> bool:
	return world != null and not world.missions.is_active()


# ------------------------------------------------------------------ Orte

## Zufälliger Punkt am Straßenrand (Gehweg direkt neben der Fahrspur).
func random_curb_point(from: Vector3, min_d: float, max_d: float) -> Vector3:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for attempt in 60:
		var n := Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4))
		var d: Vector2i = dirs[rng.randi() % 4]
		if not TrafficManager.valid_node(n + d):
			continue
		var along := rng.randf_range(25.0, 65.0)
		var p := TrafficManager.lane_point(n, d, along) + TrafficManager.dir3(TrafficManager.right_of(d)) * 5.0
		var dist := Vector2(p.x - from.x, p.z - from.z).length()
		if dist >= min_d and dist <= max_d and _curb_free(p):
			return p
	return CityLayout.poi("race_start")


func _curb_free(p: Vector3) -> bool:
	if world and world.get("city"):
		return world.city.is_point_free(p, 1.0)
	return true


# ------------------------------------------------------------------ Taxi

func start_taxi(car: Car) -> void:
	if not jobs_allowed() or is_active():
		return
	kind = "taxi"
	_taxi_car = car
	impacts = 0
	_spawn_fare()
	world.hud.toast("Taxi-Job! Ein Fahrgast wartet an der grünen Markierung.", 3.5)
	_update_objective()
	job_changed.emit()


func _spawn_fare() -> void:
	phase = "pickup"
	target = random_curb_point(world.get_player_position(), 50.0, 200.0)
	fare.global_position = target
	fare.visible = true
	timer = -1.0
	world.hud.set_timer(-1.0)
	_show_marker(target)


func _taxi_tick(delta: float) -> void:
	var car: Car = world.current_car
	if car != _taxi_car:
		cancel("Taxi-Job beendet." if phase == "pickup" else "Der Fahrgast ist ausgestiegen – kein Fahrpreis.")
		return
	if _next_fare_in > 0.0:
		_next_fare_in -= delta
		if _next_fare_in <= 0.0:
			_spawn_fare()
			_update_objective()
		return
	var pos := car.global_position
	var stopped := absf(car.speed) < STOP_SPEED
	if phase == "pickup":
		if fare.visible:
			fare.look_at(Vector3(pos.x, fare.global_position.y, pos.z) + Vector3(0.01, 0, 0), Vector3.UP)
			fare.animate(0.0, delta)
		if _flat(pos, target) < PICKUP_RADIUS and stopped:
			fare.visible = false
			phase = "ride"
			var start := target
			target = random_curb_point(start, 140.0, 320.0)
			ride_distance = _route_length(start, target)
			ride_start_time = 0.0
			timer = ride_distance / 9.0 + 20.0
			impacts = 0
			_show_marker(target)
			world.hud.toast("Fahrgast eingestiegen: „Bitte so schnell wie möglich – aber sicher!“", 3.0)
			_update_objective()
	elif phase == "ride":
		timer -= delta
		world.hud.set_timer(maxf(timer, 0.0))
		if _flat(pos, target) < DROP_RADIUS and stopped:
			var pay := fare_price(ride_distance)
			var tip := tip_for(timer, impacts)
			GameState.add_money(pay + tip)
			GameState.record_job(pay + tip)
			world.hud.toast("Fahrt bezahlt: %d € + %d € Trinkgeld" % [pay, tip] if tip > 0 else "Fahrt bezahlt: %d € (kein Trinkgeld)" % pay, 3.5)
			_hide_marker()
			world.hud.set_timer(-1.0)
			timer = -1.0
			_next_fare_in = 3.0
			phase = "pickup"
			_update_objective("Nächster Fahrgast wird gesucht ...")


static func fare_price(distance: float) -> int:
	return 30 + int(distance * 0.22)


## Trinkgeld: 25 € bei Ankunft in der Zeit, minus 8 € je Aufprall.
static func tip_for(time_left: float, crash_count: int) -> int:
	if time_left <= 0.0:
		return 0
	return maxi(0, 25 - crash_count * 8)


static func _route_length(a: Vector3, b: Vector3) -> float:
	# Straßenraster: Manhattan-Distanz ist eine gute Schätzung der Fahrstrecke
	return absf(a.x - b.x) + absf(a.z - b.z)


func on_impact(strength: float) -> void:
	if kind == "taxi" and phase == "ride" and strength > 4.0:
		impacts += 1
		world.hud.toast("Fahrgast: „Hey, vorsichtig!“", 1.5)


# ------------------------------------------------------------------ Lieferjob

func can_start_delivery(pos: Vector3) -> bool:
	return jobs_allowed() and not is_active() and world.current_car != null \
		and world.current_car.is_usable() and _flat(pos, CityLayout.poi("depot")) < DEPOT_RADIUS


func start_delivery() -> void:
	if not can_start_delivery(world.get_player_position()):
		return
	kind = "delivery"
	phase = "deliver"
	delivered = 0
	targets = []
	var from := CityLayout.poi("depot")
	var total := 0.0
	for i in DELIVERY_COUNT:
		var p := random_curb_point(from, 70.0, 220.0)
		total += _route_length(from, p)
		targets.append(p)
		from = p
	timer = total / 10.0 + 30.0
	target = targets[0]
	_show_marker(target)
	world.hud.toast("Lieferjob: %d Pakete, %d Sekunden. Los geht's!" % [DELIVERY_COUNT, int(timer)], 3.5)
	_update_objective()
	job_changed.emit()


func _delivery_tick(delta: float) -> void:
	timer -= delta
	world.hud.set_timer(maxf(timer, 0.0))
	var pos: Vector3 = world.get_player_position()
	if _flat(pos, target) < DROP_RADIUS:
		var car: Car = world.current_car
		if car == null or absf(car.speed) < STOP_SPEED:
			delivered += 1
			GameState.add_money(PACKAGE_PAY)
			GameState.record_job(PACKAGE_PAY)
			if delivered >= DELIVERY_COUNT:
				var bonus := int(maxf(timer, 0.0)) * 2
				GameState.add_money(bonus)
				GameState.record_job(bonus)
				world.hud.toast("Alle Pakete geliefert! +%d € Zeitbonus" % bonus, 3.5)
				_finish()
				return
			target = targets[delivered]
			_show_marker(target)
			world.hud.toast("Paket %d/%d abgegeben: +%d €" % [delivered, DELIVERY_COUNT, PACKAGE_PAY], 2.0)
			_update_objective()
	if timer <= 0.0:
		world.hud.toast("Zeit abgelaufen – %d von %d Paketen geliefert." % [delivered, DELIVERY_COUNT], 3.5)
		_finish()


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	if world == null or not world.game_running:
		return
	if is_active() and not jobs_allowed():
		cancel("Nebenjob pausiert – die Story-Mission geht vor.")
		return
	match kind:
		"taxi":
			_taxi_tick(delta)
		"delivery":
			_delivery_tick(delta)
		_:
			var car = world.current_car
			if car and car.car_id == "city_taxi" and jobs_allowed():
				start_taxi(car)
	if _beam.visible:
		_ring.rotate_y(delta)


func cancel(reason: String = "") -> void:
	if reason != "":
		world.hud.toast(reason, 3.0)
	_finish()


func _finish() -> void:
	kind = ""
	phase = ""
	timer = -1.0
	_taxi_car = null
	_next_fare_in = 0.0
	fare.visible = false
	_hide_marker()
	world.hud.set_timer(-1.0)
	world.missions.refresh_objective()
	job_changed.emit()


func target_position() -> Variant:
	return target if is_active() and _beam.visible else null


func _update_objective(extra: String = "") -> void:
	match kind:
		"taxi":
			var txt := "Hole den Fahrgast an der grünen Markierung ab (anhalten)." if phase == "pickup" else "Bring den Fahrgast ans Ziel und halte dort an."
			world.hud.set_objective("Taxi-Job · %d Fahrten" % GameState.jobs_done, extra if extra != "" else txt)
		"delivery":
			world.hud.set_objective("Lieferjob", "Paket %d/%d – fahre zur grünen Markierung." % [delivered + 1, DELIVERY_COUNT])


func _show_marker(p: Vector3) -> void:
	_beam.visible = true
	_ring.visible = true
	_beam.global_position = p + Vector3(0, 15.0, 0)
	_ring.global_position = p + Vector3(0, 0.3, 0)


func _hide_marker() -> void:
	_beam.visible = false
	_ring.visible = false


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
