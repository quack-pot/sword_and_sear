class_name DungeonEnemy
extends CharacterBody3D

enum State { IDLE, CHASE }

signal died(enemy: DungeonEnemy)

@export_group("Stats")
@export var max_health: float = 30.0

@export_group("Detection")
@export var detection_range: float = 8.0
@export var alert_range: float = 12.0

@export_group("Movement")
@export var move_speed: float = 4.0 # m/s
@export var acceleration: float = 30.0 # m/s^2
@export var repath_interval: float = 0.2 # s
@export var gravity: float = 20.0 # m/s^2

@export_group("Attack")
@export var attack_range: float = 1.6 # m
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0 # s

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var health: float
var state: State = State.IDLE
var player: DungeonPlayer = null
var repath_timer: float = 0.0
var attack_timer: float = 0.0

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

func _get_player() -> DungeonPlayer:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as DungeonPlayer
	return player

func _player_position() -> Vector3:
	return _get_player().rigidbody.global_position

func _flat_distance_to_player() -> float:
	var offset: Vector3 = _player_position() - global_position
	offset.y = 0.0
	return offset.length()

func _nav_map_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) != 0

func alert() -> void:
	if state == State.CHASE:
		return
	state = State.CHASE
	repath_timer = 0.0
	attack_timer = attack_interval

func _alert_nearby_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as DungeonEnemy
		if other == null or other == self:
			continue
		if global_position.distance_to(other.global_position) <= alert_range:
			other.alert()

func take_damage(amount: float, _source: Node3D = null) -> void:
	health -= amount
	if state == State.IDLE and _get_player() != null:
		alert()
		_alert_nearby_enemies()
	if health <= 0.0:
		died.emit(self)
		queue_free()

func _physics_process(delta: float) -> void:
	if _get_player() == null:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
	
	move_and_slide()

func _process_idle(delta: float) -> void:
	_set_horizontal_velocity(Vector3.ZERO, delta)
	
	if _flat_distance_to_player() <= detection_range:
		alert()
		_alert_nearby_enemies()

func _process_chase(delta: float) -> void:
	var in_range: bool = _flat_distance_to_player() <= attack_range
	
	if in_range:
		_set_horizontal_velocity(Vector3.ZERO, delta)
		_face_position(_player_position())
		
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_interval
			_attack()
		return
	
	attack_timer = minf(attack_timer, attack_interval)
	
	if not _nav_map_ready():
		return
	
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = repath_interval
		nav_agent.target_position = _player_position()
	
	if nav_agent.is_navigation_finished():
		_set_horizontal_velocity(Vector3.ZERO, delta)
		return
	
	var next_position: Vector3 = nav_agent.get_next_path_position()
	var to_next: Vector3 = next_position - global_position
	to_next.y = 0.0
	
	if to_next.length_squared() > 0.001:
		var dir: Vector3 = to_next.normalized()
		_set_horizontal_velocity(dir * move_speed, delta)
		_face_position(global_position + dir)
	else:
		_set_horizontal_velocity(Vector3.ZERO, delta)

func _set_horizontal_velocity(target: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

func _face_position(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_squared_to(global_position) > 0.001:
		look_at(flat, Vector3.UP)

func _attack() -> void:
	var target: Node = _get_player()
	if target != null and target.has_method("take_damage"):
		target.take_damage(attack_damage, self)