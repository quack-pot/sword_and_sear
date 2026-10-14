@tool
class_name SpatialItem
extends Resource

@export var item_id: GlobalItemData.ItemIds = GlobalItemData.ItemIds.EMPTY

var _syncing_size: bool = false

@export_range(1, 32, 1, "or_greater") var grid_width: int = 1:
	set(value):
		grid_width = maxi(value, 1)
		if not _syncing_size:
			_refit_pattern()

@export_range(1, 32, 1, "or_greater") var grid_height: int = 1:
	set(value):
		grid_height = maxi(value, 1)
		if not _syncing_size:
			_refit_pattern()

@export var grid_pattern: Array[Array] = [[true]]:
	set(value):
		var rows := value.size()
		var cols := 0
		for row in value:
			cols = maxi(cols, row.size())
		
		_syncing_size = true
		grid_height = rows
		grid_width = cols
		_syncing_size = false
		
		grid_pattern = _fit_pattern(value)
		
		emit_changed()
		if Engine.is_editor_hint():
			notify_property_list_changed()

@export var item_image: Texture2D

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
