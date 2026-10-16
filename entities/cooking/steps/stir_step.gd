extends CookingStep

@export var stirs: int = 24
@export var time_limit: float = 6.0
@export var tilt_degrees: float = 45.0
@export var sway: float = 8.0

@onready var spoon_pivot: Node2D = $Sprites/SpoonPivot
@onready var time_bar: ProgressBar = $TimeBar
@onready var simmering_sound: AudioStreamPlayer = $Simmering
@onready var stir_sound: AudioStreamPlayer = $Stir
@onready var cabbage1: Sprite2D = $Sprites/Cabbage
@onready var cabbage2: Sprite2D = $Sprites/Cabbage2

var last_side: int
var count: int
var time_left: float
var rest_x1: float
var rest_x2: float

func _ready() -> void:
	time_left = time_limit
	time_bar.max_value = time_limit
	rest_x1 = cabbage1.position.x
	rest_x2 = cabbage2.position.x


func _process(delta: float) -> void:
	time_left -= delta
	time_bar.value = time_left
	if time_left <= 0.0:
		_finish()


func _finish() -> void:
	done.emit(float(count) / stirs)


func _input(event: InputEvent) -> void:
	var side := 0
	if event.is_action_pressed("Left"):
		side = 1
	elif event.is_action_pressed("Right"):
		side = -1
	if side == 0 or side == last_side:
		return
	last_side = side
	count += 1
	create_tween().tween_property(spoon_pivot, "rotation", deg_to_rad(tilt_degrees) * side, 0.1)
	stir_sound.play()
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(cabbage1, "position:x", rest_x1 - side * sway, 0.25)
	t.tween_property(cabbage2, "position:x", rest_x2 - side * sway * 0.6, 0.25).set_delay(0.05)
	if count >= stirs:
		_finish()
