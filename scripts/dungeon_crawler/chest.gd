class_name Chest
extends InventoryProvider

@export var inventory: InventoryState = null
@export var loot_table: LootTable = null

@export_range(0, 10, 1, "or_greater") var target_item_count: int = 1

@onready var interact_area: Area3D = $Area3D
var in_range: bool = false

func _setup_interactions() -> void:
	if interact_area == null:
		push_warning("Chest has no interaction area assigned.")
		return
	
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _populate_loot() -> void:
	if loot_table == null or inventory == null:
		return
	
	loot_table.populate_inventory(inventory, target_item_count)

func _ready() -> void:
	_setup_interactions()
	_populate_loot()

func get_inventory() -> InventoryState:
	return inventory

func _unhandled_input(event: InputEvent) -> void:
	if not in_range:
		return
	
	if event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()
		
		var grid: InventoryGrid = InventoryGrid.instance
		if grid == null:
			return
		
		grid.toggle(self)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = true

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = false
