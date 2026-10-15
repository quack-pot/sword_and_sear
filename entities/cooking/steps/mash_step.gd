extends CookingStep

@export var presses: int = 20
@export var stages: int = 14
@export var time_limit: float = 5.0

@onready var head: Sprite2D = $Head
@onready var leaf: Sprite2D = $Leaf
@onready var time_Bar: ProgressBar = $TimeBar