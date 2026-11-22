class_name CameraRig
extends Node3D
## Third-Person-Kamera mit SpringArm (weicht Waenden aus).
## Zu Fuss frei dreh-/neigbar, im Auto folgt sie automatisch dem Heck.

const FOOT_DISTANCE := 4.2
const CAR_DISTANCE := 7.5
const MIN_PITCH := deg_to_rad(-55.0)
const MAX_PITCH := deg_to_rad(12.0)

var target: Node3D
var in_vehicle := false
var yaw := 0.0
var pitch := deg_to_rad(-14.0)
var sensitivity := 0.006
var cinematic := false
var _manual_timer := 0.0
var spring: SpringArm3D
var camera: Camera3D
var _cine_t := 0.0


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = FOOT_DISTANCE
	spring.collision_mask = 1
	spring.margin = 0.3
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.1
	camera.far = 900.0
	camera.current = true
	spring.add_child(camera)


func set_target(t: Node3D, vehicle: bool = false) -> void:
	target = t
	in_vehicle = vehicle
	if t:
		global_position = _focus_point()
		if vehicle:
			yaw = t.global_rotation.y
			pitch = deg_to_rad(-12.0)


func rotate_by(rel: Vector2) -> void:
	yaw -= rel.x * sensitivity
	pitch = clampf(pitch - rel.y * sensitivity, MIN_PITCH, MAX_PITCH)
	_manual_timer = 1.6


func reset_behind() -> void:
	if target:
		yaw = target.global_rotation.y if in_vehicle else yaw
		pitch = deg_to_rad(-14.0)


func _unhandled_input(event: InputEvent) -> void:
	# Desktop: Kamera mit gedrueckter rechter Maustaste drehen
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		rotate_by(event.relative)


func _focus_point() -> Vector3:
	if target == null:
		return global_position
	return target.global_position + Vector3(0, 1.9 if in_vehicle else 1.55, 0)


func _process(delta: float) -> void:
	if cinematic:
		_cine_t += delta * 0.05
		var c := Vector3(-60, 0, -10)
		global_position = c + Vector3(cos(_cine_t) * 70.0, 34.0, sin(_cine_t) * 70.0)
		rotation = Vector3.ZERO
		spring.rotation = Vector3.ZERO
		spring.spring_length = 0.0
		camera.look_at(c + Vector3(0, 8, 0))
		return
	if target == null:
		return
	if Input.is_action_just_pressed("camera_reset"):
		reset_behind()
	_manual_timer -= delta
	var length := CAR_DISTANCE if in_vehicle else FOOT_DISTANCE
	spring.spring_length = lerpf(spring.spring_length, length, minf(1.0, delta * 3.0))
	if in_vehicle and _manual_timer <= 0.0:
		var spd: float = target.get("speed") if target.get("speed") != null else 0.0
		var behind: float = target.global_rotation.y + (PI if spd < -2.0 else 0.0)
		var k := clampf(absf(spd) / 10.0, 0.0, 1.0)
		yaw = lerp_angle(yaw, behind, minf(1.0, delta * 2.5 * k))
		pitch = lerpf(pitch, deg_to_rad(-11.0), minf(1.0, delta * 1.5 * k))
	var follow := 18.0 if in_vehicle else 12.0
	global_position = global_position.lerp(_focus_point(), minf(1.0, delta * follow))
	rotation = Vector3(0, yaw, 0)
	spring.rotation = Vector3(pitch, 0, 0)
	camera.rotation = Vector3.ZERO
	if in_vehicle:
		var spd2: float = absf(target.get("speed")) if target.get("speed") != null else 0.0
		camera.fov = lerpf(camera.fov, 68.0 + clampf(spd2 / 40.0, 0.0, 1.0) * 14.0, minf(1.0, delta * 3.0))
	else:
		camera.fov = lerpf(camera.fov, 68.0, minf(1.0, delta * 3.0))


func get_camera_position() -> Vector3:
	return camera.global_position if camera else global_position
