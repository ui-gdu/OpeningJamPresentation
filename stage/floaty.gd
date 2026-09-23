extends Node2D

@export var rotate_range := TAU / 16.0

var elapsed := randf() * TAU
@onready var initial_rotation := rotation
@onready var initial_position := position

func _process(dt: float):
	elapsed += dt * randf_range(0.5, 1.0)
	
	rotation = initial_rotation + sin(elapsed) * rotate_range
	
	position = initial_position + Vector2(sin(elapsed) * 3.0, cos(elapsed) * 3.0)
