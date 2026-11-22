extends TestCase


func before_each() -> void:
	GameState.reset_new_game("alex")


func test_new_game_defaults() -> void:
	check_eq(GameState.character_id, "alex", "Figur")
	check_eq(GameState.money, 100, "Startgeld")
	check(GameState.completed_missions.is_empty(), "keine Missionen")
	check_near(GameState.time_of_day, 8.0, 0.001, "Startzeit")


func test_invalid_character_falls_back() -> void:
	GameState.reset_new_game("unbekannt")
	check_eq(GameState.character_id, "alex", "Fallback auf Alex")


func test_partner_is_other_character() -> void:
	check_eq(GameState.partner_id(), "mia", "Partner von Alex")
	GameState.reset_new_game("mia")
	check_eq(GameState.partner_id(), "alex", "Partner von Mia")
	check_eq(GameState.character_name(), "Mia", "Name")


func test_money_spend_and_overspend() -> void:
	GameState.add_money(50)
	check_eq(GameState.money, 150, "nach add")
	check(GameState.spend(120), "Ausgabe möglich")
	check_eq(GameState.money, 30, "nach spend")
	check(not GameState.spend(31), "Überziehen verhindert")
	check_eq(GameState.money, 30, "unverändert")
	check(not GameState.spend(-5), "negative Beträge abgelehnt")
	GameState.add_money(-1000)
	check_eq(GameState.money, 0, "Geld nie negativ")


func test_mission_reward_only_once() -> void:
	GameState.complete_mission("m_x", 200)
	GameState.complete_mission("m_x", 200)
	check_eq(GameState.money, 300, "Belohnung nur einmal")
	check(GameState.is_mission_completed("m_x"), "als erledigt markiert")


func test_collect_only_once() -> void:
	check(GameState.collect("cell_1"), "erstes Einsammeln")
	check(not GameState.collect("cell_1"), "kein zweites Mal")
	check_eq(GameState.money, 100 + GameState.COLLECTIBLE_REWARD, "Belohnung einmal")


func test_time_wraps_and_counts_days() -> void:
	GameState.time_of_day = 23.9
	GameState.advance_time(60.0 * 0.2 / GameState.time_scale * 60.0 / 60.0)
	check(GameState.time_of_day < 1.0, "Uhr läuft über Mitternacht")
	check_eq(GameState.day, 2, "Tag erhöht")
	GameState.time_of_day = 22.0
	check(GameState.is_night(), "22 Uhr ist Nacht")
	GameState.time_of_day = 12.0
	check(not GameState.is_night(), "12 Uhr ist Tag")
	check_eq(GameState.clock_string(), "12:00", "Uhrzeit-Text")


func test_dict_roundtrip() -> void:
	GameState.reset_new_game("mia")
	GameState.add_money(777)
	GameState.complete_mission("m1", 10)
	GameState.unlock_car("car_sport")
	GameState.set_tuning_value("car_sport", "engine", 2)
	GameState.collect("cell_3")
	GameState.time_of_day = 19.25
	var d := GameState.to_dict()
	var json := JSON.stringify(d)
	GameState.reset_new_game("alex")
	GameState.from_dict(JSON.parse_string(json))
	check_eq(GameState.character_id, "mia", "Figur")
	check_eq(GameState.money, 100 + 777 + 10 + GameState.COLLECTIBLE_REWARD, "Geld")
	check(GameState.is_mission_completed("m1"), "Mission")
	check(GameState.is_car_unlocked("car_sport"), "Auto")
	check_eq(int(GameState.get_tuning("car_sport")["engine"]), 2, "Tuning")
	check(GameState.collected.has("cell_3"), "Sammelobjekt")
	check_near(GameState.time_of_day, 19.25, 0.001, "Uhrzeit")


func test_from_dict_sanitizes() -> void:
	GameState.from_dict({"character_id": "hacker", "time_of_day": 99.0, "money": "12"})
	check_eq(GameState.character_id, "alex", "ungültige Figur")
	check(GameState.time_of_day < 24.0, "Uhrzeit begrenzt")
	check_eq(GameState.money, 12, "Zahl aus String")
