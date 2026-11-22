extends TestCase
## Straßenverkehr und Carsharing: Spurgeometrie, Verkehrsfluss über 60 s,
## Anhalten vor Fußgängern, Einsteigen in jedes CityFlitzer-Auto.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	runner.add_child(main)
	await frames(2)
	main.hud.hide_start_menu()
	main.start_new_game("alex")
	await frames(2)


func after_each() -> void:
	main.queue_free()
	await frames(2)
	SaveSystem.delete_save()


func test_lane_geometry() -> void:
	var east := Vector2i(1, 0)
	var p := TrafficManager.lane_point(Vector2i(1, 2), east, 20.0)
	check(p.is_equal_approx(Vector3(-70, 0, 3.5)), "Ostwärts rechte Spur südlich der Mitte: %s" % p)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, TrafficManager.yaw_for(d))
		check(fwd.is_equal_approx(TrafficManager.dir3(d)), "Ausrichtung für %s" % d)
		check(CityLayout.is_on_road(TrafficManager.lane_point(Vector2i(2, 2), d, 45.0)), "Spur auf der Straße")
	for x in 5:
		for z in 5:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				for nd in TrafficManager.turn_options(Vector2i(x, z), d):
					check(TrafficManager.valid_node(Vector2i(x, z) + nd), "Abbiegen bleibt im Viertel")
	var c := TrafficManager.turn_control(Vector2i(2, 2), east, Vector2i(0, 1))
	check(c.is_equal_approx(Vector3(-3.5, 0, 3.5)), "Rechtskurve: Kontrollpunkt %s" % c)


func test_traffic_flows_for_a_minute() -> void:
	var tm: TrafficManager = main.traffic
	var driving := tm.driving_cars()
	check(driving.size() >= 8, "genug Verkehr (%d)" % driving.size())
	var spawns0 := 0
	for c in tm.cars:
		spawns0 += int(tm.agents[c].get("spawns", 0))
	var dist := {}
	var last := {}
	for c in driving:
		dist[c] = 0.0
		last[c] = c.global_position
	var on_road := 0
	var samples := 0
	main.player.global_position = Vector3(-45, 0, -45)  # Spieler im Park, nicht im Weg
	for f in 3600:
		await tree().physics_frame
		if f % 10 == 0:
			for c in driving:
				var step: float = c.global_position.distance_to(last[c])
				if step < 15.0:
					dist[c] += step
				last[c] = c.global_position
				samples += 1
				if CityLayout.is_on_road(c.global_position):
					on_road += 1
	var total := 0.0
	var slow := 0
	for c in driving:
		total += dist[c]
		if dist[c] < 100.0:
			slow += 1
	var avg := total / driving.size()
	var spawns1 := 0
	for c in tm.cars:
		spawns1 += int(tm.agents[c].get("spawns", 0))
	print("      Verkehr: Ø %.0f m pro Auto in 60 s, %.1f %% auf der Straße, %d Neueinsetzungen, %d langsame" % [avg, 100.0 * on_road / samples, spawns1 - spawns0, slow])
	check(avg > 300.0, "Autos fahren flüssig trotz Ampeln (Ø %.0f m)" % avg)
	check(float(on_road) / samples > 0.97, "bleiben auf der Straße")
	check(spawns1 - spawns0 <= 3, "kaum festgefahrene Autos (%d)" % (spawns1 - spawns0))
	check(slow <= 2, "fast keine dauerhaft stehenden Autos (%d)" % slow)


func test_traffic_stops_for_pedestrian() -> void:
	var tm: TrafficManager = main.traffic
	var car: Car = null
	for f in 600:
		for c in tm.driving_cars():
			var a: Dictionary = tm.agents[c]
			if a["phase"] != "drive" or a.get("bus", false):
				continue
			var t: float = (c.global_position - TrafficManager.node_pos(a["node"])).dot(TrafficManager.dir3(a["dir"]))
			if t > 10.0 and t < 40.0:
				car = c
				break
		if car:
			break
		await tree().physics_frame
	check(car != null, "fahrendes Auto gefunden")
	if car == null:
		return
	var fwd := -car.global_transform.basis.z
	var p0 := car.global_position
	var stand := p0 + fwd * 18.0
	stand.y = 0.0
	# Andere Autos aus dem Weg räumen, damit nur der Spieler das Hindernis ist
	for c in tm.cars:
		if c != car and c.global_position.distance_to(stand) < 30.0:
			c.reset_to(Vector3(0, -50, 0), 0.0)
			c.visible = false
	main.player.global_position = stand
	await physics_frames(300)
	var gap: float = car.global_position.distance_to(main.player.global_position)
	check(gap > 3.0, "hält Abstand zum Fußgänger (%.1f m)" % gap)
	check(absf(car.speed) < 1.0, "steht (%.1f m/s)" % car.speed)
	check(main.player.global_position.distance_to(stand) < 0.5, "Spieler wurde nicht weggeschoben")


func test_enter_parked_flitzer_at_start() -> void:
	var home := CityLayout.poi("home")
	var nearest: Car = null
	for c in main.traffic.cars:
		if not c.ai_driving and (nearest == null or c.global_position.distance_to(home) < nearest.global_position.distance_to(home)):
			nearest = c
	check(nearest != null and nearest.global_position.distance_to(home) < 20.0, "Carsharing-Auto direkt am Start")
	check(nearest.is_usable(), "ohne Freischaltung nutzbar")
	main.player.global_position = nearest.global_position + nearest.global_transform.basis.x * 2.2
	await frames(2)
	Input.action_press("interact")
	await frames(1)
	Input.action_release("interact")
	await frames(1)
	check(main.current_car == nearest, "eingestiegen")
	var p0 := nearest.global_position
	Input.action_press("move_forward")
	await physics_frames(120)
	Input.action_release("move_forward")
	check(nearest.global_position.distance_to(p0) > 10.0, "fährt mit Spielersteuerung")
	check(not nearest.ai_driving, "KI ist aus")
	main.open_tuning()
	check(not main.hud.tuning_panel.visible, "Carsharing nicht tunebar")
	nearest.reset_to(nearest.global_position, nearest.rotation.y)
	main.exit_car()
	check(main.current_car == null, "ausgestiegen")


func test_take_over_moving_car_and_return() -> void:
	var tm: TrafficManager = main.traffic
	await physics_frames(60)
	var car: Car = tm.driving_cars()[0]
	main.player.global_position = car.global_position + Vector3(0, 0, 0.1)
	main.enter_car(car)
	check(main.current_car == car, "fahrendes Auto übernommen")
	check(not car.ai_driving and absf(car.speed) < 0.1, "hält sofort an")
	main.exit_car(true)
	main.player.global_position = car.global_position + Vector3(150, 0, 0)
	main.camera_rig.global_position = main.player.global_position
	await physics_frames(150)
	check(car.ai_driving, "kehrt außer Sicht in den Verkehr zurück")


func test_density_follows_quality() -> void:
	GameState.quality = "low"
	main.apply_quality()
	check_eq(main.traffic.driving_cars().size(), TrafficManager.DENSITY["low"] + TuningData.BUS_COUNT, "wenig Verkehr bei 'niedrig'")
	GameState.quality = "medium"
	main.apply_quality()
	check_eq(main.traffic.driving_cars().size(), TrafficManager.DENSITY["medium"] + TuningData.BUS_COUNT, "Standard")
