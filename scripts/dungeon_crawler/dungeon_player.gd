class_name DungeonPlayer
extends Node3D

@export_group("Player Data")
@export var inventory: InventoryState = null

@export_group("Wall Cutout")
@export_flags_3d_physics var occluder_collision_mask: int = 2
@export var occlusion_sample_offsets: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(0.0, -0.4, 0.0),
	Vector3(0.0, 0.4, 0.0),
]
@export var occlusion_tolerance: float = 0.15
@export var cutout_open_time: float = 0.15 # s
@export var cutout_close_time: float = 0.3 # s

@export_group("Mouse Movement")
@export_flags_3d_physics var click_collision_mask: int = 1
@export var ray_length: float = 1000.0;

@export var mouse_indicator: PackedScene
@export var mouse_indicator_offset: float = 1.0

@export_group("General Movement")
@export var do_keyboard_movement: bool = true

@export var max_velocity: float = 10.0 # m/s
@export var acceleration: float = 40.0 # m/s^2
@export var deceleration: float = 60.0 # m/s^2

@onready var rigidbody: RigidBody3D = $RigidBody3D
@onready var sprite: Sprite3D = $RigidBody3D/Sprite3D
@onready var nav_agent: NavigationAgent3D = $RigidBody3D/NavigationAgent3D

@export_group("Camera Movement")
@export var camera_track_speed: float = 5.0 # Percent Distance /s

@onready var camera: Camera3D = $Camera3D
@onready var camera_track_offset: Vector3 = camera.position - rigidbody.position

var up_press: bool = false
var down_press: bool = false
var left_press: bool = false
var right_press: bool = false
var input_dir: Vector2 = Vector2.ZERO

var click_requested: bool = false
var has_destination: bool = false

var cutout_target: float = 0.0
var cutout_amount: float = 0.0

func _get_button(event: InputEvent, action: StringName, previous: bool) -> bool:
	if event.is_action_pressed(action):
		return true
	if event.is_action_released(action):
		return false
	return previous

func _input(event: InputEvent) -> void:
	up_press = _get_button(event, "Up", up_press)
	down_press = _get_button(event, "Down", down_press)
	left_press = _get_button(event, "Left", left_press)
	right_press = _get_button(event, "Right", right_press)
	
	input_dir.x = float(right_press) - float(left_press)
	input_dir.y = float(down_press) - float(up_press)
	input_dir = input_dir.normalized()

func _unhandled_input(event: InputEvent) -> void:
	if do_keyboard_movement:
		return
	
	if event is InputEventMouseButton:
		var mouseEvent = event as InputEventMouseButton
		if mouseEvent.button_index == MOUSE_BUTTON_LEFT and mouseEvent.pressed:
			click_requested = true

func _do_camera_movement(delta: float) -> void:
	camera.position = lerp(
		camera.position,
		rigidbody.position + camera_track_offset,
		camera_track_speed * delta
	)
	
	RenderingServer.global_shader_parameter_set(
		"player_position",
		rigidbody.global_position
	)
	RenderingServer.global_shader_parameter_set(
		"camera_position",
		camera.global_position
	)
	RenderingServer.global_shader_parameter_set(
		"camera_forward",
		-camera.global_basis.z
	)

func _update_occlusion_target() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var blocked: bool = false
	
	for offset in occlusion_sample_offsets:
		var target: Vector3 = rigidbody.global_position + offset
		var origin: Vector3 = camera.project_ray_origin(
			camera.unproject_position(target)
		)
		var end: Vector3 = target.move_toward(origin, occlusion_tolerance)
		
		var query := PhysicsRayQueryParameters3D.create(
			origin, end, occluder_collision_mask
		)
		query.exclude = [rigidbody.get_rid()]
		
		if not space.intersect_ray(query).is_empty():
			blocked = true
			break
	
	cutout_target = 1.0 if blocked else 0.0
 
func _update_cutout(delta: float) -> void:
	var time: float = cutout_open_time if cutout_target > cutout_amount \
		else cutout_close_time
	cutout_amount = move_toward(cutout_amount, cutout_target, delta / maxf(time, 0.001))
	RenderingServer.global_shader_parameter_set("cutout_amount", cutout_amount)

func _process(delta: float) -> void:
	_do_camera_movement(delta)
	_update_cutout(delta)

func _apply_horizontal_velocity(target_velocity: Vector3, step: float) -> void:
	var vel: Vector3 = rigidbody.linear_velocity
	var horizontal := Vector3(vel.x, 0.0, vel.z)
	horizontal = horizontal.move_toward(target_velocity, step)
	rigidbody.linear_velocity = Vector3(horizontal.x, vel.y, horizontal.z)
 
func _do_keyboard_movement(delta: float) -> void:
	var has_input: bool = input_dir.length_squared() > 0.0
	var frame_acceleration: float = (
		acceleration if has_input else deceleration
	) * delta
	
	var yaw: float = camera.global_rotation.y
	var cam_basis := Basis(Vector3.UP, yaw)
	
	var local_dir := Vector3(input_dir.x, 0.0, input_dir.y)
	var target_velocity: Vector3 = (cam_basis * local_dir) * max_velocity
	
	_apply_horizontal_velocity(target_velocity, frame_acceleration)
 
func _nav_map_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) != 0
 
func _handle_click() -> void:
	if not click_requested or not _nav_map_ready():
		return
	
	click_requested = false
	
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var end: Vector3 = origin + camera.project_ray_normal(mouse_pos) * ray_length
	
	var query := PhysicsRayQueryParameters3D.create(origin, end, click_collision_mask)
	query.exclude = [rigidbody.get_rid()]
	
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	
	var map: RID = nav_agent.get_navigation_map()
	var hit_pos: Vector3 = hit["position"]
	var hit_norm: Vector3 = hit["normal"]
	
	if mouse_indicator != null:
		var indicator: Node3D = mouse_indicator.instantiate()
		get_tree().current_scene.add_child(indicator)
		
		var ind_pos := NavigationServer3D.map_get_closest_point(map, hit_pos)
		indicator.global_position = ind_pos + hit_norm * mouse_indicator_offset
		
		var ind_up := hit_norm.normalized()
		var ind_ref := Vector3.FORWARD if absf(ind_up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		var ind_x := ind_up.cross(ind_ref).normalized()
		var ind_z := ind_x.cross(ind_up).normalized()
		
		indicator.global_transform.basis = Basis(ind_x, ind_up, ind_z)
	
	nav_agent.target_position = NavigationServer3D.map_get_closest_point(
		map, hit_pos
	)
	has_destination = true

func _remaining_path_length() -> float:
	var path: PackedVector3Array = nav_agent.get_current_navigation_path()
	var index: int = nav_agent.get_current_navigation_path_index()
	var pos: Vector3 = rigidbody.global_position
	var prev := Vector3(pos.x, 0.0, pos.z)
	var total: float = 0.0
	for i in range(index, path.size()):
		var point := Vector3(path[i].x, 0.0, path[i].z)
		total += prev.distance_to(point)
		prev = point
	return total
 
func _do_mouse_movement(delta: float) -> void:
	_handle_click()
	
	if has_destination and _nav_map_ready() and nav_agent.is_navigation_finished():
		has_destination = false
	
	var target_velocity := Vector3.ZERO
	
	if has_destination and _nav_map_ready():
		var next_position: Vector3 = nav_agent.get_next_path_position()
		var to_next: Vector3 = next_position - rigidbody.global_position
		to_next.y = 0.0
		
		if to_next.length_squared() > 0.01:
			var brake_speed: float = sqrt(
				2.0 * deceleration * _remaining_path_length()
			)
			var speed: float = minf(max_velocity, brake_speed)
			target_velocity = to_next.normalized() * speed
	
	var vel: Vector3 = rigidbody.linear_velocity
	var current_speed: float = Vector3(vel.x, 0.0, vel.z).length()
	var speeding_up: bool = target_velocity.length() > current_speed
	var step: float = (acceleration if speeding_up else deceleration) * delta
	
	_apply_horizontal_velocity(target_velocity, step)

func _can_move() -> bool:
	var inventory_grid: InventoryGrid = InventoryGrid.instance
	if inventory_grid != null and inventory_grid.is_open():
		return false
	
	return true

func _physics_process(delta: float) -> void:
	_update_occlusion_target()
	
	if _can_move():
		if do_keyboard_movement:
			_do_keyboard_movement(delta)
		else:
			_do_mouse_movement(delta)
	else:
		_apply_horizontal_velocity(Vector3.ZERO, deceleration * delta)

func get_inventory() -> InventoryState:
	return inventory
