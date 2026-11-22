class_name UiTheme
extends RefCounted
## Einheitliches, modernes UI-Theme (dunkle Glas-Panels, orange Akzente).

const ACCENT := Color(1.0, 0.6, 0.18)
const ACCENT_2 := Color(0.25, 0.8, 1.0)
const PANEL_BG := Color(0.07, 0.08, 0.1, 0.86)
const TEXT := Color(0.95, 0.95, 0.96)
const TEXT_DIM := Color(0.7, 0.72, 0.76)


static func panel_style(bg: Color = PANEL_BG, radius: int = 14, border: Color = Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var normal := panel_style(Color(0.16, 0.17, 0.2, 0.95), 12)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.25, 0.3, 0.98)
	var pressed := normal.duplicate()
	pressed.bg_color = ACCENT.darkened(0.25)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.12, 0.12, 0.14, 0.7)
	var focus := normal.duplicate()
	focus.draw_center = false
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	var bar_bg := panel_style(Color(0.15, 0.15, 0.18), 6)
	bar_bg.content_margin_top = 0
	bar_bg.content_margin_bottom = 0
	var bar_fill := panel_style(ACCENT, 6, ACCENT)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_font_size("font_size", "ProgressBar", 14)
	return t


## outline: Kontur nur für Texte direkt über der 3D-Szene (kostet Draw-Calls).
static func label(text: String, size: int = 22, color: Color = TEXT, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("outline_size", 5)
	return l


static func button(text: String, callback: Callable, min_size: Vector2 = Vector2(0, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(callback)
	return b
