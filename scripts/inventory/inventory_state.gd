class_name InventoryState
extends Resource

const EMPTY_ID: int = -1

var _next_item_id: int = 0

class InventoryItem:
	var id: int
	var metadata: SpatialItem
	var origin: Vector2i

	func _init(p_id: int, item: SpatialItem, x: int, y: int) -> void:
		id = p_id
		metadata = item
		origin = Vector2i(x, y)

var _grid: Array[int] = [EMPTY_ID]
var _items: Dictionary[int, InventoryItem] = {}

@export var width: int = 1:
	set(value): # These should NEVER change during runtime
		width = maxi(value, 1)
		_resize_grid()

@export var height: int = 1:
	set(value): # These should NEVER change during runtime
		height = maxi(value, 1)
		_resize_grid()

# *=================================================
# *
# * Helper Methods
# *
# *=================================================

func _resize_grid() -> void:
	_grid.resize(width * height)
	_grid.fill(EMPTY_ID)

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func _item_fits(x: int, y: int, item: SpatialItem) -> bool:
	return (
		x >= 0 and
		y >= 0 and
		x + item.grid_width <= width and
		y + item.grid_height <= height
	)

func _placement_valid(x: int, y: int, item: SpatialItem) -> bool:
	if item == null or not _item_fits(x, y, item):
		return false
	
	for iy in item.grid_height:
		var p_row_idx: int = iy * item.grid_width
		var g_row_idx: int = (y + iy) * width + x
		for ix in item.grid_width:
			if not item.grid_pattern[p_row_idx + ix]:
				continue
			
			if _grid[g_row_idx + ix] != EMPTY_ID:
				return false
	
	return true

func _placement_valid_existing(x: int, y: int, id: int, item: SpatialItem) -> bool:
	if item == null or not _item_fits(x, y, item):
		return false
	
	for iy in item.grid_height:
		var p_row_idx: int = iy * item.grid_width
		var g_row_idx: int = (y + iy) * width + x
		for ix in item.grid_width:
			if not item.grid_pattern[p_row_idx + ix]:
				continue
			
			var grid_id: int = _grid[g_row_idx + ix]
			if grid_id != EMPTY_ID and grid_id != id:
				return false
	
	return true

func _stamp(x: int, y: int, id: int, item: SpatialItem) -> void:
	for iy in item.grid_height:
		var p_row_idx: int = iy * item.grid_width
		var g_row_idx: int = (y + iy) * width + x
		for ix in item.grid_width:
			if not item.grid_pattern[p_row_idx + ix]:
				continue
			
			_grid[g_row_idx + ix] = id

# *=================================================
# *
# * Getters
# *
# *=================================================

func get_width() -> int:
	return width

func get_height() -> int:
	return height

func get_item_id_at(x: int, y: int) -> int:
	if not _in_bounds(x, y):
		return EMPTY_ID
	return _grid[y * width + x]

func get_item(id: int) -> InventoryItem:
	return _items.get(id, null)

func get_item_ids() -> Array[int]:
	return _items.keys()

func get_all_items() -> Array[InventoryItem]:
	return _items.values()

# *=================================================
# *
# * Queries
# *
# *=================================================

func is_empty() -> bool:
	return _items.is_empty()

func can_place(x: int, y: int, item: SpatialItem) -> bool:
	return _placement_valid(x, y, item)

func can_move(x: int, y: int, id: int) -> bool:
	var item: InventoryItem = _items.get(id, null)
	return item != null and _placement_valid_existing(x, y, id, item.metadata)

# *=================================================
# *
# * Modification
# *
# *=================================================

func try_move(x: int, y: int, id: int) -> bool:
	var item: InventoryItem = _items.get(id, null)
	if item == null:
		return false
	
	if not _placement_valid_existing(x, y, id, item.metadata):
		return false
	
	for idx in _grid.size():
		if _grid[idx] == id:
			_grid[idx] = EMPTY_ID
	
	_stamp(x, y, id, item.metadata)
	item.origin = Vector2i(x, y)
	emit_changed()
	
	return true

func try_place(x: int, y: int, item: SpatialItem) -> bool:
	if not _placement_valid(x, y, item):
		return false
	
	var id: int = _next_item_id
	_next_item_id += 1

	_items.set(id, InventoryItem.new(id, item, x, y))
	_stamp(x, y, id, item)
	
	emit_changed()
	return true

func remove_by_id(id: int) -> SpatialItem:
	var item: InventoryItem = _items[id]
	if item == null:
		return null
	
	_items.erase(id)
	for idx in _grid.size():
		if _grid[idx] == id:
			_grid[idx] = EMPTY_ID
	
	emit_changed()
	return item.metadata

func remove(x: int, y: int) -> SpatialItem:
	var item_id: int = get_item_id_at(x, y)
	return null if item_id == EMPTY_ID else remove_by_id(item_id)

func clear() -> void:
	_items.clear()
	_grid.fill(EMPTY_ID)
	_next_item_id = 0
