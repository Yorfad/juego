extends CharacterBody3D
## Companero con vida propia. Patrulla puntos (dentro y fuera de la caseta) y,
## segun su confianza:
##  - leal/neutral: se acerca al jugador, saluda y suelta un parte.
##  - hostil: se aparta a un rincon fuera de tu vista y hace algo turbio; si te
##    acercas o lo miras, disimula y se va.
## Sin rig: solo mueve el nodo y rota el brazo derecho para el saludo.

const SPEED := 1.9
const GRAVITY := 14.0
const ARRIVE := 0.45
const SEE_DIST := 12.0
const SEE_DOT := 0.60     # ~53 grados de cono
const NEAR_DIST := 2.6

enum St { IDLE, PATROL, APPROACH, REPORT, SNEAK, CONCEAL, INNOCENT }

# --- contrato de "interactuable" (para el raycast de "E" del jugador) ---
signal interacted(player)
var prompt := ""
var enabled := true

var id := ""
var def := {}
var boldness := 0.6
var did_shady := false      # hizo algo turbio sin que lo vieras -> world.gd ofrece "confrontar"

var _player                 # CharacterBody3D del jugador (sin tipar: usamos get_rid, etc.)
var _wp := {}               # nombre -> Vector3
var _links := {}            # nombre -> [nombres]
var _cover: Array = []
var _active := Callable()   # world.gd: true si los companeros deben moverse ahora

var _state: int = St.IDLE
var _path: Array = []
var _here := "center"
var _think_t := 3.0
var _state_t := 0.0
var _label: Label3D          # rotulo persistente: "<Nombre> · <estado>" o la frase del parte
var _say_t := 0.0
var _arm_r: Node3D
var _notify := Callable()    # world.gd: mostrar un aviso (toast)


func setup(cid: String, cdef: Dictionary, player, wp: Dictionary,
		links: Dictionary, cover: Array, active_cb: Callable, notify_cb: Callable) -> void:
	id = cid
	def = cdef
	boldness = float(cdef.get("boldness", 0.6))
	_player = player
	_wp = wp
	_links = links
	_cover = cover
	_active = active_cb
	_notify = notify_cb
	_arm_r = find_child("arm_r", true, false)
	_here = _nearest_wp()
	_think_t = randf_range(1.5, 4.0)
	_refresh_label()


func _ready() -> void:
	_label = Label3D.new()
	_label.position.y = 2.25
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 34
	_label.outline_size = 9
	_label.pixel_size = 0.0032
	_label.modulate = Color(0.9, 0.88, 0.82)
	add_child(_label)


func interact(player) -> void:
	if enabled:
		interacted.emit(player)


func say(text: String, seconds: float) -> void:
	if _label == null:
		return
	_label.text = text
	_label.modulate = Color(1.0, 0.95, 0.78)
	_say_t = seconds


func _notify_toast(t: String) -> void:
	if _notify.is_valid():
		_notify.call(t)


func _refresh_label() -> void:
	if _label == null or _say_t > 0.0:
		return
	_label.text = "%s · %s" % [GameState.crew_name(id), _state_word()]
	_label.modulate = _state_color()


func _state_word() -> String:
	if _state == St.APPROACH or _state == St.REPORT:
		return "te busca"
	if _state == St.SNEAK or _state == St.CONCEAL:
		return "se aparta"
	return "en ronda"


func _state_color() -> Color:
	var b := band()
	if b == "hostile":
		return Color(0.92, 0.55, 0.5)
	if b == "loyal":
		return Color(0.6, 0.86, 0.62)
	return Color(0.82, 0.82, 0.88)


func band() -> String:
	return GameState.trust_band(id)


# --------------------------------------------------------------------- loop
func _physics_process(delta: float) -> void:
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t <= 0.0:
			_refresh_label()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var can_act: bool = _active.is_valid() and _active.call()
	if not can_act:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_state_t += delta
	_think_t -= delta
	_refresh_label()

	match _state:
		St.IDLE:
			_glance_at_player(delta)
			velocity.x = 0.0
			velocity.z = 0.0
			if _think_t <= 0.0:
				_decide()
		St.PATROL, St.SNEAK, St.APPROACH, St.INNOCENT:
			_walk(delta)
		St.CONCEAL:
			_concealing()
		St.REPORT:
			_reporting(delta)

	if (_state == St.SNEAK or _state == St.CONCEAL) and _player_watching():
		_go_innocent()

	move_and_slide()


# ----------------------------------------------------------------- decidir
func _decide() -> void:
	_think_t = randf_range(6.0, 12.0)
	var b := band()
	var r := randf()
	if b == "hostile" and r < 0.40 + boldness * 0.30:
		_start_sneak()
	elif b != "hostile" and r < 0.42 + boldness * 0.28:
		_start_approach()
	elif r < 0.82:
		_go_to(_rand(_wander_list()), St.PATROL)
	else:
		_state = St.IDLE
		_state_t = 0.0
		_think_t = randf_range(3.0, 7.0)


func _start_approach() -> void:
	if _player == null:
		return
	_path = [_near_player_spot()]
	_state = St.APPROACH
	_state_t = 0.0


func _start_sneak() -> void:
	var pt := _rand(_cover)
	if pt == "":
		_go_to(_rand(_wander_list()), St.PATROL)
		return
	_path = _path_to(pt)
	_state = St.SNEAK
	_state_t = 0.0


func _go_to(goal: String, s: int) -> void:
	if goal == "" or goal == _here:
		_state = St.IDLE
		_state_t = 0.0
		_think_t = randf_range(3.0, 7.0)
		return
	_path = _path_to(goal)
	_state = s
	_state_t = 0.0


func _go_innocent() -> void:
	_salute(false)
	_notify_toast("%s se aparta demasiado rapido. Algo se trae entre manos." % GameState.crew_name(id))
	say("...", 1.6)
	var g := _rand(_wander_list())
	_path = _path_to(g) if g != "" else []
	_state = St.INNOCENT
	_state_t = 0.0


# ----------------------------------------------------------------- mover
func _walk(delta: float) -> void:
	if _path.is_empty():
		_arrived()
		return
	var target: Vector3 = _path[0]
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	if d <= ARRIVE:
		_path.pop_front()
		if _path.is_empty():
			_arrived()
		return
	var dir := to / d
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	_face(dir, delta)


func _arrived() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_here = _nearest_wp()
	match _state:
		St.APPROACH:
			_state = St.REPORT
			_state_t = 0.0
		St.SNEAK:
			_state = St.CONCEAL
			_state_t = 0.0
		_:
			_state = St.IDLE
			_state_t = 0.0
			_think_t = randf_range(2.0, 6.0)


func _concealing() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _state_t < 1.5:
		return
	var ef: Dictionary = def.get("conceal_effect", {})
	var key := str(ef.get("key", "cash"))
	var amt := randi_range(int(ef.get("min", 10)), int(ef.get("max", 30)))
	GameState.nudge_meter(key, (-amt if key == "cash" else amt))
	GameState.adjust_trust(id, -1)
	did_shady = true
	if key == "cash":
		_notify_toast("Falta dinero en la caja. Alguien la toco.")
	elif key == "command_suspicion":
		_notify_toast("Los mandos parecen saber mas de lo que deberian.")
	_go_to(_rand(_wander_list()), St.PATROL)


func _reporting(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _player != null:
		var to := _ppos() - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_face(to.normalized(), delta * 2.5)
	if _state_t < 0.15:
		_salute(true)
		var line := _rand(def.get("reports", ["Sin novedad, comandante."]))
		say(GameState.crew_name(id) + ": " + line, 5.0)
		_notify_toast("%s te da un parte." % GameState.crew_name(id))
		if band() == "loyal" and randf() < 0.5:
			GameState.nudge_meter("command_suspicion", -2)
	elif _state_t > 5.0:
		_salute(false)
		_go_to(_rand(_wander_list()), St.PATROL)


func _salute(up: bool) -> void:
	if _arm_r == null:
		return
	var tw := create_tween()
	tw.tween_property(_arm_r, "rotation:x", (deg_to_rad(138.0) if up else 0.0), 0.28)


# ----------------------------------------------------------------- percepcion
func _ppos() -> Vector3:
	return _player.global_position


func _pfwd() -> Vector3:
	return -_player.global_transform.basis.z


func _player_watching() -> bool:
	if _player == null:
		return false
	var eye := _ppos() + Vector3(0, 1.7, 0)
	var me := global_position + Vector3(0, 1.2, 0)
	var to := me - eye
	var dist := to.length()
	if dist > SEE_DIST:
		return false
	if _pfwd().dot(to / maxf(dist, 0.001)) < SEE_DOT:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, me)
	q.exclude = [get_rid(), _player.get_rid()]
	return space.intersect_ray(q).is_empty()


func _glance_at_player(delta: float) -> void:
	if _player == null:
		return
	var to := _ppos() - global_position
	to.y = 0.0
	var d := to.length()
	if d < 3.5 and d > 0.2:
		_face(to / d, delta * 1.5)


# ----------------------------------------------------------------- utils
func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(-dir.x, -dir.z)   # la figura mira -Z local
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 6.0, 0.0, 1.0))


func _wander_list() -> Array:
	var w: Array = def.get("wander", [])
	return w if not w.is_empty() else _wp.keys()


func _rand(arr) -> String:
	var a: Array = arr
	if a.is_empty():
		return ""
	return str(a[randi() % a.size()])


func _near_player_spot() -> Vector3:
	var p := _ppos()
	var away := global_position - p
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0, 0, 1)
	return p + away.normalized() * 1.6


func _nearest_wp() -> String:
	var best := _here
	var bd := INF
	for k in _wp.keys():
		var d: float = global_position.distance_to(_wp[k] as Vector3)
		if d < bd:
			bd = d
			best = k
	return best


func _path_to(goal: String) -> Array:
	if not _wp.has(goal):
		return []
	var start := _nearest_wp()
	if start == goal or not _links.has(start):
		return [_wp[goal]]
	var prev := {start: ""}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == goal:
			break
		for nb in _links.get(cur, []):
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	if not prev.has(goal):
		return [_wp[goal]]
	var chain: Array = []
	var n := goal
	while n != "" and n != start:
		chain.push_front(_wp[n])
		n = str(prev[n])
	return chain
