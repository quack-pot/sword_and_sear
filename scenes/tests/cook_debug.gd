extends Node

@export var cooking_scene: PackedScene

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		var cook: CookingMinigame = cooking_scene.instantiate()
		add_child(cook)
		cook.finished.connect(_on_cooked)

func _on_cooked(grade: CookingMinigame.Grade) -> void:
	print(CookingMinigame.Grade.keys()[grade])