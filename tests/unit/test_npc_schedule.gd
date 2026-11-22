extends TestCase


func test_activity_wraps_midnight() -> void:
	var sched := [
		{"from": 0.0, "type": "home"},
		{"from": 7.0, "type": "idle", "at": Vector3.ONE},
		{"from": 21.0, "type": "home"},
	]
	check_eq(NpcData.activity_for_hour(sched, 3.0)["type"], "home", "nachts zu Hause")
	check_eq(NpcData.activity_for_hour(sched, 7.0)["type"], "idle", "ab 7 Uhr draußen")
	check_eq(NpcData.activity_for_hour(sched, 23.5)["type"], "home", "spätabends zu Hause")


func test_time_slots() -> void:
	check_eq(NpcData.time_slot(6.0), "morning", "Morgen")
	check_eq(NpcData.time_slot(13.0), "day", "Tag")
	check_eq(NpcData.time_slot(19.0), "evening", "Abend")
	check_eq(NpcData.time_slot(2.0), "night", "Nacht")


func test_story_npcs_always_available() -> void:
	for id in NpcData.NPCS.keys():
		var d: Dictionary = NpcData.NPCS[id]
		if not d.get("story", false):
			continue
		for h in range(0, 24):
			var a := NpcData.activity_for_hour(d["schedule"], float(h) + 0.5)
			check(a["type"] != "home", "%s um %d Uhr verfügbar" % [id, h])


func test_npcs_have_routines_and_dialogs() -> void:
	check(NpcData.NPCS.size() >= 10, "mindestens 10 NPCs")
	var ambient_home := 0
	for id in NpcData.NPCS.keys():
		var d: Dictionary = NpcData.NPCS[id]
		check(d["schedule"].size() >= 1, "%s hat Tagesablauf" % id)
		for slot in ["morning", "day", "evening"]:
			check(d["lines"].has(slot), "%s hat Dialog für %s" % [id, slot])
		if not d.get("story", false):
			var a := NpcData.activity_for_hour(d["schedule"], 3.0)
			if a["type"] == "home":
				ambient_home += 1
	check(ambient_home >= 5, "Nebenfiguren schlafen nachts")


func test_mission_givers_exist() -> void:
	for m in MissionData.MISSIONS:
		check(NpcData.NPCS.has(m["giver"]), "Auftraggeber %s existiert" % m["giver"])
		for s in m["steps"]:
			if s["type"] == "talk":
				check(NpcData.NPCS.has(s["npc"]), "Gesprächspartner %s existiert" % s["npc"])
			if s.has("poi"):
				check(CityLayout.POIS.has(s["poi"]), "Ort %s existiert" % s["poi"])
