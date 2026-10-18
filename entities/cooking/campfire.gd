extends InventoryProvider

@export var recipes: Array[Recipe]

@onready var area: Area3D = $Area3D
@onready var prompt: Label3D = $Prompt
@onready var ui: CanvasLayer = $UI
@onready var recipe_list: Label = $UI/RecipeList
@onready var cook_button: Button = $UI/CookButton

signal meal_eaten(recipe: Recipe, grade: CookingMinigame.Grade)
var cooking_recipe: Recipe

var inventory: InventoryState
var in_range: bool = false
var match_recipe: Recipe
var match_id: int

func _ready() -> void:
	inventory = InventoryState.new()
	inventory.width = 4
	inventory.height = 4
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	var parts: PackedStringArray = []
	for r in recipes:
		parts.append("%s -> %s" % [GlobalItemData.ItemIds.keys()[r.ingredient].capitalize(), r.dish_name])
	recipe_list.text = "Recipes: " + ", ".join(parts)

	inventory.changed.connect(_update_button)
	cook_button.pressed.connect(_on_cook_pressed)
	_update_button()

func _process(_delta: float) -> void:
	ui.visible = InventoryGrid.instance.is_open() and InventoryGrid.instance.secondary_provider == self

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

func _update_button() -> void:
	match_recipe = null
	for id in inventory.get_item_ids():
		var kind = inventory.get_item(id).metadata.item_id
		for r in recipes:
			if r.ingredient == kind:
				match_recipe = r
				match_id = id

	if match_recipe:
		cook_button.text = "Cook %s!" % match_recipe.dish_name
		cook_button.disabled = false
	else:
		cook_button.text = "Add an ingredient"
		cook_button.disabled = true

func _on_cook_pressed() -> void:
	cooking_recipe = match_recipe
	inventory.remove_by_id(match_id)
	InventoryGrid.instance.close()
	var minigame: CookingMinigame = cooking_recipe.minigame.instantiate()
	add_child(minigame)
	minigame.finished.connect(_on_meal_finished)

func _on_meal_finished(grade: CookingMinigame.Grade) -> void:
	meal_eaten.emit(cooking_recipe, grade)
	print("Cooked %s (%s)" % [cooking_recipe.dish_name, CookingMinigame.Grade.keys()[grade]])