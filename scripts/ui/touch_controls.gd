class_name TouchControls
extends Control
## Mobile Touch-Steuerung mit echtem Multi-Touch:
## - linke Bildschirmhälfte: dynamischer virtueller Joystick (Bewegen/Lenken)
## - rechte Hälfte: Wischen dreht die Kamera
## - runde Knöpfe je Modus (zu Fuß / im Auto)
## Alle Eingaben werden als Input-Aktionen ausgelöst.

signal camera_drag(relative: Vector2)

const JOY_RADIUS := 80.0
const JOY_ZONE := 0.42

var mode := "foot"
var buttons: Array[TouchButton] = []
var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
var cam_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rechte untere Ecke: Abstand vom Rand als (x, y)
	_add("Aktion", "interact", Vector2(250, 120), 46, ["foot", "car"], UiTheme.ACCENT)
	_add("Sprung", "jump", Vector2(110, 110), 52, ["foot"])
	_add("Sprint", "sprint", Vector2(110, 250), 42, ["foot"])
	_add("Gas", "move_forward", Vector2(105, 130), 62, ["car"], Color(0.4, 1.0, 0.5))
	_add("Bremse", "move_back", Vector2(250, 250), 46, ["car"], Color(1.0, 0.4, 0.35))
	_add("Hand-\nbremse", "jump", Vector2(105, 290), 40, ["car"])
	_add("Nitro", "nitro", Vector2(380, 150), 40, ["car"], UiTheme.ACCENT_2)
	_add("Hupe", "horn", Vector2(380, 290), 40, ["car"], Color(1.0, 0.85, 0.3))
	resized.connect(_layout)
	_layout()
	set_mode("foot")


func _add(caption: String, action: String, offset: Vector2, radius: float, modes: Array, tint: Color = Color.WHITE) -> void:
	var b := TouchButton.new()
	b.configure(caption, action, radius, modes, tint)
	b.set_meta("offset", offset)
	add_child(b)
	buttons.append(b)


func _layout() -> void:
	for b in buttons:
		var off: Vector2 = b.get_meta("offset")
		b.position = size - off - b.size * 0.5


func get_button(action: String, for_mode: String = "") -> TouchButton:
	for b in buttons:
		if b.action == action and (for_mode == "" or for_mode in b.modes):
			return b
	return null


func set_mode(m: String) -> void:
	mode = m
	release_all()
	for b in buttons:
		b.visible = m in b.modes
	queue_redraw()


func release_all() -> void:
	for b in buttons:
		b.release()
	joy_index = -1
	cam_index = -1
	_set_joy(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			for b in buttons:
				if b.hit(e.position) and b.touch_index == -1:
					b.press(e.index)
					get_viewport().set_input_as_handled()
					return
			if e.position.x < size.x * JOY_ZONE and e.position.y > size.y * 0.3 and joy_index == -1:
				joy_index = e.index
				joy_origin = e.position
				joy_pos = e.position
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			if e.position.x >= size.x * JOY_ZONE and cam_index == -1 and e.position.y > 90.0:
				cam_index = e.index
		else:
			for b in buttons:
				if b.touch_index == e.index:
					b.release()
			if e.index == joy_index:
				joy_index = -1
				_set_joy(Vector2.ZERO)
				queue_redraw()
			if e.index == cam_index:
				cam_index = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == joy_index:
			joy_pos = d.position
			var v := (joy_pos - joy_origin) / JOY_RADIUS
			if v.length() > 1.0:
				v = v.normalized()
			_set_joy(v)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif d.index == cam_index:
			camera_drag.emit(d.relative)


func _set_joy(v: Vector2) -> void:
	joy_vec = v
	_axis("move_left", "move_right", v.x)
	if mode == "foot":
		_axis("move_forward", "move_back", v.y)
	elif joy_index != -1 or v == Vector2.ZERO:
		# Im Auto lenkt der Joystick nur; Gas/Bremse über Knöpfe
		# (Joystick nach vorn/hinten wirkt zusätzlich als Gas/Bremse).
		var gas := get_button("move_forward", "car")
		var brk := get_button("move_back", "car")
		if (gas == null or not gas.pressed) and (brk == null or not brk.pressed):
			_axis("move_forward", "move_back", v.y if absf(v.y) > 0.45 else 0.0)


func _axis(neg: String, pos: String, value: float) -> void:
	if value < -0.12:
		Input.action_press(neg, minf(1.0, -value * 1.15))
		Input.action_release(pos)
	elif value > 0.12:
		Input.action_press(pos, minf(1.0, value * 1.15))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _draw() -> void:
	var origin := joy_origin if joy_index != -1 else Vector2(150, size.y - 150)
	var knob := joy_pos if joy_index != -1 else origin
	var a := 0.45 if joy_index != -1 else 0.22
	draw_circle(origin, JOY_RADIUS, Color(0, 0, 0, a * 0.7))
	draw_arc(origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, a), 2.5, true)
	var kp := origin + (knob - origin).limit_length(JOY_RADIUS)
	draw_circle(kp, 34.0, Color(1, 1, 1, a + 0.15))
