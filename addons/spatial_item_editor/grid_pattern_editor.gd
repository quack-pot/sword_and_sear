@tool
extends EditorProperty

var _grid := GridContainer.new()

func _init() -> void:
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	add_child(_grid)
	set_bottom_editor(_grid)

func _update_property() -> void:
	var item := get_edited_object() as SpatialItem
	if item == null:
		return
	
	var width := item.grid_width
	var height := item.grid_height
	var pattern: Array = item.grid_pattern
	
	if _grid.columns != width or _grid.get_child_count() != width * height:
		_rebuild(width, height)
	
	for y in height:
		for x in width:
			var box := _grid.get_child(y * width + x) as CheckBox
			box.set_pressed_no_signal(bool(pattern[y * width + x]))

func _rebuild(width: int, height: int) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	
	_grid.columns = width
	for y in height:
		for x in width:
			var box := CheckBox.new()
			box.tooltip_text = "(%d, %d)" % [x, y]
			box.toggled.connect(_on_cell_toggled.bind(x, y))
			_grid.add_child(box)

func _on_cell_toggled(pressed: bool, x: int, y: int) -> void:
	var item := get_edited_object() as SpatialItem
	var new_pattern: Array[bool] = item.grid_pattern.duplicate()
	new_pattern[y * item.grid_width + x] = pressed
	emit_changed(get_edited_property(), new_pattern)
