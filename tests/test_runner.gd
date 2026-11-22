extends Node
## Führt alle Test-Suiten aus und beendet Godot mit Exit-Code 0/1.
## Start: godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## Optional nur eine Suite: ... -- --suite=test_puzzles

const SUITES := [
	"res://tests/unit/test_game_state.gd",
	"res://tests/unit/test_save_system.gd",
	"res://tests/unit/test_tuning.gd",
	"res://tests/unit/test_puzzles.gd",
	"res://tests/unit/test_city_layout.gd",
	"res://tests/unit/test_npc_schedule.gd",
	"res://tests/unit/test_missions.gd",
	"res://tests/integration/test_city_builder.gd",
	"res://tests/integration/test_car_physics.gd",
	"res://tests/integration/test_main_flow.gd",
	"res://tests/integration/test_race_autopilot.gd",
	"res://tests/integration/test_traffic.gd",
	"res://tests/integration/test_city_life.gd",
	"res://tests/integration/test_jobs.gd",
]


const MAX_TEST_FRAMES := 60 * 180


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			only = a.substr(8)
	var passed := 0
	var failed := 0
	var failed_names: Array = []
	var t0 := Time.get_ticks_msec()
	var error_logger = null
	if ClassDB.class_exists("Logger"):
		error_logger = load("res://tests/script_error_logger.gd").new()
		OS.add_logger(error_logger)
	for path in SUITES:
		if only != "" and not path.contains(only):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			# Parse-Fehler in der Test-Datei: als Fehlschlag melden statt hängen zu bleiben
			failed += 1
			failed_names.append("%s (lässt sich nicht laden)" % path.get_file())
			print("\n== %s\n  ✘ Datei lässt sich nicht laden (Syntaxfehler?)" % path.get_file())
			continue
		var suite: TestCase = script.new()
		suite.runner = self
		print("\n== %s" % path.get_file())
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			suite.failures = []
			if error_logger:
				error_logger.take()
			await suite.before_each()
			# Watchdog: bricht ein Test durch einen Laufzeitfehler ab, kehrt seine
			# Coroutine nie zurück. Dann nach MAX_TEST_FRAMES als Fehler werten.
			var state := {"done": false}
			var run := func() -> void:
				await suite.call(mname)
				state["done"] = true
			run.call()
			var waited := 0
			while not state["done"] and waited < MAX_TEST_FRAMES:
				await get_tree().process_frame
				waited += 1
			if not state["done"]:
				suite.failures.append("Zeitüberschreitung: Test nach %d Frames abgebrochen" % MAX_TEST_FRAMES)
			await suite.after_each()
			if error_logger:
				for e in error_logger.take():
					suite.failures.append("Skriptfehler: %s" % e)
			if suite.failures.is_empty():
				passed += 1
				print("  ✔ %s" % mname)
			else:
				failed += 1
				failed_names.append("%s::%s" % [path.get_file(), mname])
				print("  ✘ %s" % mname)
				for f in suite.failures:
					print("      - %s" % f)
	print("\n================================================")
	print("Ergebnis: %d bestanden, %d fehlgeschlagen (%.1f s)" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	for n in failed_names:
		print("  FEHLER: %s" % n)
	print("================================================")
	get_tree().quit(1 if failed > 0 else 0)
