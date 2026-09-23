extends Sprite2D

const Player := preload("res://player/player.gd")

var link_opened := false

func _on_area_2d_body_entered(body):
	if not OS.has_feature("web"):
		return;
	
	if !link_opened && body is Player:
		OS.shell_open("https://discord.gg/vAMPRjczQV")
		link_opened = true
