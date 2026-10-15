extends CookingStep

@export var presses: int = 20
@export var stages: int = 14
@export var time_limit: float = 5.0

@onready var head: Sprite2D = $Head
@onready var leaf: Sprite2D = $Leaf
@onready var time_bar: ProgressBar = $TimeBar

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
		if count >= presses:
			_finish()

func _finish() -> void:
	done.emit(float(count / presses))
