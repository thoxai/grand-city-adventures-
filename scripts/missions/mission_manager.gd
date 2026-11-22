class_name MissionManager
extends Node
## Führt die Story-Missionen schrittweise aus (Daten aus MissionData).
##
## Die Welt wird über ein schmales Interface abgefragt (world):
##   get_player_position() -> Vector3, is_in_vehicle() -> bool,
##   current_car_id() -> String, get_npc(id) -> Npc
## Dadurch lässt sich der Manager auch ohne komplette Szene testen.

signal objective_changed(title: String, text: String)
signal timer_changed(seconds_left: float)
signal mission_started(index: int)
signal mission_completed(index: int)
signal mission_failed(index: int, reason: String)
signal step_changed(index: int, step: int)
signal checkpoint_reached(current: int, total: int)

var world: Object
var active_index := -1
var step_index := 0
var sub_index := 0
var timer := -1.0
var pending_talk := ""
var _markers: Node3D
var _beam_main: MeshInstance3D
var _beam_next: MeshInstance3D
var _ring_main: MeshInstance3D
var _marker_materials: Dictionary = {}
var _last_giver := ""


func setup(p_world: Object, marker_parent: Node3D = null) -> void:
	world = p_world
	if marker_parent:
		_markers = Node3D.new()
		_markers.name = "MissionMarkers"
		marker_parent.add_child(_markers)
		_beam_main = _make_beam(1.2, 40.0)
		_beam_next = _make_beam(0.6, 20.0)
		_ring_main = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.6
		tm.outer_radius = 3.0
		tm.rings = 24
		tm.ring_segments = 6
		_ring_main.mesh = tm
		_ring_main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_markers.add_child(_ring_main)
		_hide_markers()
	refresh_objective()


func _make_beam(radius: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.6
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_markers.add_child(mi)
	return mi


func _marker_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _marker_materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(color, 0.35)
		m.emission_enabled = true
		m.emission = color
		_marker_materials[key] = m
	return _marker_materials[key]


# ------------------------------------------------------------------ Zustand

func is_active() -> bool:
	return active_index >= 0


func next_available_index() -> int:
	for i in MissionData.count():
		if not GameState.is_mission_completed(MissionData.MISSIONS[i]["id"]):
			return i
	return -1


func all_completed() -> bool:
	return next_available_index() == -1


func current_mission() -> Dictionary:
	return MissionData.MISSIONS[active_index] if is_active() else {}


func current_step() -> Dictionary:
	if not is_active():
		return {}
	var steps: Array = current_mission()["steps"]
	return steps[step_index] if step_index < steps.size() else {}


func giver_npc() -> String:
	var i := next_available_index()
	return "" if i < 0 or is_active() else str(MissionData.MISSIONS[i]["giver"])


## Aktuelle Zielposition (für Minikarte/Marker) oder null.
func target_position() -> Variant:
	if not is_active():
		var g := giver_npc()
		if g != "" and world and world.get_npc(g):
			return world.get_npc(g).global_position
		return null
	var s := current_step()
	match s.get("type", ""):
		"goto", "drive", "puzzle":
			return CityLayout.poi(s["poi"])
		"talk":
			var npc = world.get_npc(s["npc"]) if world else null
			return npc.global_position if npc else null
		"race", "delivery":
			var cps := MissionData.checkpoints_for(s)
			return cps[sub_index] if sub_index < cps.size() else null
		"enter_car":
			if world and world.has_method("get_car_position"):
				return world.get_car_position(str(s.get("car", "")))
	return null


func next_checkpoint_position() -> Variant:
	var s := current_step()
	if s.get("type", "") in ["race", "delivery"]:
		var cps := MissionData.checkpoints_for(s)
		if sub_index + 1 < cps.size():
			return cps[sub_index + 1]
	return null


# ------------------------------------------------------------------ Ablauf

func start_mission(index: int) -> void:
	if index < 0 or index >= MissionData.count():
		return
	active_index = index
	step_index = 0
	mission_started.emit(index)
	_begin_step()


func _begin_step() -> void:
	sub_index = 0
	pending_talk = ""
	var s := current_step()
	timer = float(s.get("time_limit", -1.0))
	timer_changed.emit(timer)
	step_changed.emit(active_index, step_index)
	refresh_objective()


func advance() -> void:
	if not is_active():
		return
	var s := current_step()
	if s.has("unlock_car"):
		GameState.unlock_car(s["unlock_car"])
		GameState.notify.emit("Fahrzeug freigeschaltet: %s" % TuningData.base_spec(s["unlock_car"])["name"])
	step_index += 1
	if step_index >= (current_mission()["steps"] as Array).size():
		_complete()
	else:
		_begin_step()


func _complete() -> void:
	var m := current_mission()
	var idx := active_index
	if m.has("unlock_car"):
		GameState.unlock_car(m["unlock_car"])
	GameState.complete_mission(m["id"], int(m["reward"]))
	active_index = -1
	timer = -1.0
	timer_changed.emit(-1.0)
	_hide_markers()
	mission_completed.emit(idx)
	refresh_objective()


## Schlägt den aktuellen Schritt fehl. Hat der Schritt "retry_step", wird die
## Mission an diesem Schritt fortgesetzt (kein kompletter Neustart).
func fail(reason: String) -> void:
	if not is_active():
		return
	var idx := active_index
	var s := current_step()
	if s.has("retry_step"):
		step_index = int(s["retry_step"])
		mission_failed.emit(idx, reason + " Versuch es gleich noch einmal.")
		_begin_step()
		return
	active_index = -1
	timer = -1.0
	timer_changed.emit(-1.0)
	_hide_markers()
	mission_failed.emit(idx, reason)
	refresh_objective()


func abort() -> void:
	fail("Mission abgebrochen.")


func refresh_objective() -> void:
	if is_active():
		var s := current_step()
		var text := MissionData.fill(str(s.get("objective", "")))
		if s.get("type", "") in ["race", "delivery"]:
			text += "  (%d/%d)" % [sub_index, MissionData.checkpoints_for(s).size()]
		objective_changed.emit(str(current_mission()["title"]), text)
	else:
		var i := next_available_index()
		if i < 0:
			objective_changed.emit("Freies Spiel", "Story abgeschlossen! Sammle Energiezellen (%d/%d) und tune deine Autos." % [GameState.collected.size(), CityLayout.COLLECTIBLES.size()])
		else:
			var m: Dictionary = MissionData.MISSIONS[i]
			var giver: String = m["giver"]
			var gname := MissionData.fill(str(NpcData.NPCS[giver]["name"]))
			objective_changed.emit("Nächste Mission: %s" % m["title"], "Sprich mit %s (gelbes !)." % gname)


# ------------------------------------------------------------------ Ereignisse

## Wird beim Ansprechen eines NPCs aufgerufen. Gibt Missionsdialog-Zeilen zurück
## (leer, wenn der NPC gerade nichts mit einer Mission zu tun hat).
func lines_for_talk(npc_id: String) -> Array:
	if not is_active():
		var i := next_available_index()
		if i >= 0 and MissionData.MISSIONS[i]["giver"] == npc_id:
			start_mission(i)
	var s := current_step()
	if s.get("type", "") == "talk" and s.get("npc", "") == npc_id:
		pending_talk = npc_id
		var out: Array = []
		for l in s.get("lines", []):
			out.append([MissionData.fill(l[0]), MissionData.fill(l[1])])
		return out
	return []


func on_dialog_finished(npc_id: String) -> void:
	if pending_talk != "" and pending_talk == npc_id:
		pending_talk = ""
		advance()


## Interaktion am aktuellen Ort (z. B. Rätsel). Leeres Dictionary = keine.
func interaction_at(pos: Vector3) -> Dictionary:
	var s := current_step()
	if s.get("type", "") == "puzzle":
		if _flat_dist(pos, CityLayout.poi(s["poi"])) <= float(s.get("radius", 3.0)):
			return s
	return {}


func on_puzzle_solved() -> void:
	if current_step().get("type", "") == "puzzle":
		advance()


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if world == null:
		return
	_update_givers()
	if not is_active():
		_hide_markers()
		return
	var s := current_step()
	var pos: Vector3 = world.get_player_position()
	var in_car: bool = world.is_in_vehicle()
	var t: String = s.get("type", "")
	var radius := float(s.get("radius", 6.0))
	match t:
		"goto":
			if _flat_dist(pos, CityLayout.poi(s["poi"])) <= radius:
				advance()
		"drive":
			if in_car and _flat_dist(pos, CityLayout.poi(s["poi"])) <= radius:
				advance()
		"enter_car":
			var want := str(s.get("car", ""))
			if in_car and (want == "" or world.current_car_id() == want):
				advance()
		"race", "delivery":
			var cps := MissionData.checkpoints_for(s)
			if in_car and sub_index < cps.size() and _flat_dist(pos, cps[sub_index]) <= radius:
				sub_index += 1
				checkpoint_reached.emit(sub_index, cps.size())
				refresh_objective()
				if sub_index >= cps.size():
					advance()
	if not is_active():
		return
	if timer >= 0.0:
		timer -= delta
		timer_changed.emit(maxf(timer, 0.0))
		if timer <= 0.0:
			fail("Die Zeit ist abgelaufen!")
			return
	_update_markers()


func _update_givers() -> void:
	var g := giver_npc()
	if g == _last_giver:
		return
	if _last_giver != "" and world.get_npc(_last_giver):
		world.get_npc(_last_giver).set_mission_marker(false)
	if g != "" and world.get_npc(g):
		world.get_npc(g).set_mission_marker(true)
	_last_giver = g


func _update_markers() -> void:
	if _markers == null:
		return
	var target = target_position()
	var s := current_step()
	var t: String = s.get("type", "")
	if target == null or t == "talk" or t == "enter_car":
		_hide_markers()
		return
	var col := Color(1.0, 0.82, 0.2)
	if t == "race":
		col = Color(0.2, 0.85, 1.0)
	elif t == "delivery":
		col = Color(0.4, 1.0, 0.45)
	elif t == "puzzle":
		col = Color(1.0, 0.5, 0.15)
	var mat := _marker_material(col)
	var r := float(s.get("radius", 6.0))
	_beam_main.visible = true
	_beam_main.material_override = mat
	_beam_main.global_position = target + Vector3(0, 20.0, 0)
	_beam_main.scale = Vector3(r / 6.0, 1, r / 6.0) * 1.5
	_ring_main.visible = true
	_ring_main.material_override = mat
	_ring_main.global_position = target + Vector3(0, 0.3, 0)
	_ring_main.scale = Vector3.ONE * (r / 3.0)
	_ring_main.rotate_y(0.02)
	var nxt = next_checkpoint_position()
	_beam_next.visible = nxt != null
	if nxt != null:
		_beam_next.material_override = _marker_material(col.darkened(0.3))
		_beam_next.global_position = nxt + Vector3(0, 10.0, 0)


func _hide_markers() -> void:
	if _beam_main:
		_beam_main.visible = false
		_beam_next.visible = false
		_ring_main.visible = false
