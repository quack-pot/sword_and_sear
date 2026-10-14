@tool
class_name SpatialItem
extends Resource

enum ItemIds {
	CABBAGE = 0
}

@export var item_id: ItemIds = ItemIds.CABBAGE

@export_range(1, 32, 1, "or_greater") var grid_width: int = 1:
	set(value):
		grid_width = maxi(value, 1)
		_refit_pattern()

@export_range(1, 32, 1, "or_greater") var grid_height: int = 1:
	set(value):
		grid_height = maxi(value, 1)
		_refit_pattern()

@export var grid_pattern: Array[Array] = [[true]]

@export var item_image: Texture2D

func _init(
	p_item_id: ItemIds = ItemIds.CABBAGE,
	p_grid_width: int = 1,
	p_grid_height: int = 1,
	p_grid_pattern: Array[Array] = [[true]],
	p_item_image: Texture2D = null
) -> void:
	item_id = p_item_id
	grid_width = p_grid_width
	grid_height = p_grid_height
	grid_pattern = p_grid_pattern
	item_image = p_item_image

func _refit_pattern() -> void:
	grid_pattern = _fit_pattern(grid_pattern)

func _fit_pattern(source: Array) -> Array[Array]:
	var fitted: Array[Array] = []
	for y in grid_height:
		var row: Array = []
		for x in grid_width:
			var cell := false
			if y < source.size() and x < source[y].size():
				cell = bool(source[y][x])
			row.append(cell)
		fitted.append(row)
	return fitted
