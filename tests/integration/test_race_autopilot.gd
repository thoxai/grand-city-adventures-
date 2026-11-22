extends TestCase
## Ein einfacher KI-Fahrer fährt "Die Hafenrunde" mit echter Fahrphysik durch
## die generierte Stadt. Beweist, dass das Rennen in der Zeit schaffbar ist
## und die Strecke frei von Hindernissen ist.

var main: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	runner.add_child(main)
	await frames(2)
	main.hud.hide_start_menu()
	main.start_new_game("mia")
	await frames(2)


func after_each() -> void:
	main.queue_free()
	await frames(2)
	SaveSystem.delete_save()


static func autopilot(car: Car, target: Vector3, next_target: Vector3) -> Dictionary:
	var to := target - car.global_position
	to.y = 0.0
	var local := car.global_transform.basis.inverse() * to
	var angle := atan2(local.x, -local.z)
	var steer := clampf(angle * 2.5, -1.0, 1.0)
	var throttle := 1.0
	var dir_in := to.normalized()
	var dir_out := (next_target - target)
	dir_out.y = 0.0
	var turn := 0.0 if dir_out.length() < 1.0 else dir_in.angle_to(dir_out.normalized())
	var dist := to.length()
	if turn > 0.6 and dist < 18.0 + car.speed * 1.2 and car.speed > 12.0:
		throttle = -1.0
	elif absf(angle) > 0.7 and car.speed > 9.0:
		throttle = 0.0
	return {"throttle": throttle, "steer": steer}


func test_race_finishes_within_time_limit() -> void:
	var mm: MissionManager = main.missions
	GameState.complete_mission("m1_neu_im_viertel", 0)
	GameState.unlock_car("car_compact")
	main.talk_to(main.npcs["kenji"])
	main.hud.finish_dialog()
	await frames(1)
	var car: Car = main.cars["car_compact"]
	main.enter_car(car)
	await frames(2)
	car.reset_to(CityLayout.poi("race_start"), 0.0)
	await frames(2)
	check_eq(mm.current_step().get("type", ""), "race", "Rennen gestartet")
	var limit := float(mm.current_step()["time_limit"])
	var cps := CityLayout.RACE_CHECKPOINTS
	car.use_external = true
	var frames_used := 0
	var failed := []
	mm.mission_failed.connect(func(_i, r): failed.append(r))
	while mm.is_active() and mm.current_step().get("type", "") == "race" and frames_used < int(limit * 60.0) + 120:
		var i := mini(mm.sub_index, cps.size() - 1)
		var nxt: Vector3 = cps[mini(i + 1, cps.size() - 1)]
		car.external_input = autopilot(car, cps[i], nxt)
		await tree().physics_frame
		frames_used += 1
	car.use_external = false
	var seconds := frames_used / 60.0
	print("      KI-Fahrer: %.1f s von %.0f s, Checkpoints %d/%d" % [seconds, limit, mm.sub_index, cps.size()])
	check(failed.is_empty(), "kein Zeitlimit überschritten: %s" % [failed])
	check(GameState.is_mission_completed("m2_hafenrunde"), "Rennen gewonnen")
	check(seconds < limit * 0.95, "mit Puffer geschafft (%.1f s)" % seconds)


func test_delivery_route_is_drivable() -> void:
	# Lieferziele mit dem Sportwagen über echte Physik anfahren (ohne Missionsablauf)
	GameState.unlock_car("car_sport")
	var car: Car = main.cars["car_sport"]
	main.enter_car(car)
	await frames(2)
	car.reset_to(Vector3(0, 0, -30), 0.0)
	car.use_external = true
	var route := [Vector3(0, 0, -90), Vector3(-90, 0, -90), CityLayout.poi("delivery_1")]
	var idx := 0
	var frames_used := 0
	while idx < route.size() and frames_used < 60 * 60:
		var t: Vector3 = route[idx]
		car.external_input = autopilot(car, t, route[mini(idx + 1, route.size() - 1)])
		await tree().physics_frame
		frames_used += 1
		if Vector2(car.global_position.x - t.x, car.global_position.z - t.z).length() < 8.0:
			idx += 1
	car.use_external = false
	check_eq(idx, route.size(), "Lieferziel 1 per Physik erreicht (%.1f s)" % (frames_used / 60.0))
