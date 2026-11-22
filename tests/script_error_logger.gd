extends Logger
## Zählt GDScript-Laufzeitfehler, damit der Test-Runner sie einem Test zuordnen kann
## (ein Laufzeitfehler bricht die Testfunktion ab, ohne dass sie fehlschlägt).
## Benötigt Godot 4.5+ (Klasse Logger); unter älteren Versionen wird er nicht geladen.

var errors: Array = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	errors.append("%s (%s:%d) %s" % [rationale if rationale != "" else code, file.get_file(), line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take() -> Array:
	_mutex.lock()
	var out := errors.duplicate()
	errors.clear()
	_mutex.unlock()
	return out
