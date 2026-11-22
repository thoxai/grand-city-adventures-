extends TestCase

const PATH := "user://test_savegame.json"


func before_each() -> void:
	GameState.reset_new_game("alex")
	SaveSystem.delete_save(PATH)


func after_each() -> void:
	SaveSystem.delete_save(PATH)
	SaveSystem.world_snapshot_provider = Callable()


func test_save_and_load_roundtrip() -> void:
	GameState.add_money(400)
	GameState.complete_mission("m1_neu_im_viertel", 0)
	SaveSystem.world_snapshot_provider = func(): return {"player_pos": SaveSystem.vec_to_array(Vector3(1.5, 0, -2.25))}
	check(SaveSystem.save_game(PATH), "Speichern erfolgreich")
	check(SaveSystem.has_save(PATH), "Datei existiert")
	GameState.reset_new_game("mia")
	var world := SaveSystem.load_game(PATH)
	check_eq(GameState.character_id, "alex", "Figur geladen")
	check_eq(GameState.money, 500, "Geld geladen")
	check(GameState.is_mission_completed("m1_neu_im_viertel"), "Missionen geladen")
	var p := SaveSystem.array_to_vec(world.get("player_pos"))
	check(p.is_equal_approx(Vector3(1.5, 0, -2.25)), "Position geladen: %s" % p)


func test_missing_save() -> void:
	check(not SaveSystem.has_save(PATH), "keine Datei")
	check(SaveSystem.load_game(PATH).is_empty(), "leeres Ergebnis")


func test_corrupted_save_does_not_change_state() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ kaputt ")
	f.close()
	GameState.add_money(5)
	var r := SaveSystem.load_game(PATH)
	check(r.is_empty(), "beschädigt => leer")
	check_eq(GameState.money, 105, "Zustand unverändert")


func test_newer_version_rejected() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "state": {"money": 1}}))
	f.close()
	check(SaveSystem.read_save(PATH).is_empty(), "neuere Version abgelehnt")


func test_vector_helpers() -> void:
	check(SaveSystem.array_to_vec([1, 2, 3]).is_equal_approx(Vector3(1, 2, 3)), "Array -> Vektor")
	check(SaveSystem.array_to_vec("x", Vector3.ONE) == Vector3.ONE, "Fallback")
	check_eq(SaveSystem.vec_to_array(Vector3(1.234, 0, 5)), [1.23, 0.0, 5.0], "Vektor -> Array")
