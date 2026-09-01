extends Node
## Ajustes globales del jugador (autoload "Settings").
## Se guardan en user://settings.cfg y se aplican al arrancar. No son por ranura:
## valen para todas las partidas.

const PATH := "user://settings.cfg"

var mouse_sensitivity: float = 1.0   # multiplicador sobre la sensibilidad base
var invert_y: bool = false
var fullscreen: bool = false
var master_volume: float = 1.0       # lineal 0..1


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(PATH)


func apply_all() -> void:
	_apply_fullscreen()
	_apply_volume()


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_volume() -> void:
	var v := clampf(master_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, -80.0 if v <= 0.001 else linear_to_db(v))


# --- setters que aplican y persisten al momento (los usa el menu de opciones) ---
func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = v
	save_settings()


func set_invert_y(v: bool) -> void:
	invert_y = v
	save_settings()


func set_fullscreen(v: bool) -> void:
	fullscreen = v
	_apply_fullscreen()
	save_settings()


func set_master_volume(v: float) -> void:
	master_volume = v
	_apply_volume()
	save_settings()
