class_name TestCase
extends RefCounted
## Minimale Test-Basisklasse (ohne externe Abhängigkeiten wie GUT).

var runner: Node
var failures: Array = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(cond: bool, msg: String = "Bedingung nicht erfüllt") -> void:
	if not cond:
		failures.append(msg)


func check_eq(actual, expected, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		failures.append("%s: Typ %s != %s (%s vs %s)" % [msg, type_string(typeof(actual)), type_string(typeof(expected)), actual, expected])
	elif actual != expected:
		failures.append("%s: erwartet <%s>, erhalten <%s>" % [msg, expected, actual])


func check_near(actual: float, expected: float, eps: float, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		failures.append("%s: erwartet %.3f ± %.3f, erhalten %.3f" % [msg, expected, eps, actual])


func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func tree() -> SceneTree:
	return runner.get_tree()


func physics_frames(n: int) -> void:
	for i in n:
		await runner.get_tree().physics_frame


func frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame
