extends CookingStep

@export var sequence: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
@export var key_frames: Array[int] = [2, 4, 6, 8, 13]
@export var frame_time: float = 0.06
@export var min_drag: float = 40.0 # px
@export var mistake_penalty: float = 0.2

@onready var roll: Sprite2D = $Roll
@onready var arrow: Sprite2D = $Arrow
@onready var swipe_sound: AudioStreamPlayer = $Swipe

var index: int
var mistakes: int


var drag_start: Vector2

func _ready():
	_point_arrow()

# visualize like a slingshot
func _input(event: InputEvent) -> void:
	if index >= sequence.size():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start = event.position
		else:
			var drag: Vector2 = event.position - drag_start
			if drag.length() < min_drag:
				return
			_try_input(_to_direction(drag))

func _to_direction(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0 else Vector2.UP

func _try_input(dir: Vector2) -> void:
	if dir != sequence[index]:
		mistakes += 1
		_oof(arrow)
		return
	
	var target: int = key_frames[index]
	var tween := create_tween()
	tween.tween_property(roll, "frame", target, (target - roll.frame) * frame_time)
	index += 1

	swipe_sound.pitch_scale = randf_range(0.9, 1.2)
	swipe_sound.play()

	if index < sequence.size():
		_point_arrow()
	else:
		arrow.hide()
		await tween.finished
		_finish()

func _point_arrow() -> void:
	arrow.rotation = Vector2.UP.angle_to(sequence[index])

func _oof(node: CanvasItem) -> void:
	node.modulate = Color.RED
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.3)

func _finish() -> void:
	done.emit(maxf(0.0, 1.0 - mistakes * mistake_penalty))
