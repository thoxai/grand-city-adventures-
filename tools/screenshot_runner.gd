extends Node
## Rendert Referenz-Screenshots und misst Draw-Calls (benötigt echten Renderer).
## Start: godot --path . res://tools/screenshot_runner.tscn
## Ausgabe: docs/screenshots/*.png

const OUT := "res://docs/screenshots/"
var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	await _shot("01_hauptmenue")
	main.hud.hide_start_menu()
	main.start_new_game("alex")
	GameState.time_of_day = 9.5
	main.camera_rig.yaw = -PI * 0.5
	await _wait(1.5)
	await _shot("02_start_alex_tag")
	main.talk_to(main.npcs["rosa"])
	await _wait(0.5)
	await _shot("03_dialog")
	main.hud.finish_dialog()
	GameState.unlock_car("car_compact")
	GameState.unlock_car("car_sport")
	var car: Car = main.cars["car_sport"]
	car.reset_to(Vector3(0, 0, -60), 0.0)
	main.enter_car(car)
	car.use_external = true
	car.external_input = {"throttle": 1.0, "steer": 0.0}
	GameState.time_of_day = 17.8
	await _wait(2.5)
	await _shot("04_fahrt_abend")
	car.external_input = {"throttle": 0.0, "steer": 0.0, "handbrake": true}
	GameState.time_of_day = 22.0
	await _wait(0.2)
	car.reset_to(Vector3(-90, 0, 40), PI)
	await _wait(2.0)
	await _shot("05_nacht_stadt")
	main.exit_car(true)
	main.player.global_position = CityLayout.poi("fusebox_a")
	GameState.time_of_day = 13.0
	main.open_puzzle({"puzzle": "lights", "size": 3, "seed": 31, "scramble": 4})
	await _wait(0.6)
	await _shot("06_raetsel_sicherungen")
	main.hud.puzzle_panel._cancel()
	main.open_puzzle({"puzzle": "frequency", "seed": 5})
	await _wait(0.6)
	await _shot("07_raetsel_frequenz")
	main.hud.puzzle_panel._cancel()
	var c2: Car = main.cars["car_compact"]
	c2.reset_to(CityLayout.poi("garage_tuning"), PI / 2.0)
	main.enter_car(c2)
	c2.use_external = false
	await _wait(0.8)
	main.open_tuning()
	await _wait(0.6)
	await _shot("08_tuning")
	main.hud.tuning_panel._close()
	main.exit_car(true)
	main.player.global_position = Vector3(-45, 0, 22)
	main.camera_rig.yaw = 0.0
	GameState.time_of_day = 10.0
	await _wait(1.2)
	await _shot("09_rathausplatz")
	main.player.global_position = Vector3(-45, 0, -62)
	main.camera_rig.yaw = 0.0
	GameState.time_of_day = 7.2
	await _wait(1.2)
	await _shot("10_park_morgen")
	# Straßenverkehr an einer Kreuzung
	GameState.time_of_day = 11.0
	main.player.global_position = Vector3(10, 0, 12)
	main.camera_rig.yaw = PI * 0.25
	main.camera_rig.pitch = deg_to_rad(-18.0)
	await _wait(4.0)
	await _shot("11_verkehr_kreuzung")
	# Mit einem CityFlitzer im Verkehr mitfahren
	var flitzer: Car = main.traffic.driving_cars()[0]
	main.enter_car(flitzer)
	flitzer.use_external = true
	flitzer.reset_to(TrafficManager.lane_point(Vector2i(1, 2), Vector2i(1, 0), 20.0), TrafficManager.yaw_for(Vector2i(1, 0)))
	flitzer.external_input = {"throttle": 0.6, "steer": 0.0}
	await _wait(3.0)
	await _shot("12_flitzer_im_verkehr")
	GameState.time_of_day = 21.5
	await _wait(2.0)
	await _shot("13_verkehr_nacht")
	# Ampelkreuzung mit Bus und Passanten, Hupe mit Sprechblasen
	main.exit_car(true)
	GameState.time_of_day = 12.5
	main.player.global_position = Vector3(9.5, 0, 72)
	main.camera_rig.yaw = PI - 0.35
	main.camera_rig.pitch = deg_to_rad(-15.0)
	for npc in main.npcs.values():
		npc.snap_to_schedule(12.5)
	await _wait(5.0)
	await _shot("14_ampel_passanten")
	var parked: Car = main.traffic.cars[main.traffic.cars.size() - 2]
	main.enter_car(parked)
	var k := 0
	for npc in main.npcs.values():
		if npc.visible and not npc.is_home and k < 4:
			npc.global_position = parked.global_position + Vector3(-3.5 + k * 2.2, 0, 3.5)
			k += 1
	main.camera_rig.yaw = parked.rotation.y + PI * 0.8
	await _wait(0.5)
	main.honk()
	await _wait(0.4)
	await _shot("15_hupe_reaktion")
	# Taxi-Job: Fahrgast winkt am Straßenrand (Story-Mission vorher beenden, sonst pausieren Jobs)
	main.exit_car(true)
	main.missions.abort()
	await _wait(0.3)
	var taxi: Car = null
	for c in main.traffic.cars:
		if c.car_id == "city_taxi":
			taxi = c
			break
	main.enter_car(taxi)
	await _wait(0.5)
	var fare_pos: Vector3 = main.jobs.target
	var back := (fare_pos - Vector3(0, 0, 0))
	taxi.reset_to(fare_pos + Vector3(14, 0, 0) if CityLayout.is_on_road(fare_pos + Vector3(14, 0, -4)) else fare_pos + Vector3(0, 0, 14), 0.0)
	taxi.look_at(Vector3(fare_pos.x, taxi.global_position.y, fare_pos.z), Vector3.UP)
	main.camera_rig.set_target(taxi, true)
	await _wait(1.5)
	await _shot("16_taxi_fahrgast")
	main.exit_car(true)
	# Passanten am Zebrastreifen
	GameState.time_of_day = 12.0
	for npc in main.npcs.values():
		npc.snap_to_schedule(12.0)
	var shown := 0
	for npc in main.npcs.values():
		var e := NpcData.activity_for_hour(npc.data["schedule"], 12.0)
		if e.has("pair") and shown < 4:
			var path: Array = NpcData.pair_route({"pair": [Vector2i(1, 1), Vector2i(1, 2)], "start": 0})[0]
			npc._path = path
			npc._waits = NpcData.pair_route({"pair": [Vector2i(1, 1), Vector2i(1, 2)], "start": 0})[1]
			npc._path_index = 2 if shown % 2 == 0 else 6
			npc.global_position = path[npc._path_index] + Vector3(shown * 0.7, 0, 0)
			shown += 1
	# Ampel an Kreuzung (2,2) auf "Fußgänger frei" stellen (Autos Ost-West rot)
	for i in 300:
		if main.traffic_lights.state(Vector2i(2, 2), 0) == "red" and main.traffic_lights.state(Vector2i(2, 2), 1) == "green":
			break
		main.traffic_lights.time += 0.1
	main.player.global_position = Vector3(-16, 0, -13)
	main.camera_rig.global_position = main.player.global_position
	main.camera_rig.yaw = -2.6
	main.camera_rig.pitch = deg_to_rad(-16.0)
	await _wait(3.0)
	await _shot("17_zebrastreifen")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + file + ".png")
	print("Screenshot %s | FPS %d | Draw-Calls %d | Objekte %d | Primitive %d" % [file, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
