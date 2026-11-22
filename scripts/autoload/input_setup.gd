extends Node
## Registriert alle Eingabeaktionen zur Laufzeit (Tastatur + Gamepad).
## Die Touch-Steuerung loest dieselben Aktionen ueber Input.action_press aus,
## dadurch gibt es genau einen Steuerungspfad fuer alle Plattformen.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E, KEY_F],
	"nitro": [KEY_N, KEY_CTRL],
	"tuning": [KEY_T],
	"pause": [KEY_ESCAPE, KEY_P],
	"camera_reset": [KEY_C],
}

const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"interact": JOY_BUTTON_Y,
	"sprint": JOY_BUTTON_LEFT_SHOULDER,
	"nitro": JOY_BUTTON_RIGHT_SHOULDER,
	"pause": JOY_BUTTON_START,
	"tuning": JOY_BUTTON_X,
}

const PAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
}


func _ready() -> void:
	register_actions()


static func register_actions() -> void:
	for action in KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in PAD_BUTTONS.keys():
		var jb := InputEventJoypadButton.new()
		jb.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, jb)
	for action in PAD_AXES.keys():
		var jm := InputEventJoypadMotion.new()
		jm.axis = PAD_AXES[action][0]
		jm.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, jm)
