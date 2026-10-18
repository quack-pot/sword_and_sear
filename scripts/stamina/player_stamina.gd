extends Node

const MAX_STAMINA: int = 100
var _stamina: int = MAX_STAMINA

func get_stamina() -> int:
	return _stamina

func add_stamina(delta: int) -> void:
	_stamina += delta
	if _stamina > MAX_STAMINA:
		_stamina = MAX_STAMINA

func remove_stamina(delta: int) -> void:
	_stamina -= delta
	if _stamina < 0:
		_stamina = 0

func has_enough_stamina(requested: int) -> bool:
	return _stamina >= requested
