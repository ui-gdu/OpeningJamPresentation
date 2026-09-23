extends Node

const Ghost := preload("res://player/ghost.tscn")

#@export var websocket_url = "ws://localhost:9080"
#@export var websocket_url = "wss://gdu.socksdev.win"
@export var websocket_url = "wss://gdu.gleeze.com" # Have to use a ddns or else adblockers get suspicious of the .win domain ;(

var socket := WebSocketPeer.new()
var state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED

var players := {}
var ghosts := {}

func _ready():
	ensure_connection()

func update_ghosts(dt):
	# updates players
	for id in players.keys():
		if players[id].is_client:
			get_tree().get_first_node_in_group("player").id = id
			continue
		
		if id not in ghosts.keys():
			ghosts[id] = Ghost.instantiate()
			ghosts[id].position.x = players[id].x
			ghosts[id].position.y = players[id].y
			ghosts[id].id = id
			add_child(ghosts[id])
		
		ghosts[id].update(dt, players[id])
	
	# disconnects players
	for id in ghosts.keys():
		if id not in players:
			ghosts[id].disconnected()
			ghosts.erase(id)

func _process(dt):
	update_ghosts(dt)
	
	socket.poll()
	state = socket.get_ready_state()
	get_data()
	
	var username := get_tree().get_first_node_in_group("username")
	if username != null:
		username.visible = state == WebSocketPeer.STATE_OPEN 

func get_data():
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			if socket.was_string_packet():
				var packet_text = packet.get_string_from_utf8()
				players = JSON.parse_string(packet_text)
			else:
				print("< Got binary data from server: %d bytes" % packet.size())

func send_data():
	if state == WebSocketPeer.STATE_OPEN:
		var player = get_tree().get_first_node_in_group("player")
		var data = {x = player.position.x, y = player.position.y}
		var username = get_tree().get_first_node_in_group("username")
		if username != null:
			data.username = username.text.substr(0, 10)
		socket.send_text(JSON.stringify(data))

func ensure_connection():
	if state == WebSocketPeer.STATE_CLOSED:
		var err = socket.connect_to_url(websocket_url)
		if err != OK:
			push_error("Unable to connect. Error code: %d" % err)
		
		remove_all_ghosts()
		players.clear()

func remove_all_ghosts():
	for ghost: Node2D in ghosts.values():
		ghost.disconnected()
	ghosts.clear()
