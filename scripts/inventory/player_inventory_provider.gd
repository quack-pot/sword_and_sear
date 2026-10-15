extends InventoryProvider

const INVENTORY_RESOURCE := preload("res://resources/player_inventory.res")

func get_inventory() -> InventoryState:
	return INVENTORY_RESOURCE
