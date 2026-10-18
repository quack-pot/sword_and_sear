extends Control

@onready var retry_button: Button = $RetryButton

func _ready() -> void:
	var grid: InventoryGrid = InventoryGrid.instance
	if grid != null:
		grid.close()

	retry_button.pressed.connect(_on_retry_pressed)
	retry_button.grab_focus()

func _on_retry_pressed() -> void:
	PlayerStamina.add_stamina(PlayerStamina.MAX_STAMINA)
	PlayerInventory.get_inventory().clear()
	get_tree().change_scene_to_file("res://scenes/scn_dungeon.tscn")
