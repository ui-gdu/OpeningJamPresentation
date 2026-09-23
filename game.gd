extends Node

const Host := preload("res://server/host.tscn")
const Client := preload("res://server/client.tscn")

var fullscreen = false

func _ready():
	var args := OS.get_cmdline_args()
	if "--host" in args:
		add_child(Host.instantiate())
	else: # elif "--client" in args:
		# assumes client
		add_child(Client.instantiate())

func _process(_delta):
	if Input.is_action_just_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)
