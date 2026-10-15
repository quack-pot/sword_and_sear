extends CookingStep

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Cook"):
		done.emit(1.0)