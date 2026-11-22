extends TestCase
## Integrationstest der kompletten Hauptszene: Menü, Figur, Dialog, Fahrzeug,
## Missionen, Rätsel-UI, Tuning, Sammelobjekte, Touch, Speichern/Laden.

const SAVE := "user://savegame.json"
var main: Node


func before_each() -> void:
	SaveSystem.delete_save(SAVE)
	main = load("res://scenes/main.tscn").instantiate()
	runner.add_child(main)
	await frames(3)


func after_each() -> void:
	tree().paused = false
	main.queue_free()
	await frames(2)
	SaveSystem.delete_save(SAVE)


func _start(char_id: String = "alex") -> void:
	main.hud.hide_start_menu()
	main.start_new_game(char_id)
	await frames(2)


func _finish_dialog() -> void:
	check(main.hud.is_dialog_open(), "Dialog offen")
	main.hud.finish_dialog()
	await frames(1)


func _press_interact() -> void:
	Input.action_press("interact")
	await frames(1)
	Input.action_release("interact")
	await frames(1)


func test_starts_in_menu() -> void:
	check(main.hud.is_start_menu_open(), "Startmenü sichtbar")
	check(not main.game_running, "Spiel läuft noch nicht")
	check(main.camera_rig.cinematic, "Kamerafahrt im Menü")


func test_new_game_as_mia() -> void:
	await _start("mia")
	check_eq(main.player.character_id, "mia", "Spielfigur Mia")
	check_eq(main.npcs["partner"].display_name(), "Alex", "Alex als NPC")
	check(main.game_running, "Spiel läuft")
	check(not main.hud.touch.visible == false, "Touch-Steuerung sichtbar")
	check(main.player.global_position.distance_to(CityLayout.poi("home")) < 1.0, "Start zu Hause")


func test_walking_moves_player() -> void:
	await _start()
	var p0: Vector3 = main.player.global_position
	main.camera_rig.yaw = 0.0
	Input.action_press("move_forward")
	await physics_frames(60)
	Input.action_release("move_forward")
	var moved: Vector3 = main.player.global_position - p0
	check(moved.z < -1.5, "läuft vorwärts (-Z): %s" % moved)


func test_touch_joystick_sets_actions() -> void:
	await _start()
	var t: TouchControls = main.hud.touch
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(150, t.size.y - 150)
	t._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = down.position + Vector2(0, -80)
	t._input(drag)
	check(Input.get_action_strength("move_forward") > 0.8, "Joystick nach oben = vorwärts")
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	t._input(up)
	check_eq(Input.get_action_strength("move_forward"), 0.0, "Loslassen stoppt")
	# Knopf mit zweitem Finger (Multi-Touch)
	var b: TouchButton = t.get_button("jump", "foot")
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.pressed = true
	press.position = b.global_position + b.size * 0.5
	t._input(press)
	check(Input.is_action_pressed("jump"), "Sprung-Knopf")
	press.pressed = false
	t._input(press)
	check(not Input.is_action_pressed("jump"), "Sprung losgelassen")


func test_talk_starts_first_mission() -> void:
	await _start()
	var rosa: Npc = main.npcs["rosa"]
	main.player.global_position = rosa.global_position + Vector3(1.2, 0, 0)
	await frames(2)
	await _press_interact()
	check(main.hud.is_dialog_open(), "Dialog durch Aktion-Taste")
	check(main.missions.is_active(), "Mission gestartet")
	main.hud.finish_dialog()
	await frames(1)
	check_eq(main.missions.step_index, 1, "nächster Schritt nach Dialog")


func test_locked_car_cannot_be_entered() -> void:
	await _start()
	var car: Car = main.cars["car_sport"]
	main.enter_car(car)
	check(main.current_car == null, "gesperrtes Auto bleibt zu")
	GameState.unlock_car("car_sport")
	main.player.global_position = car.global_position + Vector3(2.5, 0, 0)
	await frames(2)
	await _press_interact()
	check(main.current_car == car, "Einsteigen per Aktion")
	check(not main.player.visible, "Figur sitzt im Auto")
	check_eq(main.hud.touch.mode, "car", "Touch im Fahrzeugmodus")
	await _press_interact()
	check(main.current_car == null, "Aussteigen")
	check(main.player.visible, "Figur wieder sichtbar")
	check(main.player.global_position.distance_to(car.global_position) < 5.0, "steht neben dem Auto")


func test_full_story_playthrough() -> void:
	await _start()
	var mm: MissionManager = main.missions
	for i in MissionData.count():
		var m: Dictionary = MissionData.MISSIONS[i]
		var guard := 0
		main.talk_to(main.npcs[m["giver"]])
		await _finish_dialog()
		while mm.is_active() and guard < 40:
			guard += 1
			var s := mm.current_step()
			match s["type"]:
				"talk":
					var npc: Npc = main.npcs[s["npc"]]
					main.player.global_position = npc.global_position + Vector3(1, 0, 0)
					main.talk_to(npc)
					await _finish_dialog()
				"goto":
					if main.current_car:
						main.current_car.reset_to(CityLayout.poi(s["poi"]), 0.0)
					else:
						main.player.global_position = CityLayout.poi(s["poi"])
					await frames(2)
				"enter_car":
					var cid: String = s["car"] if s["car"] != "" else "car_compact"
					main.enter_car(main.cars[cid])
					await frames(2)
				"drive":
					main.current_car.reset_to(CityLayout.poi(s["poi"]), 0.0)
					await frames(2)
				"race", "delivery":
					for cp in MissionData.checkpoints_for(s):
						main.current_car.reset_to(cp, 0.0)
						await frames(2)
				"puzzle":
					if main.current_car:
						main.exit_car(true)
					main.player.global_position = CityLayout.poi(s["poi"])
					await frames(2)
					check(not mm.interaction_at(main.player.global_position).is_empty(), "Rätsel erreichbar")
					main.open_puzzle(s)
					await frames(1)
					main.hud.puzzle_panel.debug_solve()
					await tree().create_timer(1.5).timeout
		check(GameState.is_mission_completed(m["id"]), "Mission %s abgeschlossen" % m["title"])
		check(main.hud.is_complete_panel_open(), "Abschluss-Panel bei %s" % m["title"])
		main.hud.close_complete_panel()
		if main.current_car:
			main.exit_car(true)
	check(mm.all_completed(), "Story komplett")
	check(GameState.is_car_unlocked("car_sport"), "Sportwagen frei")
	check(SaveSystem.has_save(), "Autosave nach Mission")


func test_collectible_pickup() -> void:
	await _start()
	var money := GameState.money
	main.player.global_position = CityLayout.COLLECTIBLES[1]
	await frames(3)
	check_eq(GameState.collected.size(), 1, "eingesammelt")
	check_eq(GameState.money, money + GameState.COLLECTIBLE_REWARD, "Belohnung")
	check(not main.collectible_nodes["cell_1"].visible, "ausgeblendet")


func test_tuning_purchase() -> void:
	await _start()
	GameState.unlock_car("car_compact")
	GameState.add_money(1000)
	var car: Car = main.cars["car_compact"]
	car.reset_to(CityLayout.poi("garage_tuning"), 0.0)
	main.enter_car(car)
	await frames(3)
	check(main.hud._tuning_btn.visible, "Tuning-Knopf in der Werkstatt")
	main.open_tuning()
	await frames(2)
	var top_before: float = car.stats["top_speed"]
	check(main.hud.tuning_panel.buy("engine"), "Motor gekauft")
	check(car.stats["top_speed"] > top_before, "Werte aktualisiert")
	check_eq(GameState.money, 1100 - 250, "Kosten abgezogen")
	GameState.money = 10
	check(not main.hud.tuning_panel.buy("tires"), "zu wenig Geld")
	main.hud.tuning_panel._close()
	await frames(1)
	check(not main.input_locked, "Eingabe wieder frei")


func test_save_and_load_world() -> void:
	await _start("mia")
	GameState.add_money(321)
	GameState.unlock_car("car_compact")
	main.cars["car_compact"].reset_to(Vector3(0, 0, 50), 1.0)
	main.player.global_position = Vector3(-90, 0, 30)
	GameState.time_of_day = 21.0
	check(main.save_game(), "gespeichert")
	main.start_new_game("alex")
	await frames(2)
	check(main.load_game(), "geladen")
	await frames(2)
	check_eq(GameState.character_id, "mia", "Figur")
	check_eq(GameState.money, 421, "Geld")
	check(main.player.global_position.distance_to(Vector3(-90, 0, 30)) < 0.5, "Spielerposition")
	check(main.cars["car_compact"].global_position.distance_to(Vector3(0, 0, 50)) < 0.5, "Autoposition")
	check_near(GameState.time_of_day, 21.0, 0.05, "Uhrzeit")


func test_pause_menu_pauses_game() -> void:
	await _start()
	main.hud.toggle_pause()
	check(tree().paused, "Spiel pausiert")
	check(not main.hud.touch.visible, "Touch aus im Menü")
	main.hud.toggle_pause()
	check(not tree().paused, "weiter")


func test_switch_character_and_quality() -> void:
	await _start("alex")
	main.switch_character()
	check_eq(GameState.character_id, "mia", "gewechselt")
	check_eq(main.player.character_id, "mia", "Modell gewechselt")
	for q in ["low", "medium", "high"]:
		GameState.quality = q
		main.apply_quality()
	check(main.day_night.shadows_enabled, "Schatten bei 'hoch'")
	GameState.quality = "low"
	main.apply_quality()
	check(not main.day_night.shadows_enabled, "keine Schatten bei 'niedrig'")


func test_npcs_follow_daily_routine() -> void:
	await _start()
	GameState.time_of_day = 3.0
	for npc in main.npcs.values():
		npc.snap_to_schedule(3.0)
	check(main.npcs["mehmet"].is_home, "Kioskbesitzer nachts zu Hause")
	check(not main.npcs["mehmet"].can_talk(), "nachts nicht ansprechbar")
	check(main.npcs["kenji"].can_talk(), "Story-Figur verfügbar")
	GameState.time_of_day = 10.0
	await physics_frames(3)
	check(not main.npcs["mehmet"].is_home, "Kiosk morgens offen")
	var tom: Npc = main.npcs["tom"]
	tom.snap_to_schedule(18.0)
	GameState.time_of_day = 18.0
	main.player.global_position = tom.global_position + Vector3(3, 0, 3)
	var p0 := tom.global_position
	await physics_frames(90)
	check(tom.global_position.distance_to(p0) > 1.5, "Jogger läuft seine Runde")


func test_npc_dodges_car() -> void:
	await _start()
	GameState.unlock_car("car_compact")
	var npc: Npc = main.npcs["kenji"]
	var car: Car = main.cars["car_compact"]
	var p := npc.global_position
	main.player.global_position = p + Vector3(6, 0, 0)
	car.reset_to(p + Vector3(0, 0, 8), 0.0)
	car.use_external = true
	car.external_input = {"throttle": 1.0}
	car.velocity = Vector3(0, 0, -12)
	car.speed = 12.0
	await physics_frames(20)
	check(Vector2(npc.global_position.x - p.x, npc.global_position.z - p.z).length() > 0.8, "NPC springt zur Seite")
	car.use_external = false
