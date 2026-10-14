class_name DungeonPlayer
extends Node3D

@export var do_keyboard_movement: bool = true

@export_flags_3d_physics var click_collision_mask: int = 1
@export var ray_length: float = 1000.0;

@export var max_velocity: float = 10.0 # m/s
@export var acceleration: float = 40.0 # m/s^2
@export var deceleration: float = 60.0 # m/s^2

@onready var rigidbody: RigidBody3D = $RigidBody3D
@onready var sprite: Sprite3D = $RigidBody3D/Sprite3D
@onready var nav_agent: NavigationAgent3D = $RigidBody3D/NavigationAgent3D

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

func _ready() -> void:
	nav_agent.path_desired_distance = 0.3
	nav_agent.target_desired_distance = 0.2

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

func _process(delta: float) -> void:
	_do_camera_movement(delta)

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
	nav_agent.target_position = NavigationServer3D.map_get_closest_point(
		map, hit["position"]
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

func _physics_process(delta: float) -> void:
	if do_keyboard_movement:
		_do_keyboard_movement(delta)
	else:
		_do_mouse_movement(delta)
