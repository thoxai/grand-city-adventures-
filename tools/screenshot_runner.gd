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
