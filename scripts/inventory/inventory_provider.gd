class_name InventoryProvider
extends Node

signal state_changed

# To be overwritten by sub-classes
func get_inventory() -> InventoryState:
	return null
