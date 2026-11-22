extends Node
## Misst Draw-Calls bei verschiedenen Einstellungen (benötigt echten Renderer).
var main: Node

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _w(0.5)
	main.hud.hide_start_menu()
	main.start_new_game("alex")
	main.player.global_position = Vector3(20, 0, -45)
	GameState.time_of_day = 12.0
	await _w(1.0)
	await _m("baseline")
	main.hud.root.visible = false
	await _m("ohne UI")
	main.day_night.shadows_enabled = false
	await _m("ohne Schatten")
	for n in main.npcs.values(): n.visible = false
	await _m("ohne NPCs")
	for c in main.traffic.cars: c.visible = false
	await _m("ohne Verkehr")
	main.traffic_lights.visible = false
	await _m("ohne Ampeln")
	for c in main.cars.values(): c.visible = false
	await _m("ohne eigene Autos")
	main.player.visible = false
	await _m("ohne Spieler")
	for c in main.city.get_children():
		if c is Label3D: c.visible = false
	await _m("ohne Label3D")
	for c in main.collectible_nodes.values(): c.visible = false
	await _m("ohne Sammelobjekte")
	for c in main.city.get_children():
		if c is GeometryInstance3D: c.visible = false
	await _m("ohne Stadt")
	get_tree().quit()

func _w(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _m(label: String) -> void:
	await _w(0.3)
	print("%-22s draw=%d objs=%d prims=%d" % [label, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
