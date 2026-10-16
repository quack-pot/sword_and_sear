extends CookingStep

@export var stirs: int = 12
@export var time_limit: float = 6.0
@export var tilt_degrees: float = 20.0

@onready var spoon_pivot: Node2D = $Sprites/SpoonPivot
@onready var time_bar: ProgressBar = $TimeBar

var last_side: int

func _ready() -> void:
	time_left = time_limit
	time_bar.max_value = time_limit


func _process(delta: float) -> void:
	time_left -= delta
	time_bar.value = time_left
	if time_left <= 0.0:
		_finish()


func _finish() -> void:
	done.emit(float(count) / presses)