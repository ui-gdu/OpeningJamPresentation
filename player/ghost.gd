extends Node2D

@onready var sprite = $Sprite2DCustom
@onready var animation_player = $AnimationPlayer
@onready var character_animations = $CharacterAnimations

var id := 0

func disconnected():
	animation_player.play("disappear")

func update(dt: float, player: Dictionary):
	var pos = position.lerp(Vector2(player.x, player.y), dt * 10.0)
	if pos.x != position.x:
		sprite.flip_h = pos.x > position.x
	
	update_animation(dt, pos)
	position = pos
	
	if "username" in player:
		$Username.text = player.username

func update_animation(dt: float, pos: Vector2):
	sprite.frame_coords.x = $Sprite2D.frame_coords.x
	sprite.frame_coords.y = id % sprite.vframes
	
	if abs(pos.y - position.y) > dt * 2:
		character_animations.play("fall")
	elif pos.distance_to(position) > dt:
		character_animations.play("run")
	else:
		character_animations.play("idle")
