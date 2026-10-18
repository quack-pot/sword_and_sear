class_name CampRoom
extends Node3D

@export_category("Room Size")
@export_range(1, 32, 1, "or_greater") var width: int = 6
@export_range(1, 32, 1, "or_greater") var height: int = 6

@export_category("Visuals")
@export_range(1, 10, 0.5, "or_greater") var cell_size: float = 2.0

@export var floor_prefab: PackedScene
@export var wall_prefab: PackedScene

func _ready() -> void:
	_generate_visuals()

func _spawn_tile(prefab: PackedScene, x: int, y: int) -> void:
	if prefab == null:
		return

	var tile: Node3D = prefab.instantiate() as Node3D
	add_child(tile)
	tile.position = Vector3((x + 0.5) * cell_size, 0.0, (y + 0.5) * cell_size)

func _generate_visuals() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collider: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(cell_size * width, 0.01, cell_size * height)
	floor_collider.shape = floor_shape
	floor_body.add_child(floor_collider)
	floor_body.position = Vector3(
		cell_size * width * 0.5,
		- cell_size,
		cell_size * height * 0.5
	)
	add_child(floor_body)

	for y in range(-1, height + 1):
		for x in range(-1, width + 1):
			var is_floor: bool = x >= 0 and y >= 0 and x < width and y < height
			if is_floor:
				_spawn_tile(floor_prefab, x, y)
				continue

			_spawn_tile(wall_prefab, x, y)

			var wall_body: StaticBody3D = StaticBody3D.new()
			var wall_collider: CollisionShape3D = CollisionShape3D.new()
			var wall_shape: BoxShape3D = BoxShape3D.new()
			wall_shape.size = Vector3(cell_size, cell_size, cell_size)
			wall_collider.shape = wall_shape
			wall_body.collision_mask = 2
			wall_body.collision_layer = 2
			wall_body.add_child(wall_collider)
			wall_body.position = Vector3(
				(x + 0.5) * cell_size,
				0.0,
				(y + 0.5) * cell_size
			)
			add_child(wall_body)
