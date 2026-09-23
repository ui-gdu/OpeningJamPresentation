extends CharacterBody2D
# Mario-like 2D controller for Godot 4
# - Smooth acceleration / deceleration
# - Variable jump (hold for higher jump)
# - Coyote time and jump buffering
# - Wall slide + wall jump (requires RayLeft and RayRight RayCast2D children)

const Ghost := preload("res://player/ghost.gd")

@export_category("Movement")
@export_range(0.0, 2000.0, 1.0) var walk_speed: float = 180.0
@export var run_speed: float = 300.0
@export var accel: float = 2200.0
@export var deaccel: float = 2000.0
@export var friction: float = 0.0  # when no input, extra damp (not usually needed)

@export_category("Jump")
@export var gravity: float = 2200.0
@export var jump_height: float = 42.0      # pixels
@export var jump_cut_multiplier: float = 0.5  # when releasing jump early, reduces upward speed
@export var max_air_jumps: int = 0         # number of mid-air jumps (0 = none)

@export_category("Grace / Buffer")
@export var coyote_time: float = 0.12      # seconds after leaving ground when jump still allowed
@export var jump_buffer_time: float = 0.10 # seconds before landing to buffer a jump input

@export_category("Wall")
@export var can_wall_slide: bool = true
@export var wall_slide_speed: float = 80.0
@export var wall_jump_horizontal: float = 260.0
@export var wall_jump_vertical: float = 420.0
@export var wall_stick_time: float = 0.12  # short "stick" to wall when pushing toward it

@onready var sprite := $Sprite2DCustom

var id := 0

var hp_max := 3;
var hp = hp_max;

# Internal state
var facing_right: bool = true

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_used: int = 0

var _wall_dir: int = 0        # -1 left, 1 right, 0 none
var _wall_stick_timer: float = 0.0
var _is_wall_sliding: bool = false

var on_player: Node2D = null
var previous_pos := position

func is_grounded() -> bool:
	return is_on_floor() || on_player != null

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_timers(delta)
	var input_dir := _get_input_direction()
	_handle_horizontal_movement(input_dir, delta)
	_handle_wall_logic(delta, input_dir)
	_handle_jump(input_dir)
	move_and_slide()
	_update_animation_hooks()

func _input(event):
	if event.is_action_pressed("slide_last"):
		var pos := global_position
		for slide: Control in get_tree().get_nodes_in_group("slide"):
			var slide_pos := slide.global_position + slide.size
			if (pos == global_position || slide_pos.x > pos.x) && slide_pos.x < global_position.x:
				pos = slide_pos - slide.size / 2.0
		global_position = pos 
			
	if event.is_action_pressed("slide_next"):
		var pos := global_position
		for slide: Control in get_tree().get_nodes_in_group("slide"):
			var slide_pos := slide.global_position
			if (pos == global_position || slide_pos.x < pos.x) && slide_pos.x > global_position.x:
				pos = slide_pos + slide.size / 2.0
		global_position = pos 

func _apply_gravity(delta: float) -> void:
	# increase velocity.y by gravity each frame (positive is down)
	if !is_grounded():
		velocity.y += gravity * delta

func _get_input_direction() -> int:
	var dir := 0
	if Input.is_action_pressed("move_right"):
		dir += 1
	if Input.is_action_pressed("move_left"):
		dir -= 1
	return dir

func _handle_timers(delta: float) -> void:
	# coyote timer
	if is_grounded():
		_coyote_timer = coyote_time
		_air_jumps_used = 0
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	# jump buffer timer
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# wall stick timer
	_wall_stick_timer = max(_wall_stick_timer - delta, 0.0)

func _handle_horizontal_movement(input_dir: int, delta: float) -> void:
	var target_speed: float
	if Input.is_action_pressed("run") and input_dir != 0:
		target_speed = run_speed
	else:
		target_speed = walk_speed
	var desired := input_dir * target_speed

	# acceleration / deceleration
	if abs(desired - velocity.x) < 1.0:
		velocity.x = desired
	elif abs(desired) > abs(velocity.x):
		# accelerating
		velocity.x = move_toward(velocity.x, desired, accel * delta)
	else:
		# decelerating
		velocity.x = move_toward(velocity.x, desired, deaccel * delta)

	# small friction when no input to avoid sliding
	if input_dir == 0 and abs(velocity.x) < 6:
		velocity.x = 0

	# facing
	if input_dir > 0:
		facing_right = true
	elif input_dir < 0:
		facing_right = false

func _handle_wall_logic(delta: float, input_dir: int) -> void:
	# detect wall using RayCast2D children if present; fallback to is_on_wall()
	var ray_left := $RayLeft if has_node("RayLeft") else null
	var ray_right := $RayRight if has_node("RayRight") else null
	_wall_dir = 0
	if ray_left and ray_left.is_enabled() and ray_left.is_colliding():
		_wall_dir = -1
	elif ray_right and ray_right.is_enabled() and ray_right.is_colliding():
		_wall_dir = 1
	elif is_on_wall():
		# fallback guess: use direction of horizontal velocity (not always accurate)
		_wall_dir = sign(velocity.x) if velocity.x != 0 else 0

	# wall sliding
	_is_wall_sliding = false
	if can_wall_slide and _wall_dir != 0 and not is_grounded() and velocity.y > 0:
		# only slide when pushing toward the wall or neutral (common Mario style: slide while touching and falling)
		if input_dir == _wall_dir or true:
			_is_wall_sliding = true
			velocity.y = min(velocity.y, wall_slide_speed)
			# wall stick -- if player is pressing away from the wall, they can drop immediately.
			if input_dir == -_wall_dir:
				_wall_stick_timer = 0.0
			elif input_dir == _wall_dir:
				# pressing into wall -> maybe stick a bit
				_wall_stick_timer = max(_wall_stick_timer, wall_stick_time)
	# if wall_stick_timer active, reduce horizontal movement toward the wall
	if _wall_stick_timer > 0.0 and _wall_dir != 0:
		# Slightly resist movement away from wall while timer runs (gives more controlled wall jumps)
		velocity.x = move_toward(velocity.x, _wall_dir * 10.0, accel * delta)

func _handle_jump(_input_dir: int) -> void:
	# Jump execution: prefer buffered jump or coyote time
	var jump_pressed := _jump_buffer_timer > 0.0
	if jump_pressed:
		# Wall jump takes precedence
		if _is_wall_sliding and _wall_dir != 0:
			_perform_wall_jump()
			_jump_buffer_timer = 0.0
			return
		# normal grounded jump or coyote or air jumps
		if is_grounded() or _coyote_timer > 0.0 or on_player != null:
			_do_jump()
			_jump_buffer_timer = 0.0
			return
		elif _air_jumps_used < max_air_jumps:
			_do_jump()
			_air_jumps_used += 1
			_jump_buffer_timer = 0.0
			return

	# variable jump height: cut jump when release
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y = velocity.y * jump_cut_multiplier

func _do_jump() -> void:
	# compute upward velocity to reach jump_height
	var jump_v := -sqrt(2.0 * gravity * jump_height)
	velocity.y = jump_v
	on_player = null

func _perform_wall_jump() -> void:
	# push away horizontally and give vertical boost
	velocity.y = -wall_jump_vertical
	velocity.x = -_wall_dir * wall_jump_horizontal
	# optionally flip facing
	facing_right = velocity.x > 0
	on_player = null

func _update_animation_hooks() -> void:
	sprite.frame_coords.x = $Sprite2D.frame_coords.x
	sprite.frame_coords.y = id % sprite.vframes
	
	var anim := $CharacterAnimations
	$Sprite2DCustom.flip_h = facing_right
	if is_grounded():
		if abs(velocity.x) > 10:
			anim.play("run")
		else:
			anim.play("idle")
	else:
		if velocity.y < 0:
			anim.play("jump")
		else:
			if _is_wall_sliding:
				anim.play("wall_slide")
			else:
				anim.play("fall")

func _on_head_platform_area_shape_entered(_area_rid, area, _area_shape_index, _local_shape_index):
	if velocity.y > 0 && area.get_parent() is Ghost:
		on_player = area
		position.y = on_player.global_position.y
		velocity.y = 0

func _on_head_platform_area_shape_exited(_area_rid, _area, _area_shape_index, _local_shape_index):
	on_player = null
