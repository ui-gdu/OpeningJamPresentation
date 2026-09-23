extends AnimatableBody2D

const SLAM_RANGE := 18.0

@export var slam_speed: float = 200

@onready var initial_position: Vector2 = position

var slamming := false
var return_speed := slam_speed / 2.0
var previous_position := position

func _physics_process(delta):
	slam_when_player_near()
	update_slam(delta)
	update_return(delta)
	previous_position = position

func slam_when_player_near():
	if is_ready_to_slam():
		for player: Node2D in get_tree().get_nodes_in_group("player"):
			if in_slam_range(player.position):
				slam()

func update_slam(delta):
	if slamming:
		position.y += slam_speed * delta
		if is_colliding_with_ground():
			slamming = false
			position = previous_position
	
func update_return(delta):
	if not slamming:
		position = position.move_toward(initial_position, return_speed * delta)

## Returns `true` if the positions is in the slam range.
func in_slam_range(p: Vector2) -> bool:
	return abs(p.x - position.x) < SLAM_RANGE && p.y > position.y

func slam():
	slamming = true

## Returns `true` if the node is touching the ground.
func is_colliding_with_ground() -> bool:
	return $SlamArea.get_overlapping_bodies().size() > 1

func is_ready_to_slam():
	return not slamming and initial_position == position
