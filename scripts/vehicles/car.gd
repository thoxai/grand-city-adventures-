class_name Car
extends CharacterBody3D
## Arcade-Fahrphysik auf Basis eines CharacterBody3D.
##
## Modell: Die Geschwindigkeit wird in Laengs- (vf) und Queranteil (vl)
## zerlegt. Motor/Bremse wirken auf vf, die Reifenhaftung daempft vl.
## Lenken dreht die Karosserie abhaengig von der Geschwindigkeit. Wenig
## Grip (Handbremse) => kontrollierbares Driften. Keine Schadensmodelle.

signal impact(strength: float)

const GRAVITY := 20.0

@export var car_id: String = "car_compact"

var spec: Dictionary = {}
var stats: Dictionary = {}
var model: CarModel
var engine_audio: EngineAudio
var active := false
var speed := 0.0
var nitro_charge := 0.0
var boosting := false
var braking := false
var lateral_speed := 0.0
## Fuer Autopilot/Tests: {"throttle", "steer", "handbrake", "nitro"}
var external_input: Dictionary = {}
var use_external := false
var headlights_on := false
## Carsharing-Fahrzeug (Verkehr): immer nutzbar, nicht tunebar
var shared := false
## Verkehrs-KI steuert das Fahrzeug
var ai_driving := false
## Lackfarben-Index für Carsharing-Fahrzeuge (vor add_child setzen)
var color_index := 0
var _steer := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	safe_margin = 0.02
	spec = TuningData.base_spec(car_id)
	var size: Vector3 = spec["size"]
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y * 0.8, size.z)
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.4 + 0.02, 0)
	add_child(shape)
	model = CarModel.new()
	model.name = "Model"
	add_child(model)
	shared = TuningData.is_shared(car_id)
	var t := {} if shared else GameState.get_tuning(car_id)
	var col := TuningData.paint_color(car_id, color_index if shared else int(t.get("color", 0)))
	model.build(spec, col, "GC %s" % ("K2 07" if car_id == "car_compact" else "RS 42"), shared)
	engine_audio = EngineAudio.new()
	add_child(engine_audio)
	apply_tuning()


func apply_tuning() -> void:
	if TuningData.is_shared(car_id):
		stats = TuningData.compute_stats(car_id, {})
		nitro_charge = 0.0
		return
	var t := GameState.get_tuning(car_id)
	stats = TuningData.compute_stats(car_id, t)
	nitro_charge = stats["nitro_capacity"]
	if model:
		model.set_paint(TuningData.paint_color(car_id, int(t.get("color", 0))))


func set_active(v: bool) -> void:
	active = v
	if engine_audio and is_inside_tree():
		if v:
			engine_audio.start()
		else:
			engine_audio.stop_engine()


## Übergibt das Fahrzeug an die Verkehrs-KI bzw. nimmt es ihr ab.
## KI-Autos kollidieren nicht untereinander (sie weichen per Abstandsregel aus).
func set_ai(v: bool) -> void:
	ai_driving = v
	use_external = v
	collision_mask = (1 | 2) if v else (1 | 2 | 4)
	if not v:
		external_input = {}


## Hupe: kurz (KI) oder dauerhaft, solange gehalten (Spieler).
var horn_player: AudioStreamPlayer3D
var _horn_time := 0.0


func honk(duration: float = 0.35) -> void:
	if horn_player == null:
		horn_player = Horn.make_player()
		add_child(horn_player)
	if not horn_player.playing:
		horn_player.play()
	_horn_time = maxf(_horn_time, duration)


func horn_hold(on: bool) -> void:
	if on:
		honk(0.1)
	elif horn_player and _horn_time <= 0.0:
		horn_player.stop()


func is_honking() -> bool:
	return horn_player != null and horn_player.playing


func _process(delta: float) -> void:
	if _horn_time > 0.0:
		_horn_time -= delta
		if _horn_time <= 0.0 and horn_player:
			horn_player.stop()


func is_usable() -> bool:
	if shared:
		return bool(spec.get("usable", true))
	return GameState.is_car_unlocked(car_id)


func display_name() -> String:
	return spec.get("name", car_id)


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	var handbrake := false
	var nitro := false
	if use_external:
		throttle = clampf(float(external_input.get("throttle", 0.0)), -1.0, 1.0)
		steer = clampf(float(external_input.get("steer", 0.0)), -1.0, 1.0)
		handbrake = bool(external_input.get("handbrake", false))
		nitro = bool(external_input.get("nitro", false))
	elif active:
		throttle = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		steer = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		handbrake = Input.is_action_pressed("jump")
		nitro = Input.is_action_pressed("nitro")
	else:
		handbrake = true
	simulate(delta, throttle, steer, handbrake, nitro)


func simulate(delta: float, throttle: float, steer: float, handbrake: bool, nitro: bool) -> void:
	var top: float = stats["top_speed"]
	var cap: float = stats["nitro_capacity"]
	boosting = nitro and cap > 0.0 and nitro_charge > 0.0 and throttle > 0.1
	if boosting:
		nitro_charge = maxf(0.0, nitro_charge - delta)
		top *= stats["nitro_boost"]
	elif cap > 0.0:
		nitro_charge = minf(cap, nitro_charge + delta * 0.12)

	# Lenkung (abhaengig von der Geschwindigkeit des letzten Frames)
	var speed_ratio := clampf(absf(speed) / float(stats["top_speed"]), 0.0, 1.0)
	var steer_limit := lerpf(1.0, 0.42, speed_ratio)
	_steer = move_toward(_steer, steer * steer_limit, delta * 3.5)
	var turn_factor := clampf(absf(speed) / 5.0, 0.0, 1.0)
	var yaw_rate := _steer * float(stats["steer_rate"]) * turn_factor * signf(speed)
	if handbrake:
		yaw_rate *= 1.35
	rotate_y(-yaw_rate * delta)

	var basis := global_transform.basis
	var fwd := -basis.z
	var right := basis.x
	var vf := velocity.dot(fwd)
	var vl := velocity.dot(right)
	var vy := velocity.y
	var accel: float = stats["accel"]
	var brake: float = stats["brake"]
	braking = false

	if throttle > 0.01:
		if vf < -0.5:
			vf = move_toward(vf, 0.0, brake * throttle * delta)
			braking = true
		else:
			var a := accel * throttle * (1.0 - pow(clampf(vf / top, 0.0, 1.0), 2.0))
			if boosting:
				a += accel * 0.9
			vf += a * delta
			if vf > top:
				vf = move_toward(vf, top, brake * 0.3 * delta)
	elif throttle < -0.01:
		if vf > 0.5:
			vf = move_toward(vf, 0.0, brake * -throttle * delta)
			braking = true
		else:
			vf = move_toward(vf, -float(stats["reverse"]), accel * 0.7 * -throttle * delta)
	else:
		vf = move_toward(vf, 0.0, float(stats["drag"]) * delta)
	vf -= vf * 0.02 * delta
	if handbrake:
		vf = move_toward(vf, 0.0, brake * 0.55 * delta)
		braking = braking or absf(vf) > 0.5

	var grip: float = stats["grip"] * (0.22 if handbrake else 1.0)
	vl = lerpf(vl, 0.0, clampf(grip * delta, 0.0, 1.0))
	lateral_speed = vl

	if is_on_floor():
		vy = -0.5
	else:
		vy -= GRAVITY * delta

	velocity = fwd * vf + right * vl + Vector3.UP * vy
	var pre := velocity
	move_and_slide()
	speed = velocity.dot(-global_transform.basis.z)

	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) < 0.6:
			var hit := -pre.dot(n)
			if hit > 4.0:
				velocity *= 0.7
				speed *= 0.7
				impact.emit(hit)
				break

	if model:
		model.update_visuals(speed, _steer, delta)
		model.set_lights(headlights_on, braking, active)
	if engine_audio:
		engine_audio.rpm = clampf(absf(speed) / top, 0.0, 1.0)
		engine_audio.throttle_load = absf(throttle)


func reset_to(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	speed = 0.0
