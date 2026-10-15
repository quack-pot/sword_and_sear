class_name LootTable
extends Resource

@export var table: Array[Loot] = []

func populate_inventory(
	inventory: InventoryState,
	min_items: int = 1, # Target minimum number of items we'd like to see
	max_attempts: int = 10 # Maximum attempts to reach min_items added
) -> void:
	if table.size() == 0:
		return
	
	var added: int = 0
	for _idx in max_attempts:
		for loot in table:
			if loot.item == null:
				continue
			
			if randf() > loot.spawn_chance:
				continue
			
			var x: int = randi_range(0, inventory.width - 1)
			var y: int = randi_range(0, inventory.height - 1)
			
			if inventory.try_place(x, y, loot.item):
				added += 1
