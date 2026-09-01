extends CharacterBody3D
## Controlador en primera persona. Se auto-ensambla por codigo (crea su camara,
## su colision y el raycast de interaccion) para que no haya .tscn que romper.
##
## Controles: WASD moverse, raton mirar, E interactuar, ESC liberar el raton,
## clic para volver a capturarlo.

signal looked_at(node)
signal looked_away()
signal pause_requested()

const SPEED := 3.2
const GRAVITY := 12.0
const JUMP_SPEED := 4.2
const MOUSE_SENS := 0.0022

var camera: Camera3D
var ray: RayCast3D
var _yaw := 0.0
var _pitch := 0.0
var _can_move := false
var _mouse_captured := false
var _target: Node = null


func _ready() -> void:
	collision_mask = 1 | 8   # paredes/suelo (1) + la hoja de la puerta (capa 4)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8
	cap.radius = 0.35
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.65, 0.0)
	camera.fov = 74.0
	add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0.0, 0.0, -2.6)
	ray.collide_with_bodies = true
	ray.collide_with_areas = false
	ray.collision_mask = 1 | 2   # capa 1 (interactuables/companeros) + capa 2 (zona de puerta, que no choca)
	ray.hit_from_inside = true   # detecta interactuables aunque estes pegado a ellos
	ray.add_exception(self)
	camera.add_child(ray)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_movement_enabled(v: bool) -> void:
	_can_move = v
	_set_mouse_captured(v)
	if not v:
		_set_target(null)


## Solo mirar: la camara responde pero no puedes andar, saltar ni interactuar.
## Para momentos guionizados (ver el vehiculo acercarse).
func set_look_only() -> void:
	_can_move = false
	_set_mouse_captured(true)
	_set_target(null)


func _set_mouse_captured(v: bool) -> void:
	_mouse_captured = v
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		var sens: float = MOUSE_SENS * float(Settings.mouse_sensitivity)
		var rel: Vector2 = event.relative
		_yaw -= rel.x * sens
		var dy: float = rel.y * sens
		if Settings.invert_y:
			dy = -dy
		_pitch = clampf(_pitch - dy, -1.45, 1.45)
		rotation.y = _yaw
		camera.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and _can_move and _mouse_captured \
				and _target != null and _target.has_method("interact"):
			_target.interact(self)
		elif event.physical_keycode == KEY_ESCAPE and _can_move:
			pause_requested.emit()
	elif event is InputEventMouseButton and event.pressed and _can_move and not _mouse_captured:
		_set_mouse_captured(true)


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if _can_move and _mouse_captured:
		var b := global_transform.basis
		if Input.is_physical_key_pressed(KEY_W):
			dir -= b.z
		if Input.is_physical_key_pressed(KEY_S):
			dir += b.z
		if Input.is_physical_key_pressed(KEY_A):
			dir -= b.x
		if Input.is_physical_key_pressed(KEY_D):
			dir += b.x
		dir.y = 0.0
		dir = dir.normalized()

	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		if _can_move and _mouse_captured and Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = JUMP_SPEED
	move_and_slide()
	_scan()


func _scan() -> void:
	var found: Node = null
	if _can_move and _mouse_captured and ray.is_colliding():
		var c: Node = ray.get_collider()
		while c != null and not c.has_method("interact"):
			c = c.get_parent()
		if c != null and c.has_method("interact"):
			found = c
	_set_target(found)


func _set_target(node: Node) -> void:
	if node == _target:
		return
	_target = node
	if _target != null:
		looked_at.emit(_target)
	else:
		looked_away.emit()
