extends InventoryProvider

@export var recipes: Array[Recipe]

@onready var area: Area3D = $Area3D
@onready var prompt: Label3D = $Prompt
@onready var ui: CanvasLayer = $UI
@onready var recipe_list: Label = $UI/RecipeList
@onready var cook_button: Button = $UI/CookButton

var inventory: InventoryState
var in_range: bool = false


func _ready() -> void:
	inventory = InventoryState.new()
	inventory.width = 2
	inventory.height = 2
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

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
	prompt.show()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = false
	prompt.hide()