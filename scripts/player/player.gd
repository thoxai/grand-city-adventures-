class_name Player
extends CharacterBody3D
## Spielfigur (Alex oder Mia) – Laufen, Sprinten, Springen.
## Bewegung ist relativ zur Kamera-Ausrichtung.

const WALK_SPEED := 3.2
const RUN_SPEED := 6.4
const JUMP_VELOCITY := 4.6
const GRAVITY := 14.0
const ACCEL := 14.0
const TURN_SPEED := 10.0

var camera_rig: Node3D
var model: HumanoidModel
var controls_enabled := true
var character_id := "alex"


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	model = HumanoidModel.new()
	model.name = "Model"
	add_child(model)
	set_character(character_id)


func set_character(id: String) -> void:
	character_id = id
	if model:
		model.build(HumanoidModel.preset(id))


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var sprint := false
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint = Input.is_action_pressed("sprint")
	var yaw: float = camera_rig.yaw if camera_rig else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var target_speed := (RUN_SPEED if sprint else WALK_SPEED) * minf(1.0, input.length())
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(dir.normalized() * target_speed, ACCEL * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif controls_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	if hv.length() > 0.2 and model:
		var target_rot := atan2(-hv.x, -hv.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rot, minf(1.0, TURN_SPEED * delta))
	if model:
		model.animate(hv.length(), delta, not is_on_floor())


func facing() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, model.rotation.y if model else 0.0)


func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if model and Vector2(d.x, d.z).length() > 0.1:
		model.rotation.y = atan2(-d.x, -d.z)
