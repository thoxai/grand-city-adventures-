class_name TuningPanel
extends PanelContainer
## Werkstatt-Menü: Motor, Reifen, Nitro und Lackierung kaufen.

signal closed

var car: Car
var _box: VBoxContainer


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(620, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(p_car: Car) -> void:
	car = p_car
	_rebuild()
	visible = true
	await get_tree().process_frame
	position = (get_viewport_rect().size - size) * 0.5


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	var t := GameState.get_tuning(car.car_id)
	var stats := TuningData.compute_stats(car.car_id, t)
	_box.add_child(UiTheme.label("Kenjis Werkstatt – %s" % car.display_name(), 28, UiTheme.ACCENT))
	_box.add_child(UiTheme.label("Guthaben: %d €" % GameState.money, 20, UiTheme.TEXT_DIM))
	_stat("Höchstgeschwindigkeit", "%d km/h" % TuningData.kmh(stats["top_speed"]), stats["top_speed"] / 60.0)
	_stat("Beschleunigung", "%.1f m/s²" % stats["accel"], stats["accel"] / 20.0)
	_stat("Grip", "%.1f" % stats["grip"], stats["grip"] / 12.0)
	_stat("Nitro", ("%.0f s Boost" % stats["nitro_capacity"]) if stats["nitro_capacity"] > 0 else "nicht verbaut", stats["nitro_capacity"] / 5.0)
	for cat in ["engine", "tires", "nitro"]:
		var lvl := int(t.get(cat, 0))
		var cost := TuningData.upgrade_cost(cat, lvl)
		var label := "%s  –  Stufe %d/%d" % [TuningData.CATEGORY_NAMES[cat], lvl, TuningData.MAX_LEVEL[cat]]
		var btn_text := "MAX" if cost < 0 else "Upgrade: %d €" % cost
		var row := HBoxContainer.new()
		var l := UiTheme.label(label, 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UiTheme.button(btn_text, _buy.bind(cat), Vector2(200, 52))
		b.disabled = cost < 0 or not GameState.can_afford(cost)
		row.add_child(b)
		_box.add_child(row)
	_box.add_child(UiTheme.label("Lackierung (%d €)" % TuningData.PAINT_COST, 20))
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 8)
	var cols: Array = TuningData.base_spec(car.car_id)["colors"]
	for i in cols.size():
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(64, 52)
		var sb := UiTheme.panel_style(cols[i], 10, Color.WHITE if i == int(t.get("color", 0)) else Color(1, 1, 1, 0.1))
		sb.set_border_width_all(3 if i == int(t.get("color", 0)) else 1)
		cb.add_theme_stylebox_override("normal", sb)
		cb.add_theme_stylebox_override("hover", sb)
		cb.add_theme_stylebox_override("pressed", sb)
		cb.pressed.connect(_paint.bind(i))
		colors.add_child(cb)
	_box.add_child(colors)
	var close := UiTheme.button("Fertig", _close, Vector2(0, 56))
	_box.add_child(close)


func _stat(name_text: String, value: String, ratio: float) -> void:
	var row := HBoxContainer.new()
	var l := UiTheme.label(name_text, 18, UiTheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var v := UiTheme.label("  " + value, 18)
	row.add_child(v)
	_box.add_child(row)


## Kauft die nächste Stufe einer Kategorie. Gibt true bei Erfolg zurück.
func buy(cat: String) -> bool:
	var t := GameState.get_tuning(car.car_id)
	var lvl := int(t.get(cat, 0))
	var cost := TuningData.upgrade_cost(cat, lvl)
	if cost < 0 or not GameState.spend(cost):
		return false
	GameState.set_tuning_value(car.car_id, cat, lvl + 1)
	car.apply_tuning()
	return true


func _buy(cat: String) -> void:
	if buy(cat):
		GameState.notify.emit("%s verbessert!" % TuningData.CATEGORY_NAMES[cat])
	_rebuild()


func _paint(i: int) -> void:
	var t := GameState.get_tuning(car.car_id)
	if int(t.get("color", 0)) == i:
		return
	if GameState.spend(TuningData.PAINT_COST):
		GameState.set_tuning_value(car.car_id, "color", i)
		car.apply_tuning()
	_rebuild()


func _close() -> void:
	visible = false
	closed.emit()
