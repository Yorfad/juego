extends Node3D
## Se adjunta con set_script a un nodo "boom_arm_*" del modelo exterior (su
## origen ya viene en el pivote, exportado desde Blender). Sube/baja rotando
## en X con un tween; sin rig, sin fisica.

const DOWN_DEG := 0.0
const UP_DEG := 75.0   # el brazo apunta a -Z; +X rota la punta hacia arriba
const DURATION := 0.9

var _open := false
var _tween: Tween


func is_open() -> bool:
	return _open


func set_open(v: bool, animate: bool = true) -> void:
	if v == _open:
		return
	_open = v
	var target := UP_DEG if v else DOWN_DEG
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate:
		rotation_degrees.x = target
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation_degrees:x", target, DURATION)
