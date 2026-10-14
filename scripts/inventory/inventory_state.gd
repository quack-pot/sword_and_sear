class_name InventoryState
extends Resource

const EMPTY_INDEX: int = -1

@export var width: int = 1:
	set(value): # These should NEVER change during runtime
		width = maxi(value, 1)
		_grid = _fit_pattern(_grid)

@export var height: int = 1:
	set(value): # These should NEVER change during runtime
		height = maxi(value, 1)
		_grid = _fit_pattern(_grid)

var _grid: Array[int] = [EMPTY_INDEX]
var _items: Dictionary[int, SpatialItem] = {}

var _next_item_id: int = 0

func _fit_pattern(
	source: Array[int]
) -> Array[int]:
	var fitted: Array[int] = []
	for i in width * height:
		fitted.append(source[i] if i < source.size() else EMPTY_INDEX)
	return fitted

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func _item_fits(x: int, y: int, item: SpatialItem) -> bool:
	return (
		x >= 0
		and y >= 0
		and x + item.grid_width <= width
		and y + item.grid_height <= height
	)

func get_item(x: int, y: int) -> SpatialItem:
	if not _in_bounds(x, y):
		return null
	
	var item_id: int = _grid[y * width + x]
	if item_id == EMPTY_INDEX:
		return null
	
	return _items[item_id]

func _placement_valid(x: int, y: int, item: SpatialItem) -> bool:
	if item == null or not _item_fits(x, y, item):
		return false
	
	if item.grid_pattern.size() != item.grid_width * item.grid_height:
		return false
	
	for iy in item.grid_height:
		for ix in item.grid_width:
			if not item.grid_pattern[iy * item.grid_width + ix]:
				continue
			
			if _grid[(y + iy) * width + (x + ix)] != EMPTY_INDEX:
				return false
	
	return true

func try_place(x: int, y: int, item: SpatialItem) -> bool:
	if not _placement_valid(x, y, item):
		return false
		
	var id: int = _next_item_id
	_next_item_id += 1
	
	_items.set(id, item)
	
	for iy in item.grid_height:
		for ix in item.grid_width:
			if not item.grid_pattern[iy * item.grid_width + ix]:
				continue
			
			_grid[(y + iy) * width + (x + ix)] = id
	
	return true

func remove(x: int, y: int) -> void:
	var index: int = y * width + x
	if index < 0 or index >= _grid.size():
		return
	
	var item_id: int = _grid[index]
	if item_id == EMPTY_INDEX:
		return
	
	var item: SpatialItem = _items[item_id]
	_items.erase(item_id)
	
	for idx in _grid.size():
		if _grid[idx] == item_id:
			_grid[idx] = EMPTY_INDEX
