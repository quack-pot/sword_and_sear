class_name DungeonFloorGenerator
extends Node3D

enum Cell { WALL, FLOOR }
const DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

const PLAYER_SCENE = preload("res://entities/dungeon_crawler/dungeon_player.scn")

@export_category("Generation Parameters")
@export_range(1, 256, 1, "or_greater") var width: int = 64
@export_range(1, 256, 1, "or_greater") var height: int = 64

@export_range(4, 15, 1, "or_greater") var room_min_width: int = 4
@export_range(4, 15, 1, "or_greater") var room_max_width: int = 10:
	set(value):
		room_max_width = maxi(value, room_min_width + 1)

@export_range(4, 15, 1, "or_greater") var room_min_height: int = 4
@export_range(4, 15, 1, "or_greater") var room_max_height: int = 10:
	set(value):
		room_max_height = maxi(value, room_min_height + 1)

@export_range(2, 10, 1, "or_greater") var min_room_gap: int = 2

@export_range(0.0, 0.9, 0.01) var path_randomness: float = 0.15

@export_category("Visuals")
@export_range(1, 10, 0.5, "or_greater") var cell_size: float = 2.0

@export var wall_prefabs: Array[Mesh] = []
@export var floor_prefabs: Array[Mesh] = []

var _grid: Array[Cell] = []
var _rooms: Array[Rect2i] = []
var _room_depth: Array[int] = []
var _room_edges: Array[Vector2i] = []
var _corridors: Array[Array] = [] # 2D Array of Vector2i

var _start_room: int = -1
var _end_room: int = -1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	generate_floor(0, 0)

func generate_floor(
	level: int,
	random_seed: int,
	room_attempts: int = 80,
	extra_loops: int = 4
) -> void:
	_rng.seed = random_seed
	
	_grid.resize(width * height)
	_grid.fill(Cell.WALL)

	_place_rooms(room_attempts)
	if _rooms.size() < 2: # Extremely rare, but just in case
		generate_floor(random_seed + 1, room_attempts, extra_loops)
		return
	
	_connect_rooms(extra_loops)
	_select_start_and_end()

	_generate_visuals()
	_populate_dungeon(level)

# *=================================================
# *
# * Helper Methods
# *
# *=================================================

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func _is_floor(x: int, y: int) -> bool:
	return _in_bounds(x, y) and _grid[(y * width) + x] == Cell.FLOOR

func _touches_floor(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return false
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _is_floor(x + dx, y + dy):
				return true
	
	return false

func _has_edge(a: int, b: int) -> bool:
	for edge in _room_edges:
		if (edge.x == a and edge.y == b) or (edge.x == b or edge.y == a):
			return true
	return false

func _room_center(idx: int) -> Vector2i:
	if idx < _rooms.size():
		var room: Rect2i = _rooms[idx]
		return room.position + Vector2i(
			room.size.x >> 1,
			room.size.y >> 1
		)
	return Vector2i.ZERO

func _room_distances(source_index: int) -> Array[int]:
	var distances: Array[int] = []
	distances.resize(_rooms.size())
	distances.fill(-1)
	distances[source_index] = 0

	var queue: Array[int] = [source_index]
	while not queue.is_empty():
		var cur_index: int = queue.pop_front()
		for edge in _room_edges:
			var other: int = -1
			if edge.x == cur_index:
				other = edge.y
			elif edge.y == cur_index:
				other = edge.x
			
			if other != -1 and distances[other] == -1:
				distances[other] = distances[cur_index] + 1
				queue.append(other)
	
	return distances

func _farthest_from(source_index: int) -> int:
	var distances: Array[int] = _room_distances(source_index)
	
	var best_index: int = source_index
	var best_distance: int = 0

	for index in distances.size():
		var distance: int = distances[index]
		if distance > best_distance:
			best_distance = distance
			best_index = index
	
	return best_index

# *=================================================
# *
# * Generation Methods
# *
# *=================================================

func _place_rooms(attempts: int) -> void:
	for _attempt in attempts:
		var room_width: int = _rng.randi_range(room_min_width, room_max_width)
		var room_height: int = _rng.randi_range(room_min_height, room_max_height)

		var max_x: int = width - room_width - 2
		var max_y: int = height - room_height - 2

		if max_x < 1 or max_y < 1:
			continue
		
		var room: Rect2i = Rect2i(
			_rng.randi_range(1, max_x),
			_rng.randi_range(1, max_y),
			room_width,
			room_height
		)

		var overlaps: bool = false
		for other in _rooms:
			if room.grow(min_room_gap).intersects(other):
				overlaps = true
				break
		
		if overlaps:
			continue
		
		_rooms.append(room)
		for y in range(room.position.y, room.end.y):
			var row_idx: int = y * width
			for x in range(room.position.x, room.end.x):
				_grid[row_idx + x] = Cell.FLOOR

func _carve_corridor(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var point: Vector2i = from
	var guard: int = _grid.size() * 4

	while point != to and guard > 0:
		guard -= 1

		_grid[(point.y * width) + point.x] = Cell.FLOOR
		cells.append(point)

		var dx: int = signi(to.x - point.x)
		var dy: int = signi(to.y - point.y)

		var roll: float = _rng.randf()
		if roll < path_randomness:
			point += DIRS[_rng.randi_range(0, DIRS.size() - 1)]
			point = point.clamp(
				Vector2i.ONE,
				Vector2i(
					width >> 1,
					height >> 1
				)
			)
		elif (roll < (path_randomness + 1.0) * 0.5 and dx != 0) or dy == 0:
			point.x += dx
		else:
			point.y += dy
	
	_grid[(to.y * width) + to.x] = Cell.FLOOR
	cells.append(to)

	return cells

func _add_edge(a: int, b: int) -> void:
	_room_edges.append(Vector2i(a, b))
	_corridors.append(_carve_corridor(_room_center(a), _room_center(b)))

# Prim's minimum spanning tree over room centers guarantees connections.
func _connect_rooms(extra_loops: int) -> void:
	var connected: Array[int] = [0]
	var remaining: Array[int] = []
	for idx in range(1, _rooms.size()):
		remaining.append(idx)
	
	while not remaining.is_empty():
		var best_a: int = -1
		var best_b: int = -1
		var best_dist: float = INF

		for a in connected:
			for b in remaining:
				var distance: float = Vector2(
					_room_center(a)
				).distance_to(Vector2(
					_room_center(b)
				))

				if distance < best_dist:
					best_a = a
					best_b = b
					best_dist = distance
		
		_add_edge(best_a, best_b)
		connected.append(best_b)
		remaining.erase(best_b)
	
	var added: int = 0
	var tries: int = extra_loops * 6
	while added < extra_loops and tries > 0:
		tries -= 1
		
		var a := _rng.randi_range(0, _rooms.size() - 1)
		var b := _rng.randi_range(0, _rooms.size() - 1)
		
		if a == b or _has_edge(a, b):
			continue
		
		_add_edge(a, b)
		added += 1

func _select_start_and_end() -> void:
	var first: int = _farthest_from(0)
	var depths: Array[int] = _room_distances(first)
	var second: int = 0
	
	for idx in depths.size():
		if depths[idx] > depths[second]:
			second = idx
	
	_start_room = first
	_end_room = second
	_room_depth = depths

func _generate_visuals() -> void:
	for child in get_children():
		child.queue_free()
	
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collider: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(cell_size * width, 0.01, cell_size * height)
	floor_collider.shape = floor_shape
	floor_body.add_child(floor_collider)
	floor_body.position = Vector3(
		cell_size * width * 0.5,
		-cell_size,
		cell_size * height * 0.5
	)
	add_child(floor_body)
	
	var grid_map: GridMap = GridMap.new()
	
	grid_map.name = "DungeonGrid"
	grid_map.cell_size = Vector3(cell_size, cell_size, cell_size)
	grid_map.cell_center_y = false
	
	var lib: MeshLibrary = MeshLibrary.new()
	var lib_index: int = 0
	
	for prefab in floor_prefabs:
		lib.create_item(lib_index)
		lib.set_item_name(lib_index, "floor_{lib_index}".format({"lib_index": lib_index}))
		lib.set_item_mesh(lib_index, prefab)
		lib_index += 1
	
	for prefab in wall_prefabs:
		lib.create_item(lib_index)
		lib.set_item_name(lib_index, "wall_{lib_index}".format({"lib_index": lib_index}))
		lib.set_item_mesh(lib_index, prefab)
		lib_index += 1
	
	grid_map.mesh_library = lib
	
	for y in height:
		for x in width:
			if _is_floor(x, y):
				grid_map.set_cell_item(
					Vector3i(x, 0, y),
					randi_range(0, floor_prefabs.size() - 1)
				)
			elif _touches_floor(x, y):
				grid_map.set_cell_item(
					Vector3i(x, 0, y),
					floor_prefabs.size() + randi_range(0, wall_prefabs.size() - 1)
				)
				var wall_body: StaticBody3D = StaticBody3D.new()
				var wall_collider: CollisionShape3D = CollisionShape3D.new()
				var wall_shape: BoxShape3D = BoxShape3D.new()
				wall_shape.size = Vector3(cell_size, cell_size, cell_size)
				wall_collider.shape = wall_shape
				wall_body.add_child(wall_collider)
				wall_body.position = Vector3(
					(x + 0.5) * cell_size,
					0.0,
					(y + 0.5) * cell_size
				)
				add_child(wall_body)
	
	add_child(grid_map)

func _populate_dungeon(_level: int) -> void:
	var start_room_center: Vector2i = _room_center(_start_room)
	
	var player: Node3D = PLAYER_SCENE.instantiate()
	player.position = Vector3(
		start_room_center.x * cell_size,
		0.0,
		start_room_center.y * cell_size
	)
	add_child(player)
