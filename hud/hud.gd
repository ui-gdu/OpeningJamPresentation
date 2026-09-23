extends Control

@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var hearts_empty = $HeartsEmpty
@onready var hearts_full = $HeartsFull

func _ready():
	visible = is_mobile()

func _process(_delta):
	if player:
		hearts_full.size.x = 18 * player.hp

func is_mobile() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")
