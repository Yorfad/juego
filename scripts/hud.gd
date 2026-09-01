extends CanvasLayer
## HUD: medidores y equipo con barras y color, panel de decisiones, mira,
## prompt de "[E]" y avisos. Todo por codigo.

signal panel_selected(data)

const C_TEXT   := Color(0.93, 0.93, 0.96)
const C_DIM    := Color(0.62, 0.62, 0.70)
const C_ACCENT := Color(0.90, 0.74, 0.42)
const C_PANEL  := Color(0.10, 0.10, 0.13, 0.82)
const C_GOOD   := Color(0.36, 0.78, 0.46)
const C_WARN   := Color(0.93, 0.71, 0.24)
const C_BAD    := Color(0.88, 0.30, 0.26)

const METERS := [
	["loyalty", "LEALTAD"],
	["command_suspicion", "SOSPECHA"],
	["cartel_pressure", "CARTEL"],
	["nerve", "NERVIO"],
]

var _prompt: Label
var _objective: Label
var _toast: Label
var _toast_t := 0.0

var _cash_val: Label
var _meter_rows := {}     # key -> {bar, fill, val}
var _crew_rows := {}      # id  -> {bar, fill, val}

var _overlay: Control
var _title: Label
var _body: RichTextLabel
var _choices: VBoxContainer


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_overlay()


# --------------------------------------------------------------- helpers UI
func _flat(bg: Color, radius: int = 6, border_top: int = 0, border_col: Color = C_ACCENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_top > 0:
		sb.border_width_top = border_top
		sb.border_color = border_col
	return sb


func _label(txt: String, sz: int, col: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _bar(h: int = 13) -> Dictionary:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, h)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_GOOD
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return {"bar": bar, "fill": fill}


func _stat_panel(min_w: int) -> Array:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", _flat(C_PANEL, 6, 2, C_ACCENT))
	pc.custom_minimum_size = Vector2(min_w, 0)
	var mc := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(s, 12)
	pc.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	mc.add_child(vb)
	return [pc, vb]


func _stat_row(vb: VBoxContainer, name_txt: String, name_w: int, val_w: int) -> Dictionary:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var nm := _label(name_txt, 13, C_DIM)
	nm.custom_minimum_size = Vector2(name_w, 0)
	hb.add_child(nm)
	var b := _bar()
	hb.add_child(b["bar"])
	var val := _label("0", 14, C_TEXT)
	val.custom_minimum_size = Vector2(val_w, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val)
	vb.add_child(hb)
	return {"bar": b["bar"], "fill": b["fill"], "val": val}


# ------------------------------------------------------------------ layout
func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Columna izquierda: medidores + equipo apilados
	var left_col := VBoxContainer.new()
	left_col.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_col.offset_left = 14
	left_col.offset_top = 14
	left_col.add_theme_constant_override("separation", 10)
	root.add_child(left_col)

	var sp := _stat_panel(270)
	left_col.add_child(sp[0])
	var mvb: VBoxContainer = sp[1]

	var cash_hb := HBoxContainer.new()
	var cash_lbl := _label("CAJA", 13, C_DIM)
	cash_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_hb.add_child(cash_lbl)
	_cash_val = _label("$0", 19, C_ACCENT)
	cash_hb.add_child(_cash_val)
	mvb.add_child(cash_hb)
	mvb.add_child(HSeparator.new())
	for pair in METERS:
		_meter_rows[pair[0]] = _stat_row(mvb, pair[1], 80, 34)

	var cp := _stat_panel(270)
	left_col.add_child(cp[0])
	var cvb: VBoxContainer = cp[1]
	cvb.add_child(_label("EQUIPO", 12, C_DIM))
	for c in GameState.crew_defs:
		var cid := str(c.get("id", ""))
		var nm := str(c.get("name", cid))
		_crew_rows[cid] = _stat_row(cvb, nm.substr(nm.rfind(" ") + 1), 58, 58)

	# Objetivo (arriba-centro)
	_objective = _label("", 15, C_DIM)
	_objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.offset_top = 16
	root.add_child(_objective)

	# Mira
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2
	root.add_child(dot)

	# Prompt [E] + avisos (abajo-centro)
	_prompt = _label("", 18, C_ACCENT)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -92
	_prompt.offset_bottom = -60
	root.add_child(_prompt)

	_toast = _label("", 17, C_TEXT)
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_top = -138
	_toast.offset_bottom = -110
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.12, 0.15, 0.98), 8, 3, C_ACCENT))
	center.add_child(box)

	var pad := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(s, 34)
	box.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	pad.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", C_ACCENT)
	col.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(692, 0)
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("italics_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 17)
	_body.add_theme_color_override("default_color", C_TEXT)
	col.add_child(_body)

	col.add_child(HSeparator.new())

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	col.add_child(_choices)


# ------------------------------------------------------------------- API HUD
func set_prompt(t: String) -> void:
	_prompt.text = t


func clear_prompt() -> void:
	_prompt.text = ""


func set_objective(t: String) -> void:
	_objective.text = t


func toast(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.0
	_toast_t = 3.0


func refresh_meters() -> void:
	var m: Dictionary = GameState.meters
	var cash := int(m.get("cash", 0))
	_cash_val.text = ("-$%d" % absi(cash)) if cash < 0 else ("$%d" % cash)
	_cash_val.add_theme_color_override("font_color", C_BAD if cash < 0 else C_ACCENT)
	for key in _meter_rows.keys():
		var row: Dictionary = _meter_rows[key]
		var v := int(m.get(key, 0))
		row["val"].text = str(v)
		row["fill"].bg_color = _danger_color(str(key), v)
		create_tween().tween_property(row["bar"], "value", float(v), 0.22)
	refresh_crew()


func _danger_color(key: String, v: int) -> Color:
	var d := (1.0 - v / 100.0) if (key == "loyalty" or key == "nerve") else (v / 100.0)
	if d >= 0.80:
		return C_BAD
	if d >= 0.58:
		return C_WARN
	return C_GOOD


func refresh_crew() -> void:
	for id in _crew_rows.keys():
		var sid := str(id)
		var row: Dictionary = _crew_rows[id]
		var t := GameState.trust_of(sid)
		var band := GameState.trust_band(sid)
		row["fill"].bg_color = C_GOOD if band == "loyal" else (C_BAD if band == "hostile" else C_DIM)
		var order := str(GameState.crew_order.get(sid, ""))
		row["val"].text = ("%d %s" % [t, order.left(3)]) if order != "" else str(t)
		create_tween().tween_property(row["bar"], "value", float(t), 0.22)


func show_panel(title: String, body: String, options: Array) -> void:
	_title.text = title
	_title.visible = title != ""
	_body.text = body
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	for opt in options:
		var b := Button.new()
		b.text = str(opt.get("label", ""))
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", _btn_sb(Color(0.16, 0.16, 0.20)))
		b.add_theme_stylebox_override("hover", _btn_sb(Color(0.24, 0.22, 0.17)))
		b.add_theme_stylebox_override("pressed", _btn_sb(Color(0.30, 0.26, 0.16)))
		b.add_theme_stylebox_override("focus", _btn_sb(Color(0.24, 0.22, 0.17)))
		b.add_theme_color_override("font_color", C_TEXT)
		b.add_theme_color_override("font_hover_color", C_ACCENT)
		if "autowrap_mode" in b:
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_pick.bind(opt.get("data", null)))
		_choices.add_child(b)
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.12)


func _btn_sb(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	return sb


func _pick(data: Variant) -> void:
	_overlay.visible = false
	panel_selected.emit(data)


## Abre el panel de opciones encima de todo y espera a que se cierre.
func open_options() -> void:
	var op = preload("res://scripts/options_panel.gd").new()
	add_child(op)
	await op.closed
	op.queue_free()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 1.0:
			_toast.modulate.a = maxf(_toast_t, 0.0)
		if _toast_t <= 0.0:
			_toast.text = ""
