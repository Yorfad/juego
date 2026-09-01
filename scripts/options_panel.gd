extends Control
## Panel de opciones reutilizable (menu principal y menu de pausa).
## Se auto-construye por codigo, escribe en "Settings" al momento y emite
## "closed" al pulsar Volver. El que lo instancia debe hacer queue_free().

signal closed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)

	var pad := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(s, 28)
	box.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	pad.add_child(col)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.text = "Opciones"
	col.add_child(title)

	col.add_child(_slider_row("Sensibilidad del raton", 0.2, 3.0, 0.05,
		Settings.mouse_sensitivity, _set_sensitivity))
	col.add_child(_check_row("Invertir eje Y", Settings.invert_y, _set_invert_y))
	col.add_child(_check_row("Pantalla completa", Settings.fullscreen, _set_fullscreen))
	col.add_child(_slider_row("Volumen general", 0.0, 1.0, 0.05,
		Settings.master_volume, _set_volume))

	col.add_child(HSeparator.new())

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(_on_back)
	col.add_child(back)


# --- adaptadores a Settings (asi evitamos lambdas multilinea) ---
func _set_sensitivity(v: float) -> void:
	Settings.set_mouse_sensitivity(v)


func _set_volume(v: float) -> void:
	Settings.set_master_volume(v)


func _set_invert_y(v: bool) -> void:
	Settings.set_invert_y(v)


func _set_fullscreen(v: bool) -> void:
	Settings.set_fullscreen(v)


func _on_back() -> void:
	Settings.save_settings()
	closed.emit()


# --- filas de UI ---
func _slider_row(text: String, lo: float, hi: float, step: float, val: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)

	var num := Label.new()
	num.custom_minimum_size = Vector2(46, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.text = "%.2f" % val

	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(200, 0)
	s.value_changed.connect(_on_slider_changed.bind(num, on_change))

	row.add_child(s)
	row.add_child(num)
	return row


func _on_slider_changed(value: float, num: Label, on_change: Callable) -> void:
	num.text = "%.2f" % value
	on_change.call(value)


func _check_row(text: String, val: bool, on_change: Callable) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = val
	c.toggled.connect(on_change)
	return c
