extends CookingStep

@export var presses: int = 20
@export var stages: int = 14
@export var time_limit: float = 5.0

@onready var head: Sprite2D = $Head
@onready var leaf: Sprite2D = $Leaf
@onready var time_bar: ProgressBar = $TimeBar
@onready var crunch_sound: AudioStreamPlayer = $Crunch

var count: int
var time_left: float

func _ready() -> void:
	time_left = time_limit
	time_bar.max_value = time_limit


func _process(delta: float) -> void:
	time_left -= delta
	time_bar.value = time_left
	if time_left <= 0.0:
		_finish()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Cook"):
		count += 1
		head.frame = mini(count * stages / presses, stages - 1)
		_squish_n_fling()
		if count >= presses:
			_finish()

func _finish() -> void:
	done.emit(float(count) / presses)

# thick
func _squish_n_fling() -> void:
	var tween := create_tween()
	tween.tween_property(head, "scale", Vector2(5, 3), 0.05) # squish
	tween.tween_property(head, "scale", Vector2(4, 4), 0.1) # reform
	crunch_sound.pitch_scale = randf_range(0.9, 1.2)
	crunch_sound.play()
	var leaf_fling: Sprite2D = leaf.duplicate()
	add_child(leaf_fling)
	leaf_fling.show()
	leaf_fling.frame = [15, 16].pick_random()
	var t := leaf_fling.create_tween().set_parallel()
	t.tween_property(leaf_fling, "position", leaf_fling.position + Vector2(randf_range(-200, 200), randf_range(-200, -80)), 0.5)
	t.tween_property(leaf_fling, "rotation", randf_range(-PI, PI), 0.5)
	t.tween_property(leaf_fling, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(leaf_fling.queue_free)
