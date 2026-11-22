extends TestCase
## Missionslogik mit einer Attrappe der Spielwelt (ohne 3D-Szene).


class FakeNpc:
	extends Node3D
	var marker := false
	func set_mission_marker(v: bool) -> void:
		marker = v


class FakeWorld:
	extends Node3D
	var pos := Vector3.ZERO
	var in_car := false
	var car_id := ""
	var npcs := {}
	func get_player_position() -> Vector3:
		return pos
	func is_in_vehicle() -> bool:
		return in_car
	func current_car_id() -> String:
		return car_id if in_car else ""
	func get_npc(id: String):
		return npcs.get(id)


var world: FakeWorld
var mm: MissionManager


func before_each() -> void:
	GameState.reset_new_game("alex")
	world = FakeWorld.new()
	runner.add_child(world)
	for id in NpcData.NPCS.keys():
		var n := FakeNpc.new()
		world.add_child(n)
		world.npcs[id] = n
	mm = MissionManager.new()
	runner.add_child(mm)
	mm.set_process(false)
	mm.setup(world, null)


func after_each() -> void:
	mm.queue_free()
	world.queue_free()


func _talk(npc: String) -> bool:
	var lines := mm.lines_for_talk(npc)
	if lines.is_empty():
		return false
	mm.on_dialog_finished(npc)
	return true


func _goto(p: Vector3, car: bool = false) -> void:
	world.pos = p
	world.in_car = car
	mm.tick(0.1)


## Spielt eine Mission anhand ihrer Daten vollständig durch.
func _play_mission(index: int) -> void:
	var m: Dictionary = MissionData.MISSIONS[index]
	check(_talk(m["giver"]), "Mission %d startet beim Auftraggeber" % index)
	var guard := 0
	while mm.is_active() and mm.active_index == index and guard < 50:
		guard += 1
		var s := mm.current_step()
		match s["type"]:
			"talk":
				check(_talk(s["npc"]), "Gespräch mit %s" % s["npc"])
			"goto":
				_goto(CityLayout.poi(s["poi"]))
			"drive":
				world.car_id = "car_compact"
				_goto(CityLayout.poi(s["poi"]), true)
			"enter_car":
				world.car_id = s["car"] if s["car"] != "" else "car_compact"
				_goto(world.pos, true)
			"race", "delivery":
				for cp in MissionData.checkpoints_for(s):
					_goto(cp, true)
			"puzzle":
				check(not mm.interaction_at(CityLayout.poi(s["poi"])).is_empty(), "Rätsel am Ort verfügbar")
				mm.on_puzzle_solved()


func test_no_mission_active_at_start() -> void:
	check(not mm.is_active(), "keine aktive Mission")
	check_eq(mm.next_available_index(), 0, "erste Mission verfügbar")
	check_eq(mm.giver_npc(), "rosa", "Frau Lindner vergibt Mission 1")
	mm.tick(0.0)
	check(world.npcs["rosa"].marker, "Missionsmarker am Auftraggeber")


func test_wrong_npc_does_not_start_mission() -> void:
	check(mm.lines_for_talk("kenji").is_empty(), "Kenji startet Mission 1 nicht")
	check(not mm.is_active(), "weiterhin inaktiv")


func test_mission_one_step_by_step() -> void:
	check(_talk("rosa"), "Gespräch mit Rosa")
	check_eq(mm.step_index, 1, "Schritt 2: zur Werkstatt")
	_goto(CityLayout.poi("garage") + Vector3(30, 0, 0))
	check_eq(mm.step_index, 1, "zu weit weg")
	_goto(CityLayout.poi("garage"))
	check_eq(mm.step_index, 2, "Werkstatt erreicht")
	check(_talk("kenji"), "Gespräch mit Kenji")
	check(GameState.is_car_unlocked("car_compact"), "Auto freigeschaltet")
	world.car_id = "car_sport"
	_goto(world.pos, true)
	check_eq(mm.step_index, 3, "falsches Auto zählt nicht")
	world.car_id = "car_compact"
	_goto(world.pos, true)
	check_eq(mm.step_index, 4, "eingestiegen")
	_goto(CityLayout.poi("home"), false)
	check_eq(mm.step_index, 4, "zu Fuß zählt bei 'drive' nicht")
	_goto(CityLayout.poi("home"), true)
	check(not mm.is_active(), "Mission beendet")
	check(GameState.is_mission_completed("m1_neu_im_viertel"), "Mission 1 erledigt")
	check_eq(GameState.money, 100 + 150, "Belohnung erhalten")


func test_race_timeout_retries_from_start_line() -> void:
	GameState.complete_mission("m1_neu_im_viertel", 0)
	var failed := []
	mm.mission_failed.connect(func(i, r): failed.append(r))
	_talk("kenji")
	world.car_id = "car_compact"
	_goto(Vector3.ZERO, true)
	_goto(CityLayout.poi("race_start"), true)
	check_eq(mm.current_step()["type"], "race", "Rennen läuft")
	check(mm.timer > 70.0, "Timer gestartet")
	_goto(CityLayout.RACE_CHECKPOINTS[0], true)
	check_eq(mm.sub_index, 1, "Checkpoint 1")
	mm.tick(100.0)
	check_eq(failed.size(), 1, "Fehlschlag gemeldet")
	check(mm.is_active(), "Mission bleibt aktiv")
	check_eq(mm.current_step()["type"], "drive", "zurück zur Startlinie")


func test_full_story_completable() -> void:
	var completed := []
	mm.mission_completed.connect(func(i): completed.append(i))
	for i in MissionData.count():
		_play_mission(i)
	check_eq(completed, [0, 1, 2, 3, 4], "alle fünf Missionen in Reihenfolge")
	check(mm.all_completed(), "Story abgeschlossen")
	var expected := 100
	for m in MissionData.MISSIONS:
		expected += int(m["reward"])
	check_eq(GameState.money, expected, "Summe der Belohnungen")
	check(GameState.is_car_unlocked("car_sport"), "Sportwagen freigeschaltet")
	check(mm.lines_for_talk("rosa").is_empty(), "keine weitere Mission")


func test_puzzle_only_near_location() -> void:
	for id in ["m1_neu_im_viertel", "m2_hafenrunde"]:
		GameState.complete_mission(id, 0)
	_talk("brandt")
	check_eq(mm.current_step()["type"], "puzzle", "Rätselschritt")
	check(mm.interaction_at(Vector3.ZERO).is_empty(), "weit weg keine Interaktion")
	check(not mm.interaction_at(CityLayout.poi("fusebox_a")).is_empty(), "am Kasten Interaktion")


func test_objective_texts_filled() -> void:
	var texts := []
	mm.objective_changed.connect(func(t, x): texts.append(x))
	GameState.complete_mission("m1_neu_im_viertel", 0)
	GameState.complete_mission("m2_hafenrunde", 0)
	GameState.complete_mission("m3_kurzschluss", 0)
	GameState.complete_mission("m4_ersatzteile", 0)
	_talk("jonas")
	for i in 3:
		mm.advance()
	for t in texts:
		check(not str(t).contains("{"), "Platzhalter ersetzt: %s" % t)
