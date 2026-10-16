extends CookingStep

@export var sequence: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
@export var key_frames: Array[int] = [2, 4, 6, 8, 13]
@export var frame_time: float = 0.06
@export var min_drag: float = 40.0 # px
@export var mistake_penalty: float = 0.2

@onready var roll: Sprite2D = $Roll
@onready var arrow: Sprite2D = $Arrow


var drag_start: Vector2

# visualize like a slingshot
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start = event.position
		else:
			var drag: Vector2 = event.position - drag_start
			if drag.length() < min_drag:
				return
			print(_to_direction(drag))

func _to_direction(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0 else Vector2.UP

# check

# animate

# close