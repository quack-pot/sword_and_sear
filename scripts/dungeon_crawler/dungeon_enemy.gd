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
@export var attack_hit_tolerance: float = 0.4 # m
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0 # s between attacks
@export var attack_hit_delay: float = 0.2 # s
@export var attack_lock_time: float = 0.4 # s

@export_group("Death / Loot")
@export var loot_chest_scene: PackedScene
@export var loot_table_override: LootTable
@export var loot_item_count_override: int = -1
@export var death_delay: float = 0.5 # s

@export_group("Animation")
@export var idle_animation: StringName = &"idle"
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"attack"
@export var hurt_animation: StringName = &"hurt"
@export var death_animation: StringName = &"death"
@export var hurt_anim_time: float = 0.25 # s
@export var hurt_flash_color: Color = Color(1.0, 0.2, 0.2)
@export var hurt_flash_time: float = 0.2 # s

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var sprite: AnimatedSprite3D = get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D

var health: float
var state: State = State.IDLE
var player: DungeonPlayer = null
var repath_timer: float = 0.0
var attack_timer: float = 0.0

var is_dead: bool = false
var is_attacking: bool = false
var pending_hit: bool = false
var attack_state_time: float = 0.0
var hurt_timer: float = 0.0
var facing_dir: Vector3 = Vector3.RIGHT
var hurt_tween: Tween = null

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

func _get_player() -> DungeonPlayer:
	if player == null or not is_instance_valid(player):
		var node: Node = get_tree().get_first_node_in_group("player")
		if node is DungeonPlayer:
			player = node
		elif node != null and node.get_parent() is DungeonPlayer:
			player = node.get_parent()
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
	if state == State.CHASE or is_dead:
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
	if is_dead:
		return
	
	health -= amount
	_flash_hurt()
	if health <= 0.0:
		_die()
		return
	
	hurt_timer = hurt_anim_time
	if not is_attacking:
		_play(hurt_animation, true)
	
	if state == State.IDLE and _get_player() != null:
		alert()
		_alert_nearby_enemies()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	pending_hit = false
	remove_from_group("enemies")
	died.emit(self)
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector3.ZERO
	
	if _has_animation(death_animation):
		sprite.play(death_animation)
		if sprite.sprite_frames.get_animation_loop(death_animation):
			await get_tree().create_timer(death_delay).timeout
		else:
			await sprite.animation_finished
	
	_finish_death.call_deferred()

func _finish_death() -> void:
	_spawn_loot_chest()
	queue_free()

func _spawn_loot_chest() -> void:
	if loot_chest_scene == null:
		push_warning("DungeonEnemy has no loot_chest_scene assigned.")
		return
	
	var chest := loot_chest_scene.instantiate() as Chest
	if chest == null:
		push_warning("loot_chest_scene's root node must be a Chest.")
		return
	
	if loot_table_override != null:
		chest.loot_table = loot_table_override
	if loot_item_count_override >= 0:
		chest.target_item_count = loot_item_count_override
	
	get_parent().add_child(chest)
	chest.global_position = global_position

func _physics_process(delta: float) -> void:
	if is_dead or _get_player() == null:
		return
	
	hurt_timer = maxf(hurt_timer - delta, 0.0)
	
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
	if is_attacking:
		_set_horizontal_velocity(Vector3.ZERO, delta)
		attack_state_time += delta
		
		if pending_hit and attack_state_time >= attack_hit_delay:
			pending_hit = false
			_deal_attack_damage()
		
		if attack_state_time >= attack_lock_time:
			is_attacking = false
		return
	
	var in_range: bool = _flat_distance_to_player() <= attack_range
	
	if in_range:
		_set_horizontal_velocity(Vector3.ZERO, delta)
		_face_position(_player_position())
		
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_interval
			_start_attack()
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
		facing_dir = dir
	else:
		_set_horizontal_velocity(Vector3.ZERO, delta)

func _set_horizontal_velocity(target: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

func _face_position(point: Vector3) -> void:
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		facing_dir = dir.normalized()

func _start_attack() -> void:
	is_attacking = true
	pending_hit = true
	attack_state_time = 0.0
	_play(attack_animation, true)

func _deal_attack_damage() -> void:
	if _flat_distance_to_player() > attack_range + attack_hit_tolerance:
		return
	
	var target: Node = _get_player()
	if target != null and target.has_method("take_damage"):
		target.take_damage(attack_damage, self)

func _has_animation(anim: StringName) -> bool:
	return sprite != null \
		and sprite.sprite_frames != null \
		and sprite.sprite_frames.has_animation(anim)

func _play(anim: StringName, restart: bool = false) -> void:
	if not _has_animation(anim):
		return
	if restart or sprite.animation != anim:
		sprite.play(anim)

func _process(_delta: float) -> void:
	if sprite == null or is_dead:
		return
	
	_update_sprite_flip()
	
	if is_attacking:
		return
	
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if hurt_timer > 0.0:
		_play(hurt_animation)
	elif horizontal_speed > 0.5:
		_play(move_animation)
	else:
		_play(idle_animation)

func _update_sprite_flip() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	
	var side: float = facing_dir.dot(camera.global_basis.x)
	if side < -0.1:
		sprite.flip_h = true
	elif side > 0.1:
		sprite.flip_h = false

func _flash_hurt() -> void:
	if sprite == null:
		return
	
	if hurt_tween != null and hurt_tween.is_valid():
		hurt_tween.kill()
	
	sprite.modulate = hurt_flash_color
	hurt_tween = create_tween()
	hurt_tween.tween_property(sprite, "modulate", Color.WHITE, hurt_flash_time)
