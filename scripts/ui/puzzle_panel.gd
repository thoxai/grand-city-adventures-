class_name PuzzlePanel
extends PanelContainer
## UI für die technischen Rätsel (Sicherungen / Frequenz).

signal solved
signal cancelled

var _content: VBoxContainer
var _lights: PuzzleLogic.LightsOut
var _freq: PuzzleLogic.Frequency
var _cells: Array[Button] = []
var _status: Label
var _moves: Label
var _strength_bar: ProgressBar
var _wave: Control
var _freq_slider: HSlider
var _phase_slider: HSlider
var _freq_label: Label
var _done := false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _reset(title: String, subtitle: String) -> void:
	for c in get_children():
		c.queue_free()
	_cells.clear()
	_done = false
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	add_child(_content)
	_content.add_child(UiTheme.label(title, 30, UiTheme.ACCENT))
	var sub := UiTheme.label(subtitle, 18, UiTheme.TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(520, 0)
	_content.add_child(sub)


func _center() -> void:
	await get_tree().process_frame
	var vp := get_viewport_rect().size
	position = (vp - size) * 0.5


# ------------------------------------------------------------------ Sicherungen

func open_lights(grid_size: int, seed_value: int, scramble: int) -> void:
	_lights = PuzzleLogic.LightsOut.new(grid_size, seed_value, scramble)
	_freq = null
	_reset("Verteilerkasten", "Jede Sicherung schaltet sich selbst und ihre direkten Nachbarn um. Bringe alle Sicherungen auf GRÜN.")
	var grid := GridContainer.new()
	grid.columns = grid_size
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	_content.add_child(cc)
	var cell_size := 84 if grid_size <= 3 else 70
	for i in grid_size * grid_size:
		var b := Button.new()
		b.custom_minimum_size = Vector2(cell_size, cell_size)
		b.pressed.connect(_on_cell.bind(i))
		grid.add_child(b)
		_cells.append(b)
	_moves = UiTheme.label("", 18, UiTheme.TEXT_DIM)
	_status = UiTheme.label("", 22)
	_content.add_child(_moves)
	_content.add_child(_status)
	_add_footer(true)
	_refresh_lights()
	visible = true
	_center()


func _on_cell(i: int) -> void:
	if _done or _lights == null:
		return
	_lights.press(i)
	_refresh_lights()
	if _lights.is_solved():
		_finish("Strom fließt wieder!")


func _refresh_lights() -> void:
	for i in _cells.size():
		var on: bool = _lights.cells[i]
		var sb := UiTheme.panel_style(Color(0.15, 0.75, 0.35) if on else Color(0.75, 0.18, 0.15), 10)
		var sbh := sb.duplicate()
		sbh.bg_color = sb.bg_color.lightened(0.15)
		_cells[i].add_theme_stylebox_override("normal", sb)
		_cells[i].add_theme_stylebox_override("hover", sbh)
		_cells[i].add_theme_stylebox_override("pressed", sbh)
		_cells[i].text = "AN" if on else "AUS"
	_moves.text = "Schaltvorgänge: %d   ·   Grün: %d/%d" % [_lights.moves, _lights.lit_count(), _cells.size()]


func _hint() -> void:
	if _lights:
		var h := _lights.hint()
		if h >= 0:
			_status.text = "Tipp: Versuch die markierte Sicherung."
			_cells[h].grab_focus()
	elif _freq:
		_status.text = "Tipp: Erst die Frequenz grob einstellen, dann die Phase feinjustieren."


# ------------------------------------------------------------------ Frequenz

func open_frequency(seed_value: int) -> void:
	_freq = PuzzleLogic.Frequency.new(seed_value)
	_lights = null
	_reset("Funk-Peilung", "Stelle Frequenz und Phase so ein, dass deine Welle (orange) das Störsignal (blau) überdeckt.")
	_wave = Control.new()
	_wave.custom_minimum_size = Vector2(520, 130)
	_wave.draw.connect(_draw_wave)
	_content.add_child(_wave)
	_freq_label = UiTheme.label("", 20)
	_content.add_child(_freq_label)
	_freq_slider = HSlider.new()
	_freq_slider.min_value = PuzzleLogic.Frequency.MIN_FREQ
	_freq_slider.max_value = PuzzleLogic.Frequency.MAX_FREQ
	_freq_slider.step = 0.1
	_freq_slider.custom_minimum_size = Vector2(0, 40)
	_freq_slider.value_changed.connect(func(_v): _on_freq_changed())
	_content.add_child(_freq_slider)
	_content.add_child(UiTheme.label("Phase", 18, UiTheme.TEXT_DIM))
	_phase_slider = HSlider.new()
	_phase_slider.min_value = 0
	_phase_slider.max_value = 355
	_phase_slider.step = 5
	_phase_slider.custom_minimum_size = Vector2(0, 40)
	_phase_slider.value_changed.connect(func(_v): _on_freq_changed())
	_content.add_child(_phase_slider)
	_strength_bar = ProgressBar.new()
	_strength_bar.custom_minimum_size = Vector2(0, 22)
	_strength_bar.max_value = 100
	_content.add_child(_strength_bar)
	_status = UiTheme.label("", 22)
	_content.add_child(_status)
	_add_footer(true)
	_on_freq_changed()
	visible = true
	_center()


func _on_freq_changed() -> void:
	if _freq == null or _done:
		return
	_freq.set_values(_freq_slider.value, _phase_slider.value)
	var st := _freq.strength()
	_strength_bar.value = st * 100.0
	_freq_label.text = "Frequenz: %.1f MHz   ·   Phase: %d°   ·   Signal: %d %%" % [_freq.freq, int(_freq.phase), int(st * 100)]
	_wave.queue_redraw()
	if _freq.is_solved():
		_finish("Sender identifiziert! Daten werden aufgezeichnet...")


func _draw_wave() -> void:
	var s := _wave.size
	_wave.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.05, 0.07))
	for k in [0.25, 0.5, 0.75]:
		_wave.draw_line(Vector2(0, s.y * k), Vector2(s.x, s.y * k), Color(1, 1, 1, 0.06))
	var target := PackedVector2Array()
	var mine := PackedVector2Array()
	for i in 121:
		var x := float(i) / 120.0
		var ty := sin(x * TAU * (_freq.target_freq / 20.0) + deg_to_rad(_freq.target_phase))
		var my := sin(x * TAU * (_freq.freq / 20.0) + deg_to_rad(_freq.phase))
		target.append(Vector2(x * s.x, s.y * 0.5 - ty * s.y * 0.38))
		mine.append(Vector2(x * s.x, s.y * 0.5 - my * s.y * 0.38))
	_wave.draw_polyline(target, Color(0.3, 0.7, 1.0, 0.9), 3.0, true)
	_wave.draw_polyline(mine, Color(1.0, 0.6, 0.2, 0.9), 2.0, true)


# ------------------------------------------------------------------ Gemeinsam

func _add_footer(with_hint: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	if with_hint:
		row.add_child(UiTheme.button("Tipp", _hint, Vector2(120, 56)))
	row.add_child(UiTheme.button("Abbrechen", _cancel, Vector2(160, 56)))
	_content.add_child(row)


func _finish(msg: String) -> void:
	_done = true
	_status.text = msg
	_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	await get_tree().create_timer(1.2).timeout
	visible = false
	solved.emit()


func _cancel() -> void:
	visible = false
	cancelled.emit()


## Für automatisierte Tests: Rätsel direkt lösen.
func debug_solve() -> void:
	if _lights:
		for i in _lights.solution():
			_on_cell(int(i))
	elif _freq:
		_freq_slider.value = _freq.target_freq
		_phase_slider.value = _freq.target_phase
