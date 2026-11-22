class_name Npc
extends CharacterBody3D
## NPC mit Tagesablauf (stehen, Rundgang, zu Hause), Dialogen und
## Ausweichverhalten vor Fahrzeugen. NPCs kollidieren nicht mit Autos –
## sie springen rechtzeitig zur Seite (gewaltfreies Design).

const GRAVITY := 14.0
const ARRIVE_DIST := 0.6
const ACTIVE_RANGE := 110.0

var npc_id := ""
var data: Dictionary = {}
var model: HumanoidModel
var walk_speed := 1.4
var talking := false
var talk_target := Vector3.ZERO
var is_home := false
var cars_provider: Callable
var camera_provider: Callable
var mission_marker: Label3D
var _activity: Dictionary = {}
var _path: Array = []
var _path_index := 0
var _dodge_timer := 0.0
var _dodge_dir := Vector3.ZERO
var _shape: CollisionShape3D
var _bubble: Label3D
var _bubble_t := 0.0


func setup(id: String, d: Dictionary, look: Dictionary) -> void:
	npc_id = id
	data = d
	walk_speed = float(d.get("speed", 1.4))
	name = "NPC_" + id


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	_shape.shape = cap
	_shape.position = Vector3(0, 0.85, 0)
	add_child(_shape)
	model = HumanoidModel.new()
	add_child(model)
	mission_marker = Label3D.new()
	mission_marker.text = "!"
	mission_marker.font_size = 160
	mission_marker.pixel_size = 0.004
	mission_marker.modulate = Color(1.0, 0.8, 0.2)
	mission_marker.outline_size = 12
	mission_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mission_marker.no_depth_test = true
	mission_marker.position = Vector3(0, 2.35, 0)
	mission_marker.visible = false
	add_child(mission_marker)


func build_look(look: Dictionary) -> void:
	model.build(look)


func display_name() -> String:
	return MissionData.fill(str(data.get("name", npc_id)))


func is_story() -> bool:
	return bool(data.get("story", false))


func can_talk() -> bool:
	return visible and not is_home


func set_mission_marker(v: bool) -> void:
	if mission_marker:
		mission_marker.visible = v


## Sprechblase über dem Kopf.
func say(text: String, duration: float = 2.2) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.font_size = 56
		_bubble.pixel_size = 0.006
		_bubble.outline_size = 10
		_bubble.modulate = Color(1, 1, 1)
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.position = Vector3(0, 2.25, 0)
		_bubble.visibility_range_end = 45.0
		# Feste Bildschirmgröße: nah nicht riesig, fern noch lesbar
		_bubble.fixed_size = true
		_bubble.pixel_size = 0.0009
		add_child(_bubble)
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = duration


func is_saying() -> bool:
	return _bubble != null and _bubble.visible


## Reaktion auf eine Hupe: kommentieren, und aus dem Weg gehen, wenn vor dem Auto.
func react_to_horn(car: Node3D) -> void:
	if is_home or talking:
		return
	say(NpcData.HORN_REACTIONS[randi() % NpcData.HORN_REACTIONS.size()])
	var fwd := -car.global_transform.basis.z
	var rel := global_position - car.global_position
	rel.y = 0.0
	if rel.dot(fwd) > 0.0 and rel.length() < 12.0:
		var side := fwd.cross(Vector3.UP).normalized()
		_dodge_dir = side if rel.dot(side) > 0.0 else -side
		_dodge_timer = 0.6


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and _bubble:
			_bubble.visible = false


func begin_talk(player_pos: Vector3) -> void:
	talking = true
	talk_target = player_pos
	if model:
		model.waving = true


func end_talk() -> void:
	talking = false
	if model:
		model.waving = false


## Setzt die Figur sofort an den Ort ihrer aktuellen Tagesaktivität.
func snap_to_schedule(hour: float) -> void:
	_apply_activity(NpcData.activity_for_hour(data.get("schedule", []), hour), true)


func _apply_activity(act: Dictionary, teleport: bool) -> void:
	_activity = act
	var t: String = act.get("type", "idle")
	is_home = t == "home"
	visible = not is_home
	_shape.disabled = is_home
	_path = NpcData.path_for(act)
	if teleport and not _path.is_empty():
		_path_index = 0
		global_position = _path[0]
	elif not _path.is_empty():
		# Mit dem nächstgelegenen Wegpunkt weitermachen
		var best := 0
		for i in _path.size():
			if global_position.distance_to(_path[i]) < global_position.distance_to(_path[best]):
				best = i
		_path_index = best


func _physics_process(delta: float) -> void:
	var hour := GameState.time_of_day
	var act := NpcData.activity_for_hour(data.get("schedule", []), hour)
	if act != _activity:
		var far := true
		if camera_provider.is_valid():
			far = global_position.distance_to(camera_provider.call()) > 60.0
		_apply_activity(act, far or is_home)
	if is_home:
		return
	var cam_dist := 0.0
	if camera_provider.is_valid():
		cam_dist = global_position.distance_to(camera_provider.call())
	if cam_dist > ACTIVE_RANGE:
		return  # weit weg: keine Simulation (Performance)

	var move := Vector3.ZERO
	_check_cars()
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		move = _dodge_dir * 5.0
	elif talking:
		_face(talk_target, delta)
	elif _activity.get("type", "idle") == "walk" and _path.size() > 1:
		var target: Vector3 = _path[_path_index]
		var to := target - global_position
		to.y = 0.0
		if to.length() < ARRIVE_DIST:
			_path_index = (_path_index + 1) % _path.size()
		else:
			move = to.normalized() * walk_speed
	elif not _path.is_empty():
		var home_pt: Vector3 = _path[0]
		var to2 := home_pt - global_position
		to2.y = 0.0
		if to2.length() > ARRIVE_DIST:
			move = to2.normalized() * walk_speed

	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if move.length() > 0.1 and model:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-move.x, -move.z), minf(1.0, delta * 8.0))
	if model and cam_dist < HumanoidModel.DETAIL_RANGE + 5.0:
		model.animate(Vector2(velocity.x, velocity.z).length(), delta, _dodge_timer > 0.3)


func _face(p: Vector3, delta: float) -> void:
	var d := p - global_position
	if model and Vector2(d.x, d.z).length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 6.0))


func _check_cars() -> void:
	if _dodge_timer > 0.0 or not cars_provider.is_valid():
		return
	for car in cars_provider.call():
		var c := car as Car
		if c == null or absf(c.speed) < 4.0:
			continue
		var rel := global_position - c.global_position
		rel.y = 0.0
		if rel.length() > 9.0:
			continue
		var heading := -c.global_transform.basis.z * signf(c.speed)
		if rel.normalized().dot(heading) > 0.6:
			var side := heading.cross(Vector3.UP).normalized()
			_dodge_dir = side if rel.dot(side) > 0.0 else -side
			_dodge_timer = 0.55
			return
