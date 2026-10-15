class_name InventoryGrid
extends Control

signal inventory_opened
signal inventory_closed

static var instance: InventoryGrid

class DragPayload:
	var id: int
	var item: InventoryState.InventoryItem
	var source: InventoryState
	var grab_offset: Vector2i

	func _init(
		p_id: int,
		p_item: InventoryState.InventoryItem,
		p_source: InventoryState,
		p_grab_offset: Vector2i
	) -> void:
		id = p_id
		item = p_item
		source = p_source
		grab_offset = p_grab_offset

class ItemPreview extends Control:
	var grid: InventoryGrid
	var spatial: SpatialItem

	func _init(p_grid: InventoryGrid, p_spatial: SpatialItem) -> void:
		grid = p_grid
		spatial = p_spatial
	
	func _draw() -> void:
		grid._draw_item_on(self, spatial, Vector2.ZERO)

@export var closed: bool = true:
	set(value):
		var changed: bool = value != closed
		closed = value
		mouse_filter = Control.MOUSE_FILTER_IGNORE if closed  else Control.MOUSE_FILTER_STOP
		
		_on_inventory_changed()
		if changed and is_inside_tree():
			if closed:
				inventory_closed.emit()
			else:
				inventory_opened.emit()

@export_group("Inventory State")
@export var secondary_provider: InventoryProvider:
	set(value):
		_rig_state(secondary_provider, value)
		secondary_provider = value
		_on_inventory_changed()

@export_group("Cell Visuals")
@export var cell_size: Vector2i = Vector2i(32, 32):
	set(value):
		cell_size = value.max(Vector2i.ONE)
		_on_inventory_changed()

@export var cell_gap: int = 0:
	set(value):
		cell_gap = maxi(value, 0)
		_on_inventory_changed()

@export var inventory_gap: int = 64:
	set(value):
		inventory_gap = maxi(value, 0)
		_on_inventory_changed()

@export_range(0.0, 8.0, 0.5, "or_greater") var cell_border_width: float = 1.0:
	set(value):
		cell_border_width = maxf(value, 0.0)
		queue_redraw()

@export var empty_color := Color(0.15, 0.15, 0.18, 1.0):
	set(value):
		empty_color = value
		queue_redraw()
@export var item_fallback_color := Color(0.55, 0.65, 0.85, 1.0):
	set(value):
		item_fallback_color = value
		queue_redraw()
@export var valid_color := Color(0.3, 1.0, 0.3, 0.45):
	set(value):
		valid_color = value
		queue_redraw()
@export var invalid_color := Color(1.0, 0.3, 0.3, 0.45):
	set(value):
		invalid_color = value
		queue_redraw()
@export var border_color := Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		border_color = value
		queue_redraw()

# *=================================================
# *
# * Engine Methods
# *
# *=================================================

func _ready() -> void:
	set_process(false)
	
	if not PlayerInventory.state_changed.is_connected(_on_inventory_changed):
		PlayerInventory.state_changed.connect(_on_inventory_changed)

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(_delta: float) -> void:
	queue_redraw()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			set_process(true)
		NOTIFICATION_DRAG_END:
			set_process(false)
			queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()

func _get_minimum_size() -> Vector2:
	if closed:
		return Vector2.ZERO
	
	var primary: InventoryState = PlayerInventory.get_inventory()
	if primary == null:
		return Vector2.ZERO
	
	var total: Vector2 = _inventory_pixel_size(primary)

	var secondary: InventoryState = _get_secondary()
	if secondary != null:
		var secondary_size: Vector2 = _inventory_pixel_size(secondary)
		total.x += secondary_size.x + inventory_gap
		total.y = maxf(total.y, secondary_size.y)

	return total

func _draw() -> void:
	if closed:
		return
	
	for layout: Dictionary in _get_layouts():
		_draw_inventory(layout["state"], layout["rect"])
	_draw_drop_preview()

func _get_drag_data(at_position: Vector2) -> Variant:
	var layout: Dictionary = _layout_at(at_position)
	if layout.is_empty():
		return null
	
	var state: InventoryState = layout["state"]
	var rect: Rect2 = layout["rect"]
	var cell: Vector2i = _pos_to_cell(rect, at_position)

	var id: int = state.get_item_id_at(cell.x, cell.y)
	if id == InventoryState.EMPTY_ID:
		return null
	
	var item: InventoryState.InventoryItem = state.get_item(id)
	var payload: DragPayload = DragPayload.new(
		id,
		item,
		state,
		cell - item.origin
	)

	set_drag_preview(_make_drag_preview(item, payload.grab_offset))
	queue_redraw()

	return payload

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if closed:
		return true
	
	var payload := data as DragPayload
	if payload == null:
		return false
	
	var drop: Dictionary = _resolve_drop(at_position, payload)
	return not drop.is_empty() and drop["valid"]

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if closed:
		return
	
	var payload := data as DragPayload
	if payload == null:
		return
	
	var drop: Dictionary = _resolve_drop(at_position, payload)
	if drop.is_empty() or not drop["valid"]:
		return
	
	var target: InventoryState = drop["state"]
	var origin: Vector2i = drop["origin"]

	if target == payload.source:
		target.try_move(origin.x, origin.y, payload.id)
	else:
		var spatial: SpatialItem = payload.source.remove_by_id(payload.id)
		if spatial != null:
			target.try_place(origin.x, origin.y, spatial)
	
	queue_redraw()

# *=================================================
# *
# * Helper Methods
# *
# *=================================================

func _get_secondary() -> InventoryState:
	if secondary_provider == null:
		return null
	return secondary_provider.get_inventory()

func _cell_step() -> Vector2:
	return Vector2(
		cell_size.x + cell_gap,
		cell_size.y + cell_gap
	)

func _cell_rect(rect: Rect2, cell: Vector2i) -> Rect2:
	return Rect2(
		rect.position + Vector2(cell) * _cell_step(),
		Vector2(cell_size)
	)

func _inventory_pixel_size(state: InventoryState) -> Vector2:
	var cell_step: Vector2 = _cell_step()
	return Vector2(
		state.width * cell_step.x - cell_gap,
		state.height * cell_step.y - cell_gap
	)

func _on_inventory_changed() -> void:
	update_minimum_size()
	queue_redraw()

func _rig_state(old_getter: InventoryProvider, new_getter: InventoryProvider):
	var state: InventoryState = old_getter.get_inventory() if old_getter != null else null
	if state != null and state.changed.is_connected(_on_inventory_changed):
		state.changed.disconnect(_on_inventory_changed)
	
	var new_state: InventoryState = new_getter.get_inventory() if new_getter != null else null
	if new_state != null and not new_state.changed.is_connected(_on_inventory_changed):
		new_state.changed.connect(_on_inventory_changed)

func _get_layouts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if closed:
		return result
	
	var primary: InventoryState = PlayerInventory.get_inventory()
	if primary == null:
		return result
	
	var primary_size: Vector2 = _inventory_pixel_size(primary)
	var secondary_size: Vector2 = Vector2.ZERO
	var total_width: float = primary_size.x

	var secondary: InventoryState = _get_secondary()
	if secondary != null:
		secondary_size = _inventory_pixel_size(secondary)
		total_width += secondary_size.x + inventory_gap

	var x: float = (size.x - total_width) * 0.5

	if secondary != null:
		result.append({
			"state": secondary,
			"rect": Rect2(
				Vector2(x, (size.y - secondary_size.y) * 0.5),
				secondary_size
			)
		})

		x += secondary_size.x + inventory_gap
	
	result.append({
		"state": primary,
		"rect": Rect2(
			Vector2(x, (size.y - primary_size.y) * 0.5),
			primary_size
		)
	})
	
	return result

func _layout_at(pos: Vector2) -> Dictionary:
	for layout: Dictionary in _get_layouts():
		var rect: Rect2 = layout["rect"]
		if rect.has_point(pos):
			return layout
	
	return {}

func _pos_to_cell(rect: Rect2, pos: Vector2) -> Vector2i:
	var cell_step: Vector2 = _cell_step()
	var local: Vector2 = pos - rect.position
	return Vector2i(
		floori(local.x / max(1, cell_step.x)),
		floori(local.y / max(1, cell_step.y))
	)

func _drop_is_valid(payload: DragPayload, target: InventoryState, origin: Vector2i) -> bool:
	if target == payload.source:
		return target.can_move(origin.x, origin.y, payload.id)
	return target.can_place(origin.x, origin.y, payload.item.metadata)

func _resolve_drop(pos: Vector2, payload: DragPayload) -> Dictionary:
	var layout: Dictionary = _layout_at(pos)
	if layout.is_empty():
		return {}
	
	var state: InventoryState = layout["state"]
	var rect: Rect2 = layout["rect"]
	var origin: Vector2i = _pos_to_cell(rect, pos) - payload.grab_offset

	return {
		"state": state,
		"origin": origin,
		"valid": _drop_is_valid(payload, state, origin),
	}

# *=================================================
# *
# * Drawing
# *
# *=================================================

func _make_drag_preview(item: InventoryState.InventoryItem, grab_offset: Vector2i) -> Control:
	var visual: ItemPreview = ItemPreview.new(self, item.metadata)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.modulate = Color(1.0, 1.0, 1.0, 0.75)
	visual.position = -(Vector2(grab_offset) * _cell_step() + Vector2(cell_size) * 0.5)

	var root: Control = Control.new()
	root.add_child(visual)
	return root

func _draw_inventory(state: InventoryState, rect: Rect2) -> void:
	var dragged_id: int = InventoryState.EMPTY_ID
	var payload: Variant = get_viewport().gui_get_drag_data()
	if payload is DragPayload and payload.source == state:
		dragged_id = payload.id
	
	for y in state.height:
		for x in state.width:
			var cell_rect: Rect2 = _cell_rect(rect, Vector2i(x, y))
			draw_rect(cell_rect, empty_color)
			draw_rect(cell_rect, border_color, false, cell_border_width)
	
	var cell_step: Vector2 = _cell_step()
	for id: int in state.get_item_ids():
		if id == dragged_id:
			continue
		
		var item: InventoryState.InventoryItem = state.get_item(id)
		var item_pos: Vector2 = rect.position + Vector2(item.origin) * cell_step
		_draw_item_on(self, item.metadata, item_pos)

func _draw_drop_preview() -> void:
	var payload := get_viewport().gui_get_drag_data() as DragPayload
	if payload == null:
		return
	
	var drop: Dictionary = _resolve_drop(get_local_mouse_position(), payload)
	if drop.is_empty():
		return
	
	var target: InventoryState = drop["state"]
	var origin: Vector2i = drop["origin"]
	var color: Color = valid_color if drop["valid"] else invalid_color
	var spatial: SpatialItem = payload.item.metadata

	for layout: Dictionary in _get_layouts():
		if layout["state"] != target:
			continue
		
		var rect: Rect2 = layout["rect"]
		for iy in spatial.grid_height:
			var row_idx: int = iy * spatial.grid_width
			for ix in spatial.grid_width:
				if not spatial.grid_pattern[row_idx + ix]:
					continue
				
				var cell: Vector2i = origin + Vector2i(ix, iy)
				if cell.x < 0 or cell.y < 0 or cell.x >= target.width or cell.y >= target.height:
					continue
				
				draw_rect(_cell_rect(rect, cell), color)

func _draw_item_on(canvas: CanvasItem, spatial: SpatialItem, pos: Vector2, tint: Color = Color.WHITE) -> void:
	var cell_step: Vector2 = _cell_step()
	var item_px: Vector2 = Vector2(spatial.grid_width, spatial.grid_height) * cell_step - Vector2(cell_gap, cell_gap)
	var texture: Texture2D = spatial.item_image
	var texture_size: Vector2 = texture.get_size() if texture != null else Vector2.ZERO

	for iy in spatial.grid_height:
		var row_idx: int = iy * spatial.grid_width
		for ix in spatial.grid_width:
			if not spatial.grid_pattern[row_idx + ix]:
				continue
			
			var local: Vector2 = Vector2(ix, iy) * cell_step
			var dest: Rect2 = Rect2(pos + local, Vector2(cell_size))

			if texture == null:
				canvas.draw_rect(dest, item_fallback_color * tint)
			else:
				var src: Rect2 = Rect2(
					local / item_px * texture_size,
					Vector2(cell_size) / item_px * texture_size
				)

				canvas.draw_texture_rect_region(texture, dest, src, tint)

# *=================================================
# *
# * Public API
# *
# *=================================================

func open(provider: InventoryProvider = null) -> void:
	if provider != null:
		secondary_provider = provider
	
	closed = false

func close(clear_secondary: bool = true) -> void:
	closed = true

	if clear_secondary:
		secondary_provider = null

func toggle(provider: InventoryProvider = null) -> void:
	if closed:
		open(provider)
	else:
		close(true)

func set_secondary(provider: InventoryProvider) -> void:
	secondary_provider = provider

func is_open() -> bool:
	return not closed
