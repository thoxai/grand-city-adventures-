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
]


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			only = a.substr(8)
	var passed := 0
	var failed := 0
	var failed_names: Array = []
	var t0 := Time.get_ticks_msec()
	for path in SUITES:
		if only != "" and not path.contains(only):
			continue
		var script: GDScript = load(path)
		var suite: TestCase = script.new()
		suite.runner = self
		print("\n== %s" % path.get_file())
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			suite.failures = []
			await suite.before_each()
			await suite.call(mname)
			await suite.after_each()
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
