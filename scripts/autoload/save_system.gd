extends Node
## Lokales Speichern/Laden als JSON unter user:// (Autoload "SaveSystem").
##
## Der Weltzustand (Positionen, aktive Mission) wird ueber einen Callable
## geliefert, den die Hauptszene registriert. So bleibt das Speichersystem
## unabhaengig von der Szene und ist einzeln testbar.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

var world_snapshot_provider: Callable


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH) -> bool:
	var world := {}
	if world_snapshot_provider.is_valid():
		world = world_snapshot_provider.call()
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": GameState.to_dict(),
		"world": world,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## Laedt den Spielstand in GameState und gibt den Welt-Teil zurueck.
## Bei Fehlern wird ein leeres Dictionary zurueckgegeben und GameState
## nicht veraendert.
func load_game(path: String = SAVE_PATH) -> Dictionary:
	var data := read_save(path)
	if data.is_empty():
		return {}
	GameState.from_dict(data["state"])
	return data.get("world", {})


func read_save(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Spielstand beschaedigt: %s" % path)
		return {}
	if int(parsed.get("version", 0)) > SAVE_VERSION:
		push_warning("Spielstand stammt aus einer neueren Version.")
		return {}
	if typeof(parsed.get("state")) != TYPE_DICTIONARY:
		return {}
	return parsed


func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func vec_to_array(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func array_to_vec(a, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if typeof(a) != TYPE_ARRAY or a.size() < 3:
		return fallback
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
