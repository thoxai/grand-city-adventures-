extends Node3D
## Hauptszene: verbindet Stadt, Spieler, Fahrzeuge, NPCs, Missionen und UI.
## Stellt außerdem das Welt-Interface für MissionManager und Minikarte bereit.

const PlayerScene := preload("res://scenes/player/player.tscn")
const CarScene := preload("res://scenes/vehicles/car.tscn")
const NpcScene := preload("res://scenes/npc/npc.tscn")

const TALK_RANGE := 2.8
const CAR_ENTER_RANGE := 3.4
const TUNING_RANGE := 7.0
const COLLECT_RANGE := 1.6

@onready var city: CityBuilder = $City
@onready var day_night: DayNightCycle = $DayNight
@onready var camera_rig: CameraRig = $CameraRig
@onready var missions: MissionManager = $MissionManager
@onready var hud: Hud = $HUD

var player: Player
var cars: Dictionary = {}
var npcs: Dictionary = {}
var current_car: Car = null
var traffic: TrafficManager
var game_running := false
var input_locked := false
var collectible_nodes: Dictionary = {}
var _interact_action: Callable
var _collect_t := 0.0


func _ready() -> void:
	city.build()
	day_night.setup(city)
	day_night.camera_provider = func(): return camera_rig.get_camera_position()
	_spawn_player()
	_spawn_cars()
	traffic = TrafficManager.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(self)
	for c in traffic.cars:
		c.impact.connect(_on_car_impact)
	_spawn_npcs()
	_spawn_collectibles()
	SaveSystem.world_snapshot_provider = world_snapshot
	hud.setup(self)
	hud.minimap.city = city
	hud.minimap.world = self
	hud.minimap.missions = missions
	missions.objective_changed.connect(hud.set_objective)
	missions.timer_changed.connect(hud.set_timer)
	missions.mission_started.connect(_on_mission_started)
	missions.mission_completed.connect(_on_mission_completed)
	missions.mission_failed.connect(_on_mission_failed)
	missions.checkpoint_reached.connect(_on_checkpoint)
	missions.setup(self, self)
	apply_quality()
	return_to_menu()


# ------------------------------------------------------------------ Spawning

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.camera_rig = camera_rig
	add_child(player)
	player.global_position = CityLayout.poi("home")


func _spawn_cars() -> void:
	for id in ["car_compact", "car_sport"]:
		var car: Car = CarScene.instantiate()
		car.car_id = id
		car.name = id
		add_child(car)
		cars[id] = car
		car.impact.connect(_on_car_impact)
	_reset_cars()


func _reset_cars() -> void:
	cars["car_compact"].reset_to(CityLayout.poi("car_compact_spawn"), PI / 2.0)
	cars["car_sport"].reset_to(CityLayout.poi("car_sport_spawn"), PI / 2.0)
	for c in cars.values():
		c.apply_tuning()


func _spawn_npcs() -> void:
	for id in NpcData.NPCS.keys():
		var d: Dictionary = NpcData.NPCS[id]
		var npc: Npc = NpcScene.instantiate()
		npc.setup(id, d, d.get("look", {}))
		add_child(npc)
		npc.cars_provider = get_cars
		npc.camera_provider = func(): return camera_rig.get_camera_position()
		npc.build_look(d.get("look", {}) if id != "partner" else HumanoidModel.preset(GameState.partner_id()))
		npc.snap_to_schedule(GameState.time_of_day)
		npcs[id] = npc


func _spawn_collectibles() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.metallic = 0.3
	for i in CityLayout.COLLECTIBLES.size():
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.5, 0.7, 0.5)
		mi.mesh = pm
		mi.material_override = mat
		mi.position = CityLayout.COLLECTIBLES[i] + Vector3(0, 1.1, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Cell_%d" % i
		add_child(mi)
		collectible_nodes["cell_%d" % i] = mi
	_refresh_collectibles()


func _refresh_collectibles() -> void:
	for id in collectible_nodes.keys():
		collectible_nodes[id].visible = not GameState.collected.has(id)


# ------------------------------------------------------------------ Spielablauf

func return_to_menu() -> void:
	if current_car:
		exit_car(true)
	game_running = false
	camera_rig.cinematic = true
	hud.show_start_menu()


func start_new_game(char_id: String) -> void:
	GameState.reset_new_game(char_id)
	missions.active_index = -1
	_apply_character()
	_reset_cars()
	player.global_position = CityLayout.poi("home")
	player.velocity = Vector3.ZERO
	if traffic:
		traffic.reset_all()
	camera_rig.yaw = 0.0  # Blick zur Straße
	_begin_play()
	hud.toast("Willkommen im Alten Hafen, %s!\nTipp: Grüne CityFlitzer-Autos kannst du jederzeit fahren – daneben „Aktion“ drücken." % GameState.character_name(), 7.0)


func continue_game() -> void:
	if not load_game():
		start_new_game("alex")


func _begin_play() -> void:
	for npc in npcs.values():
		npc.snap_to_schedule(GameState.time_of_day)
	_refresh_collectibles()
	camera_rig.cinematic = false
	camera_rig.set_target(player)
	game_running = true
	input_locked = false
	missions.refresh_objective()


func _apply_character() -> void:
	player.set_character(GameState.character_id)
	if npcs.has("partner"):
		npcs["partner"].build_look(HumanoidModel.preset(GameState.partner_id()))


func switch_character() -> void:
	GameState.character_id = GameState.partner_id()
	_apply_character()
	missions.refresh_objective()


func _process(delta: float) -> void:
	if not game_running:
		return
	GameState.advance_time(delta)
	var locked := input_locked or hud.any_menu_open()
	player.controls_enabled = not locked and current_car == null
	if current_car:
		current_car.active = not locked
		current_car.headlights_on = day_night.night_factor > 0.4
		var has_nitro: bool = current_car.stats["nitro_capacity"] > 0.0
		hud.update_speed(TuningData.kmh(absf(current_car.speed)), current_car.nitro_charge / maxf(0.01, current_car.stats["nitro_capacity"]), has_nitro)
		var near_tuning := _flat(current_car.global_position, CityLayout.poi("garage_tuning")) < TUNING_RANGE and absf(current_car.speed) < 3.0
		hud.set_tuning_available(near_tuning and not locked and not current_car.shared)
		if near_tuning and not locked and Input.is_action_just_pressed("tuning"):
			open_tuning()
		if current_car.global_position.y < -3.0:
			_rescue_car(current_car)
	else:
		hud.set_tuning_available(false)
		if player.global_position.y < -5.0:
			player.global_position = CityLayout.poi("home")
	_update_interaction(locked)
	_update_collectibles(delta)


func _update_interaction(locked: bool) -> void:
	var prompt := ""
	_interact_action = Callable()
	if not locked:
		if current_car:
			_interact_action = exit_car
		else:
			var pos := player.global_position
			var inter := missions.interaction_at(pos)
			if not inter.is_empty():
				prompt = "Aktion: " + str(inter.get("prompt", "Untersuchen"))
				_interact_action = open_puzzle.bind(inter)
			else:
				# Nächstgelegenes Ziel gewinnt (Person oder Auto)
				var npc := _nearest_npc(pos)
				var car := _nearest_car(pos)
				if npc and car and _flat(pos, car.global_position) - 1.0 < _flat(pos, npc.global_position):
					npc = null
				if npc:
					prompt = "Aktion: Sprechen mit %s" % npc.display_name()
					_interact_action = talk_to.bind(npc)
				elif car:
					if car.shared:
						prompt = "Aktion: Einsteigen (%s · Carsharing)" % car.display_name()
						_interact_action = enter_car.bind(car)
					elif GameState.is_car_unlocked(car.car_id):
						prompt = "Aktion: Einsteigen (%s)" % car.display_name()
						_interact_action = enter_car.bind(car)
					else:
						prompt = "%s – gehört noch Kenji" % car.display_name()
		if _interact_action.is_valid() and Input.is_action_just_pressed("interact"):
			_interact_action.call()
	hud.set_prompt(prompt)


func _nearest_npc(pos: Vector3) -> Npc:
	var best: Npc = null
	var best_d := TALK_RANGE
	for npc in npcs.values():
		if not npc.can_talk():
			continue
		var d := _flat(pos, npc.global_position)
		if d < best_d:
			best_d = d
			best = npc
	return best


func _nearest_car(pos: Vector3) -> Car:
	var best: Car = null
	var best_d := CAR_ENTER_RANGE
	for car in get_cars():
		if not car.visible or absf(car.speed) > 14.0:
			continue
		var d := _flat(pos, car.global_position)
		if d < best_d:
			best_d = d
			best = car
	return best


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_collectibles(delta: float) -> void:
	_collect_t += delta
	var pos := get_player_position()
	for id in collectible_nodes.keys():
		var node: MeshInstance3D = collectible_nodes[id]
		if not node.visible:
			continue
		node.rotation.y = _collect_t * 1.5
		node.position.y = 1.1 + sin(_collect_t * 2.0) * 0.15
		var r := COLLECT_RANGE if current_car == null else COLLECT_RANGE + 1.5
		if _flat(pos, node.global_position) < r:
			if GameState.collect(id):
				node.visible = false
				hud.toast("Energiezelle gefunden! (%d/%d)  +%d €" % [GameState.collected.size(), CityLayout.COLLECTIBLES.size(), GameState.COLLECTIBLE_REWARD])
				missions.refresh_objective()


# ------------------------------------------------------------------ Aktionen

func talk_to(npc: Npc) -> void:
	var lines := missions.lines_for_talk(npc.npc_id)
	var is_mission := not lines.is_empty()
	if not is_mission:
		var l := NpcData.line_for(npc.npc_id, GameState.time_of_day, missions.all_completed())
		if l == "":
			l = "..."
		lines = [[npc.display_name(), MissionData.fill(l)]]
	npc.begin_talk(player.global_position)
	player.face_towards(npc.global_position)
	input_locked = true
	hud.show_dialog(lines, func():
		npc.end_talk()
		input_locked = false
		if is_mission:
			missions.on_dialog_finished(npc.npc_id))


func open_puzzle(step: Dictionary) -> void:
	input_locked = true
	hud.open_puzzle(step, _on_puzzle_solved, _on_puzzle_cancelled)


func _on_puzzle_solved() -> void:
	input_locked = false
	missions.on_puzzle_solved()
	hud.toast("Rätsel gelöst!")


func _on_puzzle_cancelled() -> void:
	input_locked = false


func open_tuning() -> void:
	if current_car == null:
		return
	if current_car.shared:
		hud.toast("CityFlitzer-Carsharing kann nicht getunt werden – nutze ein eigenes Auto.")
		return
	input_locked = true
	current_car.velocity = Vector3.ZERO
	current_car.speed = 0.0
	hud.open_tuning(current_car, func(): input_locked = false)


func enter_car(car: Car) -> void:
	if current_car or not car.is_usable():
		return
	if traffic and traffic.is_traffic_car(car):
		traffic.take_over(car)
	current_car = car
	car.set_active(true)
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_set_player_collision(false)
	camera_rig.set_target(car, true)
	hud.set_vehicle_mode(true)


func exit_car(force: bool = false) -> void:
	if current_car == null:
		return
	var car := current_car
	if absf(car.speed) > 6.0 and not force:
		hud.toast("Erst langsamer werden!")
		return
	car.set_active(false)
	car.headlights_on = false
	current_car = null
	player.global_position = _find_exit_position(car)
	player.velocity = Vector3.ZERO
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	_set_player_collision(true)
	camera_rig.set_target(player)
	camera_rig.yaw = car.global_rotation.y
	hud.set_vehicle_mode(false)


func _set_player_collision(enabled: bool) -> void:
	for c in player.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", not enabled)


func _find_exit_position(car: Car) -> Vector3:
	var b := car.global_transform.basis
	var w: float = car.spec["size"].x
	var candidates := [-b.x * (w * 0.5 + 0.8), b.x * (w * 0.5 + 0.8), b.z * 3.2, -b.z * 3.2]
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	for off in candidates:
		var p: Vector3 = car.global_position + off
		p.y = 0.0
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.95, 0))
		q.collision_mask = 1 | 4
		q.exclude = [car.get_rid()]
		if space.intersect_shape(q, 1).is_empty() and CityLayout.is_inside_bounds(p):
			return p
	return car.global_position + Vector3(0, 2.0, 0)


func _rescue_car(car: Car) -> void:
	var p := CityLayout.nearest_road_point(car.global_position)
	car.reset_to(p + Vector3(0, 0.5, 0), car.rotation.y)
	hud.toast("Fahrzeug zurückgesetzt.")


func _on_car_impact(strength: float) -> void:
	if current_car == null:
		return
	camera_rig.add_shake(clampf(strength / 20.0, 0.1, 1.0))
	if strength > 10.0:
		hud.toast("Rums! Vorsichtig fahren.", 1.5)


# ------------------------------------------------------------------ Missions-Events

func _on_mission_started(index: int) -> void:
	hud.toast("Mission gestartet: %s" % MissionData.MISSIONS[index]["title"], 3.0)


func _on_mission_completed(index: int) -> void:
	var m: Dictionary = MissionData.MISSIONS[index]
	var done := GameState.completed_missions.size()
	hud.show_mission_complete(m, "Story-Fortschritt: %d/%d Missionen" % [done, MissionData.count()])
	SaveSystem.save_game()


func _on_mission_failed(_index: int, reason: String) -> void:
	hud.toast(reason, 4.5)


func _on_checkpoint(current: int, total: int) -> void:
	if current < total:
		hud.toast("Checkpoint %d/%d" % [current, total], 1.2)


# ------------------------------------------------------------------ Welt-Interface

func get_player_position() -> Vector3:
	return current_car.global_position if current_car else player.global_position


func get_player_heading() -> float:
	return current_car.global_rotation.y if current_car else player.model.rotation.y


func is_in_vehicle() -> bool:
	return current_car != null


func current_car_id() -> String:
	return current_car.car_id if current_car else ""


func get_npc(id: String) -> Npc:
	return npcs.get(id)


## Alle Fahrzeuge: eigene Autos und sichtbarer Carsharing-Verkehr.
func get_cars() -> Array:
	var out: Array = cars.values()
	if traffic:
		for c in traffic.cars:
			if c.visible:
				out.append(c)
	return out


func get_car_position(id: String) -> Variant:
	if id != "" and cars.has(id):
		return cars[id].global_position
	for c in cars.values():
		if GameState.is_car_unlocked(c.car_id):
			return c.global_position
	return null


# ------------------------------------------------------------------ Speichern / Laden

func world_snapshot() -> Dictionary:
	var car_data := {}
	for id in cars.keys():
		var c: Car = cars[id]
		car_data[id] = {"pos": SaveSystem.vec_to_array(c.global_position), "yaw": c.rotation.y}
	return {
		"player_pos": SaveSystem.vec_to_array(player.global_position if current_car == null else _find_exit_position(current_car)),
		"cars": car_data,
	}


func save_game() -> bool:
	return SaveSystem.save_game()


func load_game() -> bool:
	if not SaveSystem.has_save():
		return false
	if current_car:
		exit_car(true)
	var world := SaveSystem.load_game()
	if world.is_empty() and not SaveSystem.has_save():
		return false
	missions.active_index = -1
	missions.timer = -1.0
	missions.timer_changed.emit(-1.0)
	_apply_character()
	for id in cars.keys():
		var cd: Dictionary = world.get("cars", {}).get(id, {})
		var c: Car = cars[id]
		if cd.is_empty():
			continue
		c.reset_to(SaveSystem.array_to_vec(cd.get("pos"), c.global_position), float(cd.get("yaw", 0.0)))
		c.apply_tuning()
	player.global_position = SaveSystem.array_to_vec(world.get("player_pos"), CityLayout.poi("home"))
	player.velocity = Vector3.ZERO
	_begin_play()
	hud.hide_start_menu()
	hud.toast("Spielstand geladen.")
	return true


# ------------------------------------------------------------------ Grafik

func apply_quality() -> void:
	if traffic:
		traffic.set_density(TrafficManager.DENSITY.get(GameState.quality, 20))
	var vp := get_viewport()
	match GameState.quality:
		"low":
			vp.scaling_3d_scale = 0.7
			vp.msaa_3d = Viewport.MSAA_DISABLED
			day_night.shadows_enabled = false
			day_night.env.glow_enabled = false
			day_night.env.fog_enabled = false
		"high":
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			day_night.shadows_enabled = true
			day_night.sun.directional_shadow_max_distance = 130.0
			day_night.env.glow_enabled = true
			day_night.env.fog_enabled = true
		_:
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
			day_night.shadows_enabled = true
			day_night.sun.directional_shadow_max_distance = 80.0
			day_night.env.glow_enabled = true
			day_night.env.fog_enabled = true
