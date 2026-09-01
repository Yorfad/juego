extends Node3D
## Prototipo 3D en primera persona. Monta el escenario en gris, el jugador, la
## ventanilla y la litera, y orquesta el flujo de turnos apoyandose en GameState.
## El contenido (situaciones) sigue viviendo en data/encounters.json.

var _player
var _hud
var _window
var _bed
var _door
var _visitor
var _visitor_spot := Vector3(0.0, 0.0, -4.9)

const ENV_MODEL_PATH := "res://models/environment.glb"
const EXT_MODEL_PATH := "res://models/exterior.glb"
var _env_model: PackedScene = null
var _ext_model: PackedScene = null

# --- companeros: grafo de puntos por el que rondan (dentro y fuera) ---
const WAYPOINTS := {
	"window":  Vector3(1.6, 0.1, -2.2),
	"desk":    Vector3(1.6, 0.1, 1.4),
	"bunk":    Vector3(-2.4, 0.1, 1.4),
	"center":  Vector3(0.2, 0.1, 0.3),
	"door_in": Vector3(0.5, 0.1, 3.1),
	"door":    Vector3(0.5, 0.1, 4.4),
	"yard":    Vector3(0.5, 0.1, 7.0),
	"rock":    Vector3(3.2, 0.1, 8.6),
	"side_w":  Vector3(-6.3, 0.1, 5.5),
	"side_e":  Vector3(6.3, 0.1, 5.5),
	"front_w": Vector3(-6.5, 0.1, -2.0),
	"front_e": Vector3(6.5, 0.1, -2.0),
	"road":    Vector3(0.0, 0.1, -6.3),
	"gate_w":  Vector3(-6.8, 0.1, -6.2),
	"gate_e":  Vector3(6.8, 0.1, -6.2),
}
const LINKS := {
	"window":  ["center", "desk"],
	"desk":    ["window", "center", "bunk"],
	"bunk":    ["desk", "center"],
	"center":  ["window", "desk", "bunk", "door_in"],
	"door_in": ["center", "door"],
	"door":    ["door_in", "yard"],
	"yard":    ["door", "side_w", "side_e"],
	"rock":    ["side_e"],
	"side_w":  ["yard", "front_w"],
	"side_e":  ["yard", "rock", "front_e"],
	"front_w": ["side_w", "gate_w"],
	"front_e": ["side_e", "gate_e"],
	"gate_w":  ["front_w", "road"],
	"gate_e":  ["front_e", "road"],
	"road":    ["gate_w", "gate_e"],
}
const COVER := ["desk", "bunk", "rock", "yard", "gate_w"]

var _companions := {}      # id -> CharacterBody3D (companion.gd)
var _door_pivot: Node3D
var _door_shape: CollisionShape3D
var _door_open := true      # empieza abierta para que el equipo entre y salga

# --- trafico -----------------------------------------------------------
# Todo el trafico llega SIEMPRE desde el oeste, por el carril cercano a la
# caseta, y para justo enfrente de la ventanilla.
const VEHICLE_SCENES := {
	"sedan":  "res://models/vehicle_sedan.glb",
	"pickup": "res://models/vehicle_pickup.glb",
	"van":    "res://models/vehicle_van.glb",
	"truck":  "res://models/vehicle_truck.glb",
}
const VEHICLE_LANE_Z := -7.5      # carril cercano, dentro de la calzada
const VEHICLE_SPAWN_X := -22.0    # aparece por la izquierda (y retrocede aqui)
const VEHICLE_STOP_X := -0.3      # para centrado enfrente de la ventanilla
const VEHICLE_EXIT_X := 22.0      # sale por la derecha
const VEHICLE_Y := 0.05

var _gate_west     # Node del brazo de la talanquera oeste, con boom_gate.gd
var _gate_east     # Node del brazo de la talanquera este, con boom_gate.gd
var _vehicle        # Node3D del vehiculo actual, con vehicle.gd

var _busy := false
var _shift_running := false

const INTRO := "Eres el comandante de un puesto de registro en la frontera, turno de noche. Aguanta hasta el traslado sin que ningun medidor toque su limite.\n\nWASD para moverte, raton para mirar, Espacio para saltar, E para interactuar. Atiende la ventanilla, sal por la puerta trasera a estirar las piernas, y vigila a tu equipo: no todos estan de tu lado.\n\nNadie sale limpio de aqui: si te dejas comprar te delatan, y si eres intachable estorbas."


func _ready() -> void:
	if ResourceLoader.exists(ENV_MODEL_PATH):
		_env_model = load(ENV_MODEL_PATH)
	if ResourceLoader.exists(EXT_MODEL_PATH):
		_ext_model = load(EXT_MODEL_PATH)

	_build_room()          # colisiones (invisibles si hay modelo, cajas grises si no)
	_build_lights()

	if _env_model != null:
		var env: Node3D = _env_model.instantiate()
		env.name = "EnvironmentModel"
		add_child(env)
	if _ext_model != null:
		var ext: Node3D = _ext_model.instantiate()
		ext.name = "ExteriorModel"
		add_child(ext)
		_gate_west = ext.find_child("boom_arm_west", true, false)
		_gate_east = ext.find_child("boom_arm_east", true, false)
		if _gate_west != null:
			_gate_west.set_script(preload("res://scripts/boom_gate.gd"))
		if _gate_east != null:
			_gate_east.set_script(preload("res://scripts/boom_gate.gd"))

	_player = CharacterBody3D.new()
	_player.set_script(preload("res://scripts/player.gd"))
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.3, 2.4)

	_hud = CanvasLayer.new()
	_hud.set_script(preload("res://scripts/hud.gd"))
	add_child(_hud)

	_player.connect("looked_at", _on_looked_at)
	_player.connect("looked_away", _on_looked_away)
	_player.connect("pause_requested", _on_pause_requested)

	_window = _make_interactable(
		Vector3(1.7, 1.35, 0.16), Vector3(0.0, 1.55, -3.92),
		Color(0.40, 0.45, 0.50), "Atender la ventanilla")
	_window.connect("interacted", _on_window)

	_bed = _make_interactable(
		Vector3(1.1, 0.5, 2.1), Vector3(-3.2, 0.3, 1.8),
		Color(0.30, 0.26, 0.24), "Dormir y terminar el turno")
	_bed.set("enabled", false)
	_bed.connect("interacted", _on_bed)

	# Suelo exterior (colision) y puerta trasera abrible.
	_add_box(Vector3(300, 0.4, 300), Vector3(0, -0.30, 0), Color(0.5, 0.44, 0.32))
	_build_door()
	_spawn_companions()

	call_deferred("_begin")


# --------------------------------------------------------------- escenario
## Cuerpo estatico de colision. Solo dibuja la caja gris si NO hay modelo 3D
## cargado (asi el greybox sigue siendo jugable sin el .glb).
func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	if _env_model == null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		bm.material = mat
		mi.mesh = bm
		body.add_child(mi)
	body.position = pos
	add_child(body)


func _build_room() -> void:
	var wall := Color(0.32, 0.32, 0.36)
	var floor_c := Color(0.20, 0.19, 0.19)
	_add_box(Vector3(8, 0.2, 8), Vector3(0, -0.1, 0), floor_c)        # suelo
	_add_box(Vector3(8, 0.2, 8), Vector3(0, 3.0, 0), wall)            # techo
	_add_box(Vector3(0.2, 3.2, 8), Vector3(-4, 1.5, 0), wall)         # pared oeste
	_add_box(Vector3(0.2, 3.2, 8), Vector3(4, 1.5, 0), wall)          # pared este
	_add_box(Vector3(3.9, 3.2, 0.2), Vector3(-2.05, 1.5, 4), wall)    # trasera izq
	_add_box(Vector3(2.9, 3.2, 0.2), Vector3(2.55, 1.5, 4), wall)    # trasera der
	_add_box(Vector3(1.2, 1.0, 0.2), Vector3(0.5, 2.6, 4), wall)     # dintel puerta
	_add_box(Vector3(3.3, 3.2, 0.2), Vector3(-2.45, 1.5, -4), wall)   # frontal izq
	_add_box(Vector3(3.3, 3.2, 0.2), Vector3(2.45, 1.5, -4), wall)    # frontal der
	_add_box(Vector3(1.7, 1.0, 0.2), Vector3(0, 2.7, -4), wall)       # dintel
	_add_box(Vector3(1.7, 0.9, 0.55), Vector3(0, 0.45, -3.8), Color(0.25, 0.24, 0.26))  # repisa
	_add_box(Vector3(1.6, 0.9, 1.1), Vector3(2.7, 0.45, 2.6), Color(0.24, 0.23, 0.25))  # escritorio


func _build_lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.26)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.06, 0.07, 0.11)
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 140.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Luna: direccional que ilumina el desierto de noche.
	var moon_dir := DirectionalLight3D.new()
	moon_dir.rotation_degrees = Vector3(-40, 24, 0)
	moon_dir.light_color = Color(0.55, 0.62, 0.85)
	moon_dir.light_energy = 0.85
	moon_dir.shadow_enabled = false
	add_child(moon_dir)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.7, 0.5)
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 1.4
	lamp.omni_range = 8.0
	# Sombras dinamicas de OmniLight en el render GL Compatibility parpadean al
	# mover la camara. Apagadas hasta tener lightmaps horneados (fase de arte).
	lamp.shadow_enabled = false
	add_child(lamp)

	var moon := OmniLight3D.new()
	moon.position = Vector3(0, 2.0, -5.2)
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.7
	moon.omni_range = 7.0
	add_child(moon)


# ------------------------------------------------------------ interactuables
func _make_interactable(size: Vector3, pos: Vector3, color: Color, prompt: String, force_mesh: bool = false):
	var body := StaticBody3D.new()
	body.set_script(preload("res://scripts/interactable.gd"))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	# Con modelo 3D cargado el interactuable es solo colision (raycast de "E" +
	# prompt); sin modelo dibuja la caja de color como referencia del greybox.
	# force_mesh = siempre dibuja la caja (p. ej. la puerta, que no esta en el .glb).
	if _env_model == null or force_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		bm.material = mat
		mi.mesh = bm
		body.add_child(mi)
	body.position = pos
	body.set("prompt", prompt)
	add_child(body)
	return body


# ------------------------------------------------------------------ puerta
func _build_door() -> void:
	# Pivote (bisagra) en el borde izquierdo del hueco de la pared trasera.
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-0.05, 1.02, 3.92)
	add_child(_door_pivot)

	var leaf := StaticBody3D.new()
	_door_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.05, 1.98, 0.08)
	_door_shape.shape = bs
	_door_shape.position = Vector3(0.55, 0.0, 0.0)   # la hoja sale hacia +X del pivote
	leaf.add_child(_door_shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.24, 0.16)
	mat.roughness = 1.0
	bm.material = mat
	mi.mesh = bm
	mi.position = _door_shape.position
	leaf.add_child(mi)
	_door_pivot.add_child(leaf)

	# estado inicial (abierta)
	_door_shape.disabled = _door_open
	_door_pivot.rotation_degrees.y = -105.0 if _door_open else 0.0

	# Zona de "E" en el vano, alcanzable desde dentro y desde fuera.
	var zone = _make_interactable(
		Vector3(1.5, 2.0, 1.4), Vector3(0.5, 1.0, 3.92),
		Color(0, 0, 0), "Abrir / cerrar la puerta")
	zone.connect("interacted", _on_door)
	_door = zone


func _spawn_companions() -> void:
	var home: Vector3 = WAYPOINTS.get("center", Vector3(0, 0.2, 0))
	for c in GameState.crew_defs:
		var cid := str(c.get("id", ""))
		var body = CharacterBody3D.new()
		body.set_script(preload("res://scripts/companion.gd"))
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.height = 1.7
		cap.radius = 0.3
		col.shape = cap
		col.position.y = 0.9
		body.add_child(col)

		var glb := "res://models/crew_%s.glb" % cid
		if ResourceLoader.exists(glb):
			var scn = load(glb)
			body.add_child(scn.instantiate())
		else:
			var mi := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.height = 1.7
			cm.radius = 0.28
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.22, 0.24, 0.2)
			cm.material = m
			mi.mesh = cm
			mi.position.y = 0.9
			body.add_child(mi)

		add_child(body)
		body.global_position = home + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		body.set("prompt", "Hablar con " + GameState.crew_name(cid))
		body.setup(cid, GameState.crew_def(cid), _player, WAYPOINTS, LINKS, COVER, _companions_active)
		body.connect("interacted", _on_crew_interact.bind(cid))
		_companions[cid] = body


func _companions_active() -> bool:
	return _shift_running and not _busy


func _on_looked_at(node: Node) -> void:
	if node.has_method("interact") and bool(node.get("enabled")):
		_hud.set_prompt("[E] " + str(node.get("prompt")))
	else:
		_hud.clear_prompt()


func _on_looked_away() -> void:
	_hud.clear_prompt()


# ------------------------------------------------------------------ visitante
func _spawn_visitor(e: Dictionary) -> void:
	_clear_visitor()
	_visitor = Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.height = 1.7
	cm.radius = 0.28
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.15)
	cm.material = mat
	mi.mesh = cm
	mi.position.y = 0.9
	_visitor.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = str(e.get("speaker", ""))
	lbl.position.y = 2.05
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 64
	lbl.outline_size = 14
	lbl.pixel_size = 0.0038
	lbl.modulate = Color(0.9, 0.88, 0.8)
	_visitor.add_child(lbl)
	_visitor.position = _visitor_spot
	add_child(_visitor)


func _clear_visitor() -> void:
	if is_instance_valid(_visitor):
		_visitor.queue_free()
	_visitor = null


# --------------------------------------------------------------- flujo juego
## GameState ya viene preparado por el menu (start_new_run o load_run).
func _begin() -> void:
	_busy = false
	_shift_running = false
	_set_exit(false)
	_clear_visitor()
	_hud.refresh_meters()
	_hud.set_objective("")
	_player.set_movement_enabled(false)
	if GameState.resumed:
		_hud.show_panel("PUESTO FRONTERIZO — Dia %d" % GameState.day,
			"Retomas el turno donde lo dejaste.", [{"label": "Continuar", "data": "go"}])
	else:
		_hud.show_panel("PUESTO FRONTERIZO", INTRO, [{"label": "Empezar turno", "data": "start"}])
	await _hud.panel_selected
	_start_shift()


## Solo la litera se bloquea/desbloquea; la puerta esta siempre disponible.
func _set_exit(v: bool) -> void:
	_bed.set("enabled", v)


func _start_shift() -> void:
	_shift_running = true
	_busy = false
	_hud.refresh_meters()
	if GameState.has_next_encounter():
		_hud.set_objective("Atiende la ventanilla — %d en la fila" % GameState.shift_queue.size())
		_set_exit(false)
	else:
		_hud.set_objective("Turno cubierto. Duerme en la litera para terminar el dia.")
		_set_exit(true)
	GameState.save_run()
	_player.set_movement_enabled(true)


func _on_window(_p) -> void:
	if _busy or not _shift_running:
		return
	if not GameState.has_next_encounter():
		_hud.toast("No queda nadie en la fila. Ve a la litera.")
		return
	_busy = true
	var e := GameState.next_encounter()
	var vkind := str(e.get("vehicle", "sedan"))   # todo el trafico es en vehiculo

	_player.set_look_only()                        # puedes mirar, no andar
	_hud.set_objective("Un vehiculo se acerca por la carretera...")
	await _drive_in(vkind)
	_hud.set_objective("")
	_player.set_movement_enabled(false)            # bloquea todo para el panel

	var options: Array = []
	for ch in e.get("choices", []):
		options.append({"label": ch.get("label", ""), "data": ch})
	_hud.show_panel(str(e.get("speaker", "—")), str(e.get("text", "")), options)
	var choice: Variant = await _hud.panel_selected

	GameState.apply_choice(choice)
	_hud.refresh_meters()

	var fm := GameState.failed_meter()
	if fm != "":
		_game_over(fm)
		return

	_hud.show_panel("", "[i]%s[/i]%s%s" % [
			str(choice.get("result", "")), _crew_event_suffix(), _delta_suffix()],
		[{"label": "Continuar", "data": "ok"}])
	await _hud.panel_selected
	_hud.refresh_meters()

	_send_vehicle_off(choice)

	if GameState.has_next_encounter():
		_hud.set_objective("Atiende la ventanilla — %d en la fila" % GameState.shift_queue.size())
	else:
		_hud.set_objective("Turno cubierto. Duerme en la litera para terminar el dia.")
		_set_exit(true)
	GameState.save_run()
	_player.set_movement_enabled(true)
	_busy = false


# --------------------------------------------------------------- trafico
## El vehiculo aparece lejos por el oeste, abre la talanquera de entrada y
## avanza hasta pararse enfrente de la ventanilla. Si falta el modelo, no
## aparece nada (el encuentro sigue con solo el panel).
func _drive_in(vkind: String) -> void:
	_clear_vehicle()
	var path: String = VEHICLE_SCENES.get(vkind, VEHICLE_SCENES["sedan"])
	if not ResourceLoader.exists(path):
		return
	var scn = load(path)
	var v = scn.instantiate()
	v.set_script(preload("res://scripts/vehicle.gd"))
	add_child(v)

	v.rotation = Vector3.ZERO                       # morro hacia +X (avanza al este)
	v.global_position = Vector3(VEHICLE_SPAWN_X, VEHICLE_Y, VEHICLE_LANE_Z)
	_vehicle = v

	if _gate_west != null:
		_gate_west.set_open(true)                   # talanquera de entrada

	v.speed = 8.0
	v.drive_to(VEHICLE_STOP_X)
	await v.arrived


## Tras la decision: si no es un rechazo explicito, sube la talanquera de
## salida y el vehiculo sigue de largo; si lo es, retrocede por donde vino.
func _send_vehicle_off(choice: Variant) -> void:
	if not is_instance_valid(_vehicle):
		return
	var deny := choice is Dictionary and str((choice as Dictionary).get("gate_action", "pass")) == "deny"
	var v = _vehicle
	if deny:
		v.speed = 9.0
		v.drive_to(VEHICLE_SPAWN_X, _on_vehicle_gone)
	else:
		if _gate_east != null:
			_gate_east.set_open(true)
		v.speed = 8.0
		v.drive_to(VEHICLE_EXIT_X, _on_vehicle_gone)


func _on_vehicle_gone() -> void:
	_clear_vehicle()
	if _gate_west != null:
		_gate_west.set_open(false)
	if _gate_east != null:
		_gate_east.set_open(false)


func _clear_vehicle() -> void:
	if is_instance_valid(_vehicle):
		_vehicle.queue_free()
	_vehicle = null


func _on_bed(_p) -> void:
	if _busy or not _shift_running or GameState.has_next_encounter():
		return
	_busy = true
	_end_shift()


## Puerta trasera: abre/cierra la hoja. No termina el turno (para eso, la litera).
func _on_door(_p) -> void:
	if _door_pivot == null:
		return
	_door_open = not _door_open
	_door_shape.disabled = _door_open
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_door_pivot, "rotation_degrees:y", (-105.0 if _door_open else 0.0), 0.5)


func _end_shift() -> void:
	_shift_running = false
	var rep := GameState.end_shift_report()
	_hud.refresh_meters()
	if str(rep.get("failed", "")) != "":
		_game_over(str(rep["failed"]))
		return
	if rep.get("won", false):
		_win()
		return

	_player.set_movement_enabled(false)
	var b := ""
	if rep.get("paid", false):
		b += "Pagaste la nomina del equipo: -$%d.\n" % int(rep.get("payroll", 0))
	else:
		b += "NO alcanzo para la nomina ($%d). La lealtad cae.\n" % int(rep.get("payroll", 0))
	if rep.get("clean_shift", false):
		b += "\nNo aceptaste ni un soborno. Arriba se preguntan por que no llego su parte. La sospecha sube.\n"
	if str(rep.get("crew_leak", "")) != "":
		b += "\n%s hizo una llamada que no debia. La sospecha de los mandos sube.\n" % str(rep["crew_leak"])
	b += "\n" + _crew_status_text()
	_hud.show_panel("FIN DEL TURNO — Dia %d" % GameState.day, b, [{"label": "Continuar", "data": "ok"}])
	await _hud.panel_selected

	await _crew_talk_step()

	var opts: Array = []
	for o in GameState.config.get("relief_options", []):
		opts.append({"label": _relief_label(o), "data": o})
	opts.append({"label": "No hacer nada", "data": {}})
	_hud.show_panel("Antes del proximo turno", "El turno se te mete en la cabeza. Como lo sobrellevas?", opts)
	var pick: Variant = await _hud.panel_selected
	if pick is Dictionary and not (pick as Dictionary).is_empty():
		GameState.apply_relief(pick)
	GameState.advance_day()
	GameState.save_run()
	_hud.refresh_meters()

	var fm := GameState.failed_meter()
	if fm != "":
		_game_over(fm)
		return

	_set_exit(false)
	_hud.show_panel("Dia %d" % GameState.day, "Nuevo turno. El trafico no descansa.",
		[{"label": "Comenzar turno", "data": "ok"}])
	await _hud.panel_selected
	_start_shift()


func _game_over(meter: String) -> void:
	_shift_running = false
	_busy = true
	_clear_visitor()
	_clear_vehicle()
	_player.set_movement_enabled(false)
	_hud.set_objective("")
	GameState.clear_save(GameState.active_slot)
	_hud.show_panel("TE QUEMARON", "%s\n\nAguantaste hasta el turno %d de %d." % [
		_game_over_text(meter), GameState.day, int(GameState.config.get("total_days", 5))],
		[{"label": "Reintentar", "data": "retry"}, {"label": "Menu principal", "data": "menu"}])
	var pick: Variant = await _hud.panel_selected
	_leave(pick)


func _win() -> void:
	_shift_running = false
	_busy = true
	_clear_vehicle()
	_player.set_movement_enabled(false)
	_hud.set_objective("")
	GameState.clear_save(GameState.active_slot)
	_hud.show_panel("TRASLADADO",
		"Sobreviviste el turno completo. Llega tu traslado a otra zona.\n\nNadie te felicita. Pero sigues vivo, y aqui eso es un final feliz.",
		[{"label": "Jugar de nuevo", "data": "retry"}, {"label": "Menu principal", "data": "menu"}])
	var pick: Variant = await _hud.panel_selected
	_leave(pick)


func _leave(pick: Variant) -> void:
	if pick == "retry":
		GameState.start_new_run(GameState.active_slot)
		get_tree().change_scene_to_file("res://scenes/world.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ------------------------------------------------------------------- pausa
func _on_pause_requested() -> void:
	if not _shift_running or _busy:
		return
	_busy = true
	_player.set_movement_enabled(false)
	while true:
		_hud.show_panel("PAUSA", "Turno en curso — Dia %d." % GameState.day, [
			{"label": "Reanudar", "data": "resume"},
			{"label": "Opciones", "data": "options"},
			{"label": "Guardar y salir al menu", "data": "menu"},
			{"label": "Salir al escritorio", "data": "quit"},
		])
		var pick: Variant = await _hud.panel_selected
		if pick == "options":
			await _hud.open_options()
			continue
		if pick == "menu":
			GameState.save_run()
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return
		if pick == "quit":
			GameState.save_run()
			get_tree().quit()
			return
		break
	_busy = false
	_player.set_movement_enabled(true)


# -------------------------------------------------------------- companeros
func _band_label(band: String) -> String:
	if band == "loyal":
		return "leal"
	if band == "hostile":
		return "hostil"
	return "neutral"


## Linea por companero con su confianza, para el panel de fin de turno.
func _crew_status_text() -> String:
	var s := "EL EQUIPO\n"
	for c in GameState.crew_defs:
		var cid := str(c.get("id", ""))
		s += "  %s — %d (%s)\n" % [
			GameState.crew_name(cid), GameState.trust_of(cid),
			_band_label(GameState.trust_band(cid))]
	return s


## Texto extra en el panel de resultado si un companero apoyo o vendio.
func _crew_event_suffix() -> String:
	var ev: Dictionary = GameState.last_crew_event
	if ev.is_empty():
		return ""
	var assist := str(ev.get("kind", "")) == "assist"
	var col := "#5fc46f" if assist else "#dc574a"
	var verb := "respalda" if assist else "te vende"
	return "\n\n[color=%s][b]%s %s.[/b][/color] %s" % [
		col, str(ev.get("name", "")), verb, str(ev.get("text", ""))]


## Paso entre turnos: elegir un companero y una accion (pagar / trago / apretar).
func _crew_talk_step() -> void:
	var who: Array = []
	for c in GameState.crew_defs:
		var cid := str(c.get("id", ""))
		who.append({"label": "%s  (%d, %s)" % [
			GameState.crew_name(cid), GameState.trust_of(cid),
			_band_label(GameState.trust_band(cid))], "data": cid})
	who.append({"label": "Dejar al equipo en paz", "data": ""})
	_hud.show_panel("El equipo", "Con quien hablas antes de dormir?", who)
	var pick: Variant = await _hud.panel_selected
	if not (pick is String) or str(pick) == "":
		return
	var id := str(pick)

	var acts: Array = []
	for o in GameState.crew_talk_options:
		var cost := int(o.get("cost", 0))
		var lbl := str(o.get("label", ""))
		if cost > 0:
			lbl += "  (-$%d)" % cost
		acts.append({"label": lbl, "data": o})
	acts.append({"label": "Volver", "data": {}})
	_hud.show_panel(GameState.crew_name(id), str(GameState.crew_def(id).get("trait", "")), acts)
	var opt: Variant = await _hud.panel_selected
	if not (opt is Dictionary) or (opt as Dictionary).is_empty():
		return
	var rep := GameState.crew_talk(id, opt)
	_hud.refresh_meters()
	_hud.show_panel(str(rep.get("name", "")),
		"Confianza: %d (%s)." % [int(rep.get("trust", 0)), _band_label(str(rep.get("band", "neutral")))],
		[{"label": "Continuar", "data": "ok"}])
	await _hud.panel_selected


## Hablar con un companero durante el turno: acciones de confianza + ordenes.
func _on_crew_interact(_p, cid: String) -> void:
	if _busy or not _shift_running:
		return
	_busy = true
	_player.set_movement_enabled(false)

	var comp = _companions.get(cid)
	var caught: bool = comp != null and bool(comp.get("did_shady"))

	var opts: Array = []
	if caught:
		opts.append({"label": "Confrontarlo por lo que acabas de ver", "data": {"kind": "confront"}})
	for o in GameState.crew_talk_options:
		var cost := int(o.get("cost", 0))
		var lbl := str(o.get("label", ""))
		if cost > 0:
			lbl += "  (-$%d)" % cost
		opts.append({"label": lbl, "data": {"kind": "talk", "opt": o}})
	for o in GameState.crew_orders:
		opts.append({"label": str(o.get("label", "")), "data": {"kind": "order", "opt": o}})
	opts.append({"label": "Volver", "data": {}})

	var body := "%s\n\nConfianza: %d (%s)." % [
		str(GameState.crew_def(cid).get("trait", "")),
		GameState.trust_of(cid), _band_label(GameState.trust_band(cid))]
	var cur := str(GameState.crew_order.get(cid, ""))
	if cur != "":
		body += "\nOrden activa: %s." % cur
	_hud.show_panel(GameState.crew_name(cid), body, opts)
	var pick: Variant = await _hud.panel_selected

	if pick is Dictionary and not (pick as Dictionary).is_empty():
		var p := pick as Dictionary
		if str(p.get("kind", "")) == "confront":
			GameState.adjust_trust(cid, -8)
			GameState.nudge_meter("command_suspicion", -3)
			if comp != null:
				comp.set("did_shady", false)
			_hud.refresh_meters()
			_hud.show_panel(GameState.crew_name(cid),
				"Lo agarras del brazo. Suelta lo que se guardo sin decir palabra y no te mira. La confianza se rompe un poco mas.",
				[{"label": "Continuar", "data": "ok"}])
			await _hud.panel_selected
		elif str(p.get("kind", "")) == "talk":
			var rep := GameState.crew_talk(cid, p.get("opt", {}) as Dictionary)
			_hud.refresh_meters()
			_hud.show_panel(str(rep.get("name", "")),
				"Confianza: %d (%s)." % [int(rep.get("trust", 0)), _band_label(str(rep.get("band", "neutral")))],
				[{"label": "Continuar", "data": "ok"}])
			await _hud.panel_selected
		elif str(p.get("kind", "")) == "order":
			var oid := str((p.get("opt", {}) as Dictionary).get("id", ""))
			GameState.give_order(cid, oid)
			_hud.refresh_crew()
			_hud.show_panel(GameState.crew_name(cid), "Recibido.",
				[{"label": "Continuar", "data": "ok"}])
			await _hud.panel_selected

	_player.set_movement_enabled(true)
	_busy = false


# ------------------------------------------------------------------- helpers
const _DELTA_UP_IS_GOOD := {
	"cash": true, "loyalty": true, "nerve": true,
	"command_suspicion": false, "cartel_pressure": false,
}

## Chips coloreados con los cambios de medidor de la ultima eleccion.
func _delta_suffix() -> String:
	var out := ""
	for k in GameState.last_deltas.keys():
		var v := int(GameState.last_deltas[k])
		if v == 0:
			continue
		var good: bool = (v > 0) == bool(_DELTA_UP_IS_GOOD.get(k, true))
		var col := "#5fc46f" if good else "#dc574a"
		if out != "":
			out += "    "
		out += "[color=%s]%s %s%d[/color]" % [col, _meter_name(k), ("+" if v > 0 else ""), v]
	return ("\n\n" + out) if out != "" else ""


func _meter_name(k: String) -> String:
	match k:
		"cash":
			return "$"
		"loyalty":
			return "Lealtad"
		"command_suspicion":
			return "Sospecha"
		"cartel_pressure":
			return "Cartel"
		"nerve":
			return "Nervio"
	return k


func _relief_label(o: Dictionary) -> String:
	var c := int(o.get("cost", 0))
	var t := "%s   (+%d nervio" % [str(o.get("label", "")), int(o.get("nerve", 0))]
	if c > 0:
		t += ", -$%d" % c
	return t + ")"


func _game_over_text(meter: String) -> String:
	match meter:
		"loyalty":
			return "Tu propio equipo te entrego. Sabian tu turno y donde vivias."
		"nerve":
			return "Te quebraste en el puesto. Te hallaron temblando junto a la pluma, hablando solo."
		"command_suspicion":
			return "Los altos mandos te volvieron el chivo expiatorio. Tu cara salio en las noticias."
		"cartel_pressure":
			return "Un carro sin placas se detuvo frente a tu casa. No hubo aviso."
	return "Se acabo."
