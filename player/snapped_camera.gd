extends Camera2D

func _process(_dt):
	global_position = get_parent().global_position
	global_position = (global_position / Vector2(480, 270)).floor() * Vector2(480, 270)
	
	# ensures that the camera will only show slides
	global_position = nearest_slide_at(global_position)

func nearest_slide_at(p: Vector2) -> Vector2:
	var nearest: Control = null
	var min_distance: float = INF
	
	for slide: Control in get_tree().get_nodes_in_group("slide"):
		var distance = slide.global_position.distance_squared_to(p)
		if distance < min_distance:
			min_distance = distance
			nearest = slide
	return nearest.global_position
