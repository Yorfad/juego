extends StaticBody3D
## Objeto con el que el jugador interactua mirandolo y pulsando E.
## world.gd le añade la malla y la colision y ajusta 'prompt' / 'enabled'.

signal interacted(player)

var prompt := "Interactuar"
var enabled := true


func set_enabled(v: bool) -> void:
	enabled = v


func interact(player) -> void:
	if enabled:
		interacted.emit(player)
