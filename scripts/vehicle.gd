extends Node3D
## Vehiculo sin fisica ni rig: interpola su posicion en X hacia un punto de
## destino y avisa cuando llega. world.gd lo usa para "conducir" un modelo
## importado (glTF) hasta la ventanilla y luego dejarlo seguir o retroceder.

signal arrived

var speed: float = 6.0

var _target_x: float = 0.0
var _moving: bool = false
var _on_arrive: Callable = Callable()


## Empieza a moverse hacia world x = x_pos. cb (opcional) se llama al llegar,
## ademas de emitir "arrived".
func drive_to(x_pos: float, cb: Callable = Callable()) -> void:
	_target_x = x_pos
	_on_arrive = cb
	_moving = true


func _process(delta: float) -> void:
	if not _moving:
		return
	var dx: float = _target_x - global_position.x
	var step: float = speed * delta
	if absf(dx) <= step:
		global_position.x = _target_x
		_moving = false
		if _on_arrive.is_valid():
			_on_arrive.call()
		arrived.emit()
	else:
		global_position.x += step * signf(dx)
