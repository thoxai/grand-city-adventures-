class_name TouchButton
extends Control
## Runder Multi-Touch-Knopf, der eine Eingabeaktion auslöst.

var action := ""
var caption := ""
var radius := 48.0
var modes: Array = []
var tint := Color(1, 1, 1)
var touch_index := -1
var pressed := false
var highlight := false


func configure(p_caption: String, p_action: String, p_radius: float, p_modes: Array, p_tint: Color = Color.WHITE) -> void:
	caption = p_caption
	action = p_action
	radius = p_radius
	modes = p_modes
	tint = p_tint
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit(p: Vector2) -> bool:
	return visible and (p - (global_position + size * 0.5)).length() <= radius * 1.15


func press(index: int) -> void:
	touch_index = index
	pressed = true
	Input.action_press(action)
	queue_redraw()


func release() -> void:
	if pressed:
		Input.action_release(action)
	touch_index = -1
	pressed = false
	queue_redraw()


func set_highlight(v: bool) -> void:
	if v != highlight:
		highlight = v
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var bg := Color(0, 0, 0, 0.55 if pressed else 0.32)
	draw_circle(c, radius, bg)
	var ring := tint
	ring.a = 0.95 if (pressed or highlight) else 0.55
	draw_arc(c, radius - 2.0, 0, TAU, 40, ring, 4.0 if highlight else 2.5, true)
	var font := get_theme_default_font()
	var fs := int(clampf(radius * 0.36, 13, 22))
	var ts := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, 0.95))
