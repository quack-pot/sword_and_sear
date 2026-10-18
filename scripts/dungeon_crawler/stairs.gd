class_name Stairs
extends Node3D

@export_file("*.tscn") var next_scene: String = "res://scenes/scn_camp.tscn"

@onready var interact_area: Area3D = $Area3D
var in_range: bool = false

func _setup_interactions() -> void:
	if interact_area == null:
		push_warning("Stairs have no interaction area assigned.")
		return
	
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _ready() -> void:
	_setup_interactions()

func _unhandled_input(event: InputEvent) -> void:
	if not in_range:
		return
	
	if event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(next_scene)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = true

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	in_range = false
