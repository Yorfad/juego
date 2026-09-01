extends Control
## Menu principal. Tres ranuras independientes; cada una es el autoguardado de
## su propia partida. Todo construido por codigo, mismo estilo que hud.gd.

const WORLD := "res://scenes/world.tscn"
const SLOTS := 3

@onready var _root: Control = self


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "PUESTO FRONTERIZO"
	col.add_child(title)

	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 15)
	sub.modulate = Color(0.7, 0.7, 0.75)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.text = "turno de noche"
	col.add_child(sub)

	col.add_child(_spacer(18))

	for slot in range(1, SLOTS + 1):
		col.add_child(_slot_button(slot))

	col.add_child(_spacer(10))

	var opt := _button("Opciones")
	opt.pressed.connect(_open_options)
	col.add_child(opt)

	var quit := _button("Salir")
	quit.pressed.connect(_quit)
	col.add_child(quit)


func _quit() -> void:
	get_tree().quit()


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 44)
	return b


func _slot_button(slot: int) -> Button:
	var info := GameState.slot_info(slot)
	var b := _button("")
	b.custom_minimum_size = Vector2(380, 52)
	if info.is_empty():
		b.text = "Ranura %d  —  vacia" % slot
	else:
		b.text = "Ranura %d  —  Dia %d · $%d · Nervio %d" % [
			slot, int(info.get("day", 1)), int(info.get("cash", 0)), int(info.get("nerve", 0))]
	b.pressed.connect(_on_slot.bind(slot, not info.is_empty()))
	return b


func _on_slot(slot: int, occupied: bool) -> void:
	if occupied:
		_slot_menu(slot)
	else:
		_start(slot)


func _slot_menu(slot: int) -> void:
	var ov := _overlay()
	var col: VBoxContainer = ov.get_meta("col")

	var t := Label.new()
	t.add_theme_font_size_override("font_size", 20)
	t.text = "Ranura %d" % slot
	col.add_child(t)

	var cont := _button("Continuar")
	cont.pressed.connect(_continue_slot.bind(slot, ov))
	col.add_child(cont)

	var neu := _button("Partida nueva (borra esta)")
	neu.pressed.connect(_new_from_menu.bind(slot, ov))
	col.add_child(neu)

	var back := _button("Volver")
	back.pressed.connect(ov.queue_free)
	col.add_child(back)


func _continue_slot(slot: int, ov: Control) -> void:
	ov.queue_free()
	if GameState.load_run(slot):
		get_tree().change_scene_to_file(WORLD)


func _new_from_menu(slot: int, ov: Control) -> void:
	ov.queue_free()
	_confirm_new(slot)


func _confirm_new(slot: int) -> void:
	var ov := _overlay()
	var col: VBoxContainer = ov.get_meta("col")

	var t := Label.new()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(360, 0)
	t.text = "Se borra la partida de la ranura %d y empiezas de cero. Seguro?" % slot
	col.add_child(t)

	var yes := _button("Si, empezar de nuevo")
	yes.pressed.connect(_confirm_new_yes.bind(slot, ov))
	col.add_child(yes)

	var no := _button("Cancelar")
	no.pressed.connect(ov.queue_free)
	col.add_child(no)


func _confirm_new_yes(slot: int, ov: Control) -> void:
	ov.queue_free()
	_start(slot)


func _start(slot: int) -> void:
	GameState.start_new_run(slot)
	get_tree().change_scene_to_file(WORLD)


func _open_options() -> void:
	var op = preload("res://scripts/options_panel.gd").new()
	_root.add_child(op)
	await op.closed
	op.queue_free()


func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	center.add_child(box)

	var pad := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(s, 24)
	box.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)

	o.set_meta("col", col)
	_root.add_child(o)
	return o
