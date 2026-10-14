extends Node3D

@export var lifetime: float = 0.5 # s
var timer: float = 0.0

func _process(delta: float) -> void:
	timer += delta
	
	if timer >= lifetime:
		queue_free()
