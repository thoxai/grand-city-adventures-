extends TestCase
## Fahrphysik mit echter Physik-Engine auf einer flachen Teststrecke.

var arena: Node3D
var car: Car


func before_each() -> void:
	GameState.reset_new_game("alex")
	arena = Node3D.new()
	runner.add_child(arena)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(cs)
	arena.add_child(floor_body)
	car = load("res://scenes/vehicles/car.tscn").instantiate()
	car.car_id = "car_compact"
	arena.add_child(car)
	car.reset_to(Vector3.ZERO, 0.0)
	car.use_external = true
	await physics_frames(5)


func after_each() -> void:
	arena.queue_free()


func _drive(input: Dictionary, frames_count: int) -> void:
	car.external_input = input
	await physics_frames(frames_count)


func test_accelerates_forward() -> void:
	await _drive({"throttle": 1.0}, 180)
	check(car.speed > 15.0, "nach 3 s schneller als 15 m/s (%.1f)" % car.speed)
	check(car.speed <= car.stats["top_speed"] + 0.5, "nicht über Höchstgeschwindigkeit")
	check(car.global_position.z < -20.0, "fährt nach vorne (-Z): %s" % car.global_position)
	check(car.is_on_floor(), "bleibt am Boden")
	check_near(car.global_position.y, 0.0, 0.3, "Höhe stabil")


func test_reaches_top_speed_and_brakes() -> void:
	await _drive({"throttle": 1.0}, 900)
	check(car.speed > car.stats["top_speed"] * 0.9, "nahe Höchstgeschwindigkeit (%.1f)" % car.speed)
	await _drive({"throttle": -1.0}, 120)
	check(car.speed < 3.0, "Bremsen stoppt in 2 s (%.1f)" % car.speed)


func test_reverse() -> void:
	await _drive({"throttle": -1.0}, 150)
	check(car.speed < -3.0, "fährt rückwärts (%.1f)" % car.speed)
	check(car.speed >= -car.stats["reverse"] - 0.1, "Rückwärts begrenzt")


func test_steering_turns_right_and_left() -> void:
	await _drive({"throttle": 0.7}, 60)
	var yaw0 := car.rotation.y
	await _drive({"throttle": 0.7, "steer": 1.0}, 60)
	check(car.rotation.y < yaw0 - 0.3, "Rechts lenken dreht im Uhrzeigersinn")
	var yaw1 := car.rotation.y
	await _drive({"throttle": 0.7, "steer": -1.0}, 60)
	check(car.rotation.y > yaw1 + 0.3, "Links lenken dreht gegen den Uhrzeigersinn")


func test_no_steering_when_stopped() -> void:
	await _drive({"throttle": 0.0, "steer": 1.0}, 60)
	check_near(car.rotation.y, 0.0, 0.01, "im Stand keine Drehung")


func test_handbrake_drift() -> void:
	await _drive({"throttle": 1.0}, 150)
	await _drive({"throttle": 0.3, "steer": 1.0, "handbrake": true}, 30)
	check(absf(car.lateral_speed) > 1.0, "Handbremse erzeugt Driften (%.2f)" % car.lateral_speed)


func test_wall_collision_stops_car() -> void:
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(20, 4, 1)
	cs.shape = b
	wall.add_child(cs)
	wall.position = Vector3(0, 2, -40)
	arena.add_child(wall)
	var hits := []
	car.impact.connect(func(s): hits.append(s))
	await _drive({"throttle": 1.0}, 240)
	check(car.global_position.z > -40.0, "Wand wird nicht durchfahren")
	check(hits.size() > 0, "Aufprall gemeldet")
	check(absf(car.speed) < 5.0, "Auto steht an der Wand (%.1f)" % car.speed)


func test_engine_upgrade_is_faster() -> void:
	await _drive({"throttle": 1.0}, 240)
	var base_speed := car.speed
	car.reset_to(Vector3.ZERO, 0.0)
	GameState.set_tuning_value("car_compact", "engine", 3)
	car.apply_tuning()
	await physics_frames(2)
	await _drive({"throttle": 1.0}, 240)
	check(car.speed > base_speed + 2.0, "Motor-Upgrade wirkt (%.1f > %.1f)" % [car.speed, base_speed])


func test_nitro_boost() -> void:
	GameState.set_tuning_value("car_compact", "nitro", 1)
	car.apply_tuning()
	check(car.nitro_charge > 0.0, "Nitro geladen")
	await _drive({"throttle": 1.0}, 120)
	var before := car.speed
	await _drive({"throttle": 1.0, "nitro": true}, 60)
	check(car.boosting or car.nitro_charge < car.stats["nitro_capacity"], "Nitro verbraucht")
	check(car.speed > before + 3.0, "Nitro beschleunigt (%.1f > %.1f)" % [car.speed, before])
