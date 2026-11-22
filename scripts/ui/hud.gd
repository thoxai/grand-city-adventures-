class_name Hud
extends CanvasLayer
## Komplettes Spiel-UI: HUD, Minikarte, Touch-Steuerung, Dialoge, Menüs.
## Alles wird im Code aufgebaut, damit es ohne Editor-Assets lauffähig ist.

var main: Node
var root: Control
var touch: TouchControls
var minimap: Minimap
var puzzle_panel: PuzzlePanel
var tuning_panel: TuningPanel

var _money: Label
var _clock: Label
var _obj_title: Label
var _obj_text: Label
var _timer: Label
var _toast: Label
var _toast_time := 0.0
var _prompt: Label
var _speed: Label
var _nitro_bar: ProgressBar
var _fps: Label
var _pause_btn: Button
var _tuning_btn: Button
var _hud_layer: Control

var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _dialog_lines: Array = []
var _dialog_index := 0
var _dialog_done: Callable
var _dialog_open_frame := -1

var _start_menu: Control
var _continue_btn: Button
var _pause_menu: Control
var _abort_btn: Button
var _quality_btn: Button
var _complete_panel: PanelContainer
var _complete_title: Label
var _complete_text: Label
var _complete_reward: Label
var _complete_done: Callable


func setup(p_main: Node) -> void:
	main = p_main
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "UIRoot"
	root.theme = UiTheme.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_dialog()
	_build_complete_panel()
	puzzle_panel = PuzzlePanel.new()
	root.add_child(puzzle_panel)
	tuning_panel = TuningPanel.new()
	root.add_child(tuning_panel)
	_build_pause_menu()
	_build_start_menu()
	GameState.money_changed.connect(func(m): _money.text = "%d €" % m)
	GameState.notify.connect(toast)
	_money.text = "%d €" % GameState.money


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	_hud_layer = Control.new()
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud_layer)

	touch = TouchControls.new()
	_hud_layer.add_child(touch)
	touch.camera_drag.connect(_on_camera_drag)

	# Oben links: Geld, Uhr, Missionsziel
	var info := PanelContainer.new()
	info.position = Vector2(16, 16)
	info.custom_minimum_size = Vector2(420, 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(info)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	info.add_child(vb)
	var top := HBoxContainer.new()
	_money = UiTheme.label("0 €", 26, Color(0.55, 1.0, 0.6))
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_money)
	_clock = UiTheme.label("08:00", 26)
	top.add_child(_clock)
	vb.add_child(top)
	_obj_title = UiTheme.label("", 20, UiTheme.ACCENT)
	vb.add_child(_obj_title)
	_obj_text = UiTheme.label("", 18)
	_obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_text.custom_minimum_size = Vector2(390, 0)
	vb.add_child(_obj_text)

	# Oben rechts: Minikarte + Pause
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(210, 210)
	minimap.size = Vector2(210, 210)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-226, 16)
	_hud_layer.add_child(minimap)
	_pause_btn = UiTheme.button("II", toggle_pause, Vector2(64, 64))
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.position = Vector2(-306, 16)
	_hud_layer.add_child(_pause_btn)
	_fps = UiTheme.label("", 16, UiTheme.TEXT, true)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.position = Vector2(-226, 232)
	_hud_layer.add_child(_fps)

	# Mitte oben: Timer und Meldungen
	_timer = UiTheme.label("", 44, Color(1, 0.9, 0.4), true)
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.position = Vector2(-100, 18)
	_timer.custom_minimum_size = Vector2(200, 0)
	_hud_layer.add_child(_timer)
	_toast = UiTheme.label("", 24, UiTheme.TEXT, true)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(560, 0)
	_toast.position = Vector2(-280, 84)
	_hud_layer.add_child(_toast)

	# Unten Mitte: Interaktionshinweis, Tacho
	_prompt = UiTheme.label("", 22, Color(1, 1, 1), true)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.position = Vector2(-300, -200)
	_hud_layer.add_child(_prompt)
	_speed = UiTheme.label("", 40, UiTheme.TEXT, true)
	_speed.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.custom_minimum_size = Vector2(240, 0)
	_speed.position = Vector2(-120, -110)
	_hud_layer.add_child(_speed)
	_nitro_bar = ProgressBar.new()
	_nitro_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_nitro_bar.custom_minimum_size = Vector2(200, 12)
	_nitro_bar.size = Vector2(200, 12)
	_nitro_bar.position = Vector2(-100, -50)
	_nitro_bar.max_value = 1.0
	_nitro_bar.show_percentage = false
	_nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_nitro_bar)
	_tuning_btn = UiTheme.button("Tuning öffnen (T)", _on_tuning_pressed, Vector2(260, 60))
	_tuning_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tuning_btn.position = Vector2(-130, -280)
	_tuning_btn.visible = false
	_hud_layer.add_child(_tuning_btn)
	set_vehicle_mode(false)


func _on_camera_drag(rel: Vector2) -> void:
	if main and main.camera_rig:
		main.camera_rig.rotate_by(rel * 1.4)


func _on_tuning_pressed() -> void:
	if main:
		main.open_tuning()


func _process(delta: float) -> void:
	_clock.text = GameState.clock_string()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	_fps.visible = GameState.show_fps
	if GameState.show_fps:
		_fps.text = "%d FPS · %d Draw-Calls" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	if _dialog.visible and Engine.get_process_frames() != _dialog_open_frame and Input.is_action_just_pressed("interact"):
		_advance_dialog()
	if Input.is_action_just_pressed("pause") and not _start_menu.visible:
		if tuning_panel.visible:
			tuning_panel._close()
		elif puzzle_panel.visible:
			puzzle_panel._cancel()
		else:
			toggle_pause()


func set_objective(title: String, text: String) -> void:
	_obj_title.text = title
	_obj_text.text = text


func set_timer(seconds: float) -> void:
	if seconds < 0.0:
		_timer.text = ""
	else:
		_timer.text = "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]
		_timer.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if seconds < 10.0 else Color(1, 0.9, 0.4))


func toast(text: String, duration: float = 3.5) -> void:
	_toast.text = text
	_toast_time = duration
	_toast.modulate.a = 1.0


func set_prompt(text: String) -> void:
	_prompt.text = text
	var b := touch.get_button("interact")
	if b:
		b.set_highlight(text != "")


func set_vehicle_mode(in_car: bool) -> void:
	touch.set_mode("car" if in_car else "foot")
	_speed.visible = in_car
	_nitro_bar.visible = false


func update_speed(kmh: int, nitro_ratio: float, has_nitro: bool) -> void:
	_speed.text = "%d km/h" % kmh
	_nitro_bar.visible = has_nitro
	_nitro_bar.value = nitro_ratio
	var nb := touch.get_button("nitro", "car")
	if nb:
		nb.visible = has_nitro and touch.mode == "car"


func set_tuning_available(v: bool) -> void:
	_tuning_btn.visible = v and not any_menu_open()


func any_menu_open() -> bool:
	return _dialog.visible or _start_menu.visible or _pause_menu.visible or puzzle_panel.visible or tuning_panel.visible or _complete_panel.visible


func set_hud_visible(v: bool) -> void:
	_hud_layer.visible = v


func _update_touch_visibility() -> void:
	touch.visible = not any_menu_open()
	if not touch.visible:
		touch.release_all()


# ------------------------------------------------------------------ Dialog

func _build_dialog() -> void:
	_dialog = PanelContainer.new()
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.custom_minimum_size = Vector2(760, 170)
	_dialog.position = Vector2(-380, -200)
	_dialog.visible = false
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_advance_dialog())
	root.add_child(_dialog)
	var vb := VBoxContainer.new()
	_dialog.add_child(vb)
	_dialog_name = UiTheme.label("", 24, UiTheme.ACCENT)
	vb.add_child(_dialog_name)
	_dialog_text = UiTheme.label("", 22)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(720, 70)
	vb.add_child(_dialog_text)
	var hint := UiTheme.label("Tippen oder [E] – weiter", 16, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)


func show_dialog(lines: Array, on_done: Callable = Callable()) -> void:
	_dialog_lines = lines
	_dialog_index = 0
	_dialog_done = on_done
	_dialog_open_frame = Engine.get_process_frames()
	_dialog.visible = true
	_show_dialog_line()
	_update_touch_visibility()


func is_dialog_open() -> bool:
	return _dialog.visible


func _show_dialog_line() -> void:
	var l: Array = _dialog_lines[_dialog_index]
	_dialog_name.text = l[0]
	_dialog_text.text = l[1]


func _advance_dialog() -> void:
	if not _dialog.visible:
		return
	_dialog_index += 1
	if _dialog_index >= _dialog_lines.size():
		finish_dialog()
	else:
		_show_dialog_line()


func finish_dialog() -> void:
	_dialog.visible = false
	_update_touch_visibility()
	if _dialog_done.is_valid():
		var cb := _dialog_done
		_dialog_done = Callable()
		cb.call()


# ------------------------------------------------------------------ Rätsel / Tuning

func open_puzzle(step: Dictionary, on_solved: Callable, on_cancel: Callable) -> void:
	for c in puzzle_panel.solved.get_connections():
		puzzle_panel.solved.disconnect(c["callable"])
	for c in puzzle_panel.cancelled.get_connections():
		puzzle_panel.cancelled.disconnect(c["callable"])
	puzzle_panel.solved.connect(func():
		_update_touch_visibility()
		on_solved.call(), CONNECT_ONE_SHOT)
	puzzle_panel.cancelled.connect(func():
		_update_touch_visibility()
		on_cancel.call(), CONNECT_ONE_SHOT)
	if step.get("puzzle", "") == "frequency":
		puzzle_panel.open_frequency(int(step.get("seed", 1)))
	else:
		puzzle_panel.open_lights(int(step.get("size", 3)), int(step.get("seed", 1)), int(step.get("scramble", 4)))
	_update_touch_visibility()


func open_tuning(car: Car, on_close: Callable) -> void:
	for c in tuning_panel.closed.get_connections():
		tuning_panel.closed.disconnect(c["callable"])
	tuning_panel.closed.connect(func():
		_update_touch_visibility()
		on_close.call(), CONNECT_ONE_SHOT)
	tuning_panel.open(car)
	_tuning_btn.visible = false
	_update_touch_visibility()


# ------------------------------------------------------------------ Missionsabschluss

func _build_complete_panel() -> void:
	_complete_panel = PanelContainer.new()
	_complete_panel.set_anchors_preset(Control.PRESET_CENTER)
	_complete_panel.custom_minimum_size = Vector2(620, 0)
	_complete_panel.position = Vector2(-310, -170)
	_complete_panel.visible = false
	root.add_child(_complete_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_complete_panel.add_child(vb)
	var head := UiTheme.label("MISSION ABGESCHLOSSEN", 34, UiTheme.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	_complete_title = UiTheme.label("", 26)
	_complete_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_complete_title)
	_complete_text = UiTheme.label("", 20, UiTheme.TEXT_DIM)
	_complete_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_complete_text.custom_minimum_size = Vector2(580, 0)
	vb.add_child(_complete_text)
	_complete_reward = UiTheme.label("", 26, Color(0.55, 1.0, 0.6))
	_complete_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_complete_reward)
	vb.add_child(UiTheme.button("Weiter", _close_complete))


func show_mission_complete(mission: Dictionary, progress_text: String, on_close: Callable = Callable()) -> void:
	_complete_title.text = "„%s“" % mission["title"]
	_complete_text.text = MissionData.fill(str(mission.get("outro", "")))
	var reward := "Belohnung: +%d €" % int(mission["reward"])
	if mission.has("unlock_car"):
		reward += "  ·  Neues Auto: %s" % TuningData.base_spec(mission["unlock_car"])["name"]
	_complete_reward.text = reward + "\n" + progress_text
	_complete_done = on_close
	_complete_panel.visible = true
	_update_touch_visibility()


func _close_complete() -> void:
	_complete_panel.visible = false
	_update_touch_visibility()
	if _complete_done.is_valid():
		_complete_done.call()


func is_complete_panel_open() -> bool:
	return _complete_panel.visible


func close_complete_panel() -> void:
	_close_complete()


# ------------------------------------------------------------------ Menüs

func _fullscreen_dim(alpha: float) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, alpha)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _build_start_menu() -> void:
	_start_menu = _fullscreen_dim(0.45)
	root.add_child(_start_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_menu.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	cc.add_child(vb)
	var title := UiTheme.label("GRAND CITY ADVENTURES", 58, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)
	var sub := UiTheme.label("URBAN EDITION", 26, UiTheme.ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var tag := UiTheme.label("Rennen · Rätsel · Tuning · eine Stadtgeschichte – ganz ohne Waffen.", 18, UiTheme.TEXT_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cards)
	for id in ["alex", "mia"]:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(320, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var info: Dictionary = GameState.CHARACTERS[id]
		cv.add_child(UiTheme.label(info["name"], 30, UiTheme.ACCENT))
		var bio := UiTheme.label(info["bio"], 18, UiTheme.TEXT_DIM)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bio.custom_minimum_size = Vector2(280, 50)
		cv.add_child(bio)
		var b := UiTheme.button("Neues Spiel als %s" % info["name"], func(): _on_new_game(id))
		b.name = "NewGame_" + id
		cv.add_child(b)
		cards.add_child(card)
	_continue_btn = UiTheme.button("Weiterspielen", func():
		hide_start_menu()
		main.continue_game())
	vb.add_child(_continue_btn)
	_quality_btn = UiTheme.button("", _cycle_quality)
	vb.add_child(_quality_btn)
	_update_quality_text()
	var foot := UiTheme.label("Steuerung: Joystick links · Kamera wischen · Knöpfe rechts  |  PC: WASD, Maus rechts, E, Leertaste, Shift, N, T, Esc", 14, UiTheme.TEXT_DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(foot)


func _on_new_game(id: String) -> void:
	hide_start_menu()
	main.start_new_game(id)


func show_start_menu() -> void:
	_continue_btn.disabled = not SaveSystem.has_save()
	_start_menu.visible = true
	_pause_menu.visible = false
	set_hud_visible(false)
	_update_touch_visibility()


func hide_start_menu() -> void:
	_start_menu.visible = false
	set_hud_visible(true)
	_update_touch_visibility()


func is_start_menu_open() -> bool:
	return _start_menu.visible


func _build_pause_menu() -> void:
	_pause_menu = _fullscreen_dim(0.6)
	_pause_menu.visible = false
	root.add_child(_pause_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	cc.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var t := UiTheme.label("PAUSE", 36, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(UiTheme.button("Fortsetzen", toggle_pause))
	vb.add_child(UiTheme.button("Speichern", func():
		toast("Spiel gespeichert." if main.save_game() else "Speichern fehlgeschlagen!")))
	vb.add_child(UiTheme.button("Laden", func():
		toggle_pause()
		if not main.load_game():
			toast("Kein Spielstand vorhanden.")))
	vb.add_child(UiTheme.button("Figur wechseln (Alex/Mia)", func():
		main.switch_character()
		toast("Du spielst jetzt %s." % GameState.character_name())))
	var q := UiTheme.button("", _cycle_quality)
	q.name = "QualityPause"
	vb.add_child(q)
	vb.add_child(UiTheme.button("FPS-Anzeige an/aus", func(): GameState.show_fps = not GameState.show_fps))
	_abort_btn = UiTheme.button("Mission abbrechen", func():
		main.missions.abort()
		toggle_pause())
	vb.add_child(_abort_btn)
	vb.add_child(UiTheme.button("Hauptmenü", func():
		get_tree().paused = false
		main.return_to_menu()))


func toggle_pause() -> void:
	if _start_menu.visible:
		return
	_pause_menu.visible = not _pause_menu.visible
	get_tree().paused = _pause_menu.visible
	_abort_btn.visible = main.missions.is_active()
	_update_quality_text()
	_update_touch_visibility()


func is_paused() -> bool:
	return _pause_menu.visible


func _cycle_quality() -> void:
	var order := ["low", "medium", "high"]
	var i := order.find(GameState.quality)
	GameState.quality = order[(i + 1) % order.size()]
	main.apply_quality()
	_update_quality_text()


func _update_quality_text() -> void:
	var names := {"low": "Niedrig (Akku sparen)", "medium": "Mittel (empfohlen)", "high": "Hoch"}
	var txt := "Grafik: %s" % names.get(GameState.quality, "Mittel")
	if _quality_btn:
		_quality_btn.text = txt
	if _pause_menu:
		var q := _pause_menu.find_child("QualityPause", true, false) as Button
		if q:
			q.text = txt
