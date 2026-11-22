extends TestCase
## Ampeln, Busse, Hupe und Passanten.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	runner.add_child(main)
	await frames(2)
	main.hud.hide_start_menu()
	main.start_new_game("mia")
	GameState.time_of_day = 12.0
	await frames(2)


func after_each() -> void:
	main.queue_free()
	await frames(2)
	SaveSystem.delete_save()


func test_light_phases_never_conflict() -> void:
	var n := Vector2i(2, 2)
	var green := [0, 0]
	var steps := 600
	for i in steps:
		var t := TrafficLights.CYCLE * i / steps
		var a := TrafficLights.state_at(n, 0, t)
		var b := TrafficLights.state_at(n, 1, t)
		check(not (a != "red" and b != "red"), "nie beide Achsen frei (t=%.1f: %s/%s)" % [t, a, b])
		if a == "green":
			green[0] += 1
		if b == "green":
			green[1] += 1
	check_near(float(green[0]) / steps, TrafficLights.GREEN_TIME / TrafficLights.CYCLE, 0.02, "Grünanteil Ost-West")
	check_near(float(green[1]) / steps, TrafficLights.GREEN_TIME / TrafficLights.CYCLE, 0.02, "Grünanteil Nord-Süd")
	check_eq(TrafficLights.state_at(Vector2i(0, 0), 0, 5.0), "green", "Ecken ohne Ampel")
	check_eq(main.traffic_lights.nodes.size(), 21, "21 Ampelkreuzungen")
	check_eq(main.traffic_lights.heads.size(), 4 * 9 + 3 * 12, "Ampelköpfe")


func test_poles_do_not_block_places() -> void:
	for pole in main.traffic_lights.pole_positions():
		check(not CityLayout.is_on_road(pole), "Mast nicht auf der Fahrbahn %s" % pole)
		for k in CityLayout.POIS.keys():
			check(Vector2(pole.x - CityLayout.poi(k).x, pole.z - CityLayout.poi(k).z).length() > 1.5, "Mast nicht auf Ort %s" % k)


func test_traffic_respects_red_lights() -> void:
	var tm: TrafficManager = main.traffic
	main.player.global_position = Vector3(-45, 0, -45)
	var red_waits := 0
	var red_runs := 0
	var prev_phase := {}
	for f in 2400:
		await tree().physics_frame
		for c in tm.driving_cars():
			var a: Dictionary = tm.agents[c]
			if a.get("at_red", false) and absf(c.speed) < 0.5:
				red_waits += 1
			if prev_phase.get(c, "") == "drive" and a["phase"] == "turn":
				var b: Vector2i = a["node"] + a["dir"]
				if main.traffic_lights.state(b, TrafficLights.axis_of(a["dir"])) == "red":
					red_runs += 1
			prev_phase[c] = a["phase"]
	print("      Ampeln: %d Warte-Frames an Rot, %d Rotlichtverstöße der KI" % [red_waits, red_runs])
	check(red_waits > 100, "KI-Autos warten an roten Ampeln")
	check_eq(red_runs, 0, "keine KI fährt bei Rot in die Kreuzung")


func test_buses_drive_but_are_not_usable() -> void:
	var buses := []
	for c in main.traffic.cars:
		if c.car_id == "city_bus":
			buses.append(c)
	check_eq(buses.size(), TuningData.BUS_COUNT, "Busse im Verkehr")
	check(buses[0].ai_driving, "Bus fährt")
	check(not buses[0].is_usable(), "Bus nicht nutzbar")
	main.enter_car(buses[0])
	check(main.current_car == null, "Einsteigen in Bus verhindert")
	var taxi := false
	for c in main.traffic.cars:
		if c.car_id == "city_taxi":
			taxi = true
	check(taxi, "Taxis im Verkehr")
	check(main.traffic.driving_cars().size() >= 28, "mehr Verkehr (%d)" % main.traffic.driving_cars().size())


func test_player_horn_makes_pedestrians_react() -> void:
	var car: Car = main.traffic.cars[main.traffic.cars.size() - 1]  # geparkter Flitzer
	main.enter_car(car)
	var npc: Npc = main.npcs["rosa"]
	npc.global_position = car.global_position - car.global_transform.basis.z * 6.0 + Vector3(0, 0, 0)
	main.player.global_position = car.global_position
	Input.action_press("horn")
	await frames(2)
	check(car.is_honking(), "Hupe ertönt")
	check(npc.is_saying(), "Passantin kommentiert")
	Input.action_release("horn")
	await frames(30)
	check(not car.is_honking(), "Hupe verstummt nach dem Loslassen")
	check(main.horn_count >= 1, "Hupen gezählt")
	check(Horn.stream().data.size() > 10000, "Hupton erzeugt")


func test_ai_honks_when_player_blocks() -> void:
	var tm: TrafficManager = main.traffic
	var ai: Car = null
	for c in tm.driving_cars():
		if tm.agents[c]["phase"] == "drive" and not tm.agents[c].get("bus", false):
			ai = c
			break
	var mine: Car = main.traffic.cars[main.traffic.cars.size() - 1]
	main.enter_car(mine)
	var fwd := -ai.global_transform.basis.z
	mine.reset_to(ai.global_position + fwd * 14.0, ai.rotation.y)
	for c in tm.cars:
		if c != ai and c != mine and c.global_position.distance_to(mine.global_position) < 25.0:
			c.reset_to(Vector3(0, -50, 0), 0.0)
			c.visible = false
	var honked := false
	for f in 300:
		await tree().physics_frame
		if ai.is_honking():
			honked = true
	check(honked, "KI hupt, wenn der Spieler im Weg steht")
	check(ai.global_position.distance_to(mine.global_position) > 4.0, "fährt nicht auf")


func test_red_light_warning_for_player() -> void:
	var tm: TrafficManager = main.traffic
	var mine: Car = tm.cars[tm.cars.size() - 1]
	main.enter_car(mine)
	# Kreuzung (2,2) so stellen, dass Ost-West gerade rot hat
	var lights: TrafficLights = main.traffic_lights
	for i in 400:
		if lights.state(Vector2i(2, 2), 0) == "red":
			break
		lights.time += 0.1
	mine.reset_to(Vector3(-20, 0, 3.5), TrafficManager.yaw_for(Vector2i(1, 0)))
	mine.use_external = true
	mine.external_input = {"throttle": 1.0}
	await physics_frames(150)
	mine.use_external = false
	check(tm.red_light_warnings >= 1, "Hinweis bei Rotlicht")


func test_many_pedestrians_with_routines() -> void:
	var all := NpcData.all_npcs()
	check(all.size() >= 40, "mindestens 40 NPCs (%d)" % all.size())
	check_eq(NpcData.generate_pedestrians(5, 1), NpcData.generate_pedestrians(5, 1), "deterministisch")
	check_eq(main.npcs.size(), all.size(), "alle NPCs in der Szene")
	var out_noon := 0
	var out_night := 0
	for id in all.keys():
		if not all[id].get("pedestrian", false):
			continue
		if NpcData.activity_for_hour(all[id]["schedule"], 12.0)["type"] != "home":
			out_noon += 1
		if NpcData.activity_for_hour(all[id]["schedule"], 3.0)["type"] != "home":
			out_night += 1
	check(out_noon >= 25, "mittags viele Passanten unterwegs (%d)" % out_noon)
	check(out_night <= 8, "nachts wenige (%d)" % out_night)
	var ped: Npc = main.npcs["ped_0"]
	check(ped.display_name() != "", "Passant hat Namen")
	check(NpcData.line_for("ped_0", 12.0, false) != "", "Passant hat Dialog")
