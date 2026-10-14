@tool
class_name SpatialItem
extends Resource

@export var item_id: GlobalItemData.ItemIds = GlobalItemData.ItemIds.EMPTY

@export_range(1, 32, 1, "or_greater") var grid_width: int = 1:
	set(value):
		var old_width := grid_width
		grid_width = maxi(value, 1)
		_remap_pattern(old_width, grid_height)

@export_range(1, 32, 1, "or_greater") var grid_height: int = 1:
	set(value):
		var old_height := grid_height
		grid_height = maxi(value, 1)
		_remap_pattern(grid_width, old_height)

@export var grid_pattern: Array[bool] = [true]:
	set(value):
		grid_pattern = _fit_pattern(value)
		emit_changed()
		if Engine.is_editor_hint():
			notify_property_list_changed()

@export var item_image: Texture2D

func _remap_pattern(old_width: int, old_height: int) -> void:
	var remapped: Array[bool] = []
	for y in grid_height:
		for x in grid_width:
			var cell := false
			if x < old_width and y < old_height:
				var old_index := y * old_width + x
				if old_index < grid_pattern.size():
					cell = grid_pattern[old_index]
			remapped.append(cell)
	grid_pattern = remapped

func _fit_pattern(source: Array) -> Array[bool]:
	var fitted: Array[bool] = []
	for i in grid_width * grid_height:
		fitted.append(bool(source[i]) if i < source.size() else false)
	return fitted
