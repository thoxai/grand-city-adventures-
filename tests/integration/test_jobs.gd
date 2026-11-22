extends TestCase
## Nebenjobs (Taxi, Lieferdienst) und Passanten an Zebrastreifen.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	runner.add_child(main)
	await frames(2)
	main.hud.hide_start_menu()
	main.start_new_game("alex")
	GameState.time_of_day = 12.0
	await frames(2)


func after_each() -> void:
	main.queue_free()
	await frames(2)
	SaveSystem.delete_save()


func _taxi() -> Car:
	for c in main.traffic.cars:
		if c.car_id == "city_taxi":
			return c
	return null


func _arrive(car: Car, p: Vector3) -> void:
	car.reset_to(p + Vector3(0, 0, 0.5), car.rotation.y)
	await frames(3)


func test_taxi_job_full_ride() -> void:
	var taxi := _taxi()
	check(taxi != null, "Taxi im Verkehr")
	main.enter_car(taxi)
	await frames(3)
	var jobs: JobManager = main.jobs
	check_eq(jobs.kind, "taxi", "Taxi-Job startet automatisch")
	check_eq(jobs.phase, "pickup", "Fahrgast wartet")
	check(jobs.fare.visible, "Fahrgast sichtbar")
	check_eq(CityLayout.surface_at(jobs.target), "sidewalk", "Fahrgast steht auf dem Gehweg")
	check(main.hud._obj_title.text.begins_with("Taxi-Job"), "Ziel-Panel zeigt den Job")
	await _arrive(taxi, jobs.target)
	check_eq(jobs.phase, "ride", "Fahrgast eingestiegen")
	check(not jobs.fare.visible, "Fahrgast im Auto")
	check(jobs.timer > 20.0, "Zeitlimit für Trinkgeld")
	var money := GameState.money
	await _arrive(taxi, jobs.target)
	check(GameState.money >= money + 30 + 25, "Fahrpreis plus Trinkgeld (%d)" % (GameState.money - money))
	check_eq(GameState.jobs_done, 1, "Job gezählt")
	check_eq(jobs.phase, "pickup", "nächster Fahrgast wird gesucht")
	await tree().create_timer(3.5).timeout
	check(jobs.fare.visible, "neuer Fahrgast erscheint")


func test_taxi_job_ends_when_leaving() -> void:
	var taxi := _taxi()
	main.enter_car(taxi)
	await frames(3)
	main.exit_car(true)
	await frames(2)
	check(not main.jobs.is_active(), "Job beendet beim Aussteigen")
	check(not main.jobs.fare.visible, "Fahrgast weg")


func test_tip_rules() -> void:
	check_eq(JobManager.tip_for(10.0, 0), 25, "volles Trinkgeld")
	check_eq(JobManager.tip_for(10.0, 2), 9, "Abzug je Aufprall")
	check_eq(JobManager.tip_for(-1.0, 0), 0, "zu spät: kein Trinkgeld")
	check(JobManager.fare_price(300.0) > JobManager.fare_price(100.0), "längere Fahrt, mehr Geld")


func test_delivery_job() -> void:
	var car: Car = main.traffic.cars[main.traffic.cars.size() - 1]
	main.enter_car(car)
	car.reset_to(CityLayout.poi("depot") + Vector3(0, 0, -4), 0.0)
	await frames(3)
	check(main.jobs.can_start_delivery(car.global_position), "Depot erreichbar")
	check(main.hud._prompt.text.contains("Lieferjob"), "Hinweis am Depot")
	Input.action_press("interact")
	await frames(1)
	Input.action_release("interact")
	await frames(1)
	check_eq(main.jobs.kind, "delivery", "Lieferjob gestartet")
	check(main.current_car == car, "nicht ausgestiegen")
	check_eq(main.jobs.targets.size(), 3, "drei Pakete")
	for t in main.jobs.targets:
		check(main.city.is_point_free(t, 0.8), "Lieferadresse frei %s" % t)
	var money := GameState.money
	for i in 3:
		await _arrive(car, main.jobs.target)
	check(not main.jobs.is_active(), "Job abgeschlossen")
	check(GameState.money >= money + 3 * JobManager.PACKAGE_PAY, "Lohn für drei Pakete")


func test_delivery_timeout_pays_partial() -> void:
	var car: Car = main.traffic.cars[main.traffic.cars.size() - 1]
	main.enter_car(car)
	car.reset_to(CityLayout.poi("depot"), 0.0)
	await frames(2)
	main.jobs.start_delivery()
	await _arrive(car, main.jobs.target)
	var money := GameState.money
	main.jobs.timer = 0.01
	await frames(3)
	check(not main.jobs.is_active(), "Zeit abgelaufen")
	check_eq(main.jobs.delivered, 1, "ein Paket geliefert")
	check_eq(GameState.money, money, "kein Bonus nach Ablauf")


func test_no_jobs_during_story_mission() -> void:
	main.talk_to(main.npcs["rosa"])
	main.hud.finish_dialog()
	await frames(1)
	check(main.missions.is_active(), "Mission läuft")
	main.enter_car(_taxi())
	await frames(3)
	check(not main.jobs.is_active(), "kein Taxi-Job während der Mission")


func test_jobs_saved() -> void:
	GameState.record_job(80)
	var d := GameState.to_dict()
	GameState.reset_new_game("alex")
	GameState.from_dict(d)
	check_eq(GameState.jobs_done, 1, "Jobs gespeichert")
	check_eq(GameState.job_earnings, 80, "Verdienst gespeichert")


func test_pedestrians_cross_on_red_only() -> void:
	var crossers := []
	for id in main.npcs.keys():
		var npc: Npc = main.npcs[id]
		var entry := NpcData.activity_for_hour(npc.data["schedule"], 12.0)
		if entry.has("pair"):
			crossers.append(npc)
	check(crossers.size() >= 6, "mehrere Passanten mit Straßenüberquerung (%d)" % crossers.size())
	# Alle an ihren nächsten Bordstein-Wartepunkt setzen
	main.player.global_position = Vector3(0, 0, 0)
	main.camera_rig.global_position = Vector3(0, 1.5, 0)
	for npc in main.npcs.values():
		npc.snap_to_schedule(12.0)
	await frames(2)
	var cam: Vector3 = main.camera_rig.get_camera_position()
	var near := []
	for npc in crossers:
		var w0: int = npc._waits.keys()[0]
		if npc._path[w0].distance_to(cam) < Npc.ACTIVE_RANGE - 20.0:
			near.append(npc)
	crossers = near
	check(crossers.size() >= 3, "Passanten in Kameranähe (%d)" % crossers.size())
	for npc in crossers:
		var w: int = npc._waits.keys()[0]
		npc._path_index = w
		npc.global_position = npc._path[w]
	var crossed := 0
	var bad_start := 0
	var near_miss := 0
	var was_on_road := {}
	for f in 1800:
		await tree().physics_frame
		if f % 3 != 0:
			continue
		for npc in crossers:
			if npc.on_road and not was_on_road.get(npc, false):
				crossed += 1
				# Beim Betreten der Fahrbahn müssen die Autos dieser Straße Rot/Gelb haben
				var prev: int = posmod(npc._path_index - 1, npc._path.size())
				if npc._waits.has(prev):
					var w2: Array = npc._waits[prev]
					if main.traffic_lights.state(w2[0], w2[1]) == "green":
						bad_start += 1
			was_on_road[npc] = npc.on_road
			if npc.on_road:
				for car in main.traffic.driving_cars():
					if car.global_position.distance_to(npc.global_position) < 1.2:
						near_miss += 1
	print("      Passanten: %d Überquerungen, %d bei Grün für Autos, %d Beinahe-Kontakte" % [crossed, bad_start, near_miss])
	check(crossed >= crossers.size() * 0.8, "Passanten überqueren Straßen (%d von %d)" % [crossed, crossers.size()])
	check_eq(bad_start, 0, "nur wenn die Autos Rot haben")
	check_eq(near_miss, 0, "Autos halten für Fußgänger")


func test_crossing_routes_use_crosswalks() -> void:
	var entry := {"pair": [Vector2i(1, 1), Vector2i(1, 2)], "start": 0}
	var route := NpcData.pair_route(entry)
	var path: Array = route[0]
	var waits: Dictionary = route[1]
	check_eq(path.size(), 8, "8 Wegpunkte")
	check_eq(waits.size(), 2, "zwei Überquerungen")
	for i in waits.keys():
		var a: Vector3 = path[i]
		var b: Vector3 = path[(i + 1) % path.size()]
		check_eq(CityLayout.surface_at(a), "sidewalk", "Warten auf dem Gehweg")
		check_eq(CityLayout.surface_at(b), "sidewalk", "Ankunft auf dem Gehweg")
		check(CityLayout.is_on_road((a + b) * 0.5), "dazwischen liegt die Straße")
		var node: Vector2i = waits[i][0]
		var c := TrafficManager.node_pos(node)
		var d := absf(a.x - c.x) if absf(a.z - b.z) > 1.0 else absf(a.z - c.z)
		check(d > 8.0 and d < 11.5, "auf dem Zebrastreifen (%.1f m)" % d)
	var rotated := NpcData.pair_route({"pair": [Vector2i(1, 1), Vector2i(1, 2)], "start": 3})
	check(rotated[0][0].is_equal_approx(path[3]), "Startpunkt rotiert")
	check_eq(rotated[1].size(), 2, "Wartepunkte mitrotiert")
