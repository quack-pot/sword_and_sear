class_name Chest
extends InventoryProvider

var inventory: InventoryState = null
@export var width: int = 1:
	set(value): # These should NEVER change during runtime
		width = maxi(value, 1)

@export var height: int = 1:
	set(value): # These should NEVER change during runtime
		height = maxi(value, 1)

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
	inventory = InventoryState.new()
	inventory.width = width
	inventory.height = height

	if loot_table == null:
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

		if not grid.is_open() and inventory.is_empty():
			queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = true

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = false
