extends Range

func _process(_delta: float) -> void:
	value = max_value * (float(PlayerStamina.get_stamina()) / PlayerStamina.MAX_STAMINA)
