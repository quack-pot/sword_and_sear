class_name CookingMinigame
extends CanvasLayer

enum Grade {RUINED, GOOD, PERFECT}
signal finished(grade: Grade)

@export var good_threshold := 0.4
@export var perfect_threshold := 0.8
@export var dish_texture: Texture2D

@onready var steps: Control = $Steps
@onready var prompt: Label = $Prompt
@onready var result: Control = $Result
@onready var dish: Sprite2D = $Result/Dish
@onready var grade_label: Label = $Result/Grade

var index: int
var total: float
var grade: Grade
var can_close: bool

func _ready() -> void:
	get_tree().paused = true
	dish.texture = dish_texture
	for step: CookingStep in steps.get_children():
		step.hide()
		step.process_mode = Node.PROCESS_MODE_DISABLED
		step.done.connect(_on_step_done)
	_start_step()

func _start_step() -> void:
	var current: CookingStep = steps.get_child(index)
	current.show()
	current.process_mode = Node.PROCESS_MODE_INHERIT
	prompt.text = current.prompt

func _on_step_done(score: float) -> void:
	total += score
	var current: CookingStep = steps.get_child(index)
	current.hide()
	current.process_mode = Node.PROCESS_MODE_DISABLED
	index += 1
	if index < steps.get_child_count():
		_start_step()
	else:
		_show_result()

func _show_result() -> void:
	var average = total / steps.get_child_count()
	if average >= perfect_threshold:
		grade = Grade.PERFECT
	elif average >= good_threshold:
		grade = Grade.GOOD
	else:
		grade = Grade.RUINED

	prompt.hide()
	result.show()
	grade_label.text = Grade.keys()[grade]

	if grade == Grade.RUINED:
		dish.modulate = Color(0.35, 0.3, 0.3) # make it look burnt
	await get_tree().create_timer(0.5).timeout
	can_close = true

func _input(event: InputEvent) -> void:
	if not can_close:
		return

	if event.is_action_pressed("Cook") or (event is InputEventMouseButton and event.pressed):
		get_tree().paused = false
		finished.emit(grade)
		queue_free()