# CharacterController.gd
extends CharacterBody3D

# Constants
const JUMP_VELOCITY = 7.0
const GRAVITY = 18.0

# Child node references
@onready var head = $head
@onready var camera_3d = $head/recoil/Camera3D
@onready var state_machine = $StateMachine

# Export variables
@export var sensitivity: float = 0.003
@export var bob_freq = 1
@export var speed: float = 10.0
@export var dash_distance: float = 15.0
@export var dash_time: float = 0.1
@export var double_jump_velocity: float = 10.5
@export var jump_hold_boost: float = 2.5
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.2
@export var wall_slide_gravity: float = 5.0
@export var wall_slide_max_speed: float = 3.0
@export var slide_speed: float = 12.0
@export var slide_friction: float = 8.0
@export var slide_duration: float = 1.5
@export var slide_fov_change: float = 85.0

# Movement and physics variables
var bob_amp = 0.01
var t_bob: float = 0.0
var pitch := 0.0

# Jump system
var jump_count: int = 0
var max_jumps: int = 2
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var can_wall_jump: bool = false  # New variable to track wall jump availability

# Wall interaction
var wall_normal: Vector3 = Vector3.ZERO

# Camera effects
var jump_camera_shake: float = 0.0
var land_camera_shake: float = 0.0
@export var jump_shake_intensity: float = 0.02
@export var land_shake_intensity: float = 0.03

# Slow motion
@export var jump_slowmo_factor: float = 0.3
@export var jump_slowmo_duration: float = 0.4
@export var air_time_threshold: float = 0.2
var slowmo_timer: float = 0.0
var air_time: float = 0.0
var camera_lerp_speed: float = 1.0

# Slide mechanics
var slide_direction = Vector3.ZERO
var slide_timer: float = 0.0
var slide_velocity: float = 0.0
var original_collision_height: float
var slide_collision_height: float = 0.5

# Camera tilting
var camera_tilt: float = 0.0
@export var slide_tilt_angle: float = 5.0
@export var movement_tilt_angle: float = 2.0
@export var wall_slide_tilt_angle: float = 8.0
var camera_crouch_offset: float = 0.0
@export var slide_camera_lower: float = 0.5

# Dash mechanics
var dash_direction = Vector3.ZERO
var current_dash_time: float = 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	setup_states()

func setup_states():
	# Create states
	var idle_state = create_idle_state()
	var walking_state = create_walking_state()
	var jumping_state = create_jumping_state()
	var falling_state = create_falling_state()
	var wall_sliding_state = create_wall_sliding_state()
	var dashing_state = create_dashing_state()
	var sliding_state = create_sliding_state()
	
	# Add states to machine
	state_machine.add_state(idle_state)
	state_machine.add_state(walking_state)
	state_machine.add_state(jumping_state)
	state_machine.add_state(falling_state)
	state_machine.add_state(wall_sliding_state)
	state_machine.add_state(dashing_state)
	state_machine.add_state(sliding_state)
	
	# Start with idle state
	state_machine.change_state("Idle")

func create_idle_state() -> STATE:
	var state = STATE.new()
	state.state_name = "Idle"
	
	state.enter_func = func(_owner):
		pass
	
	state.update_func = func(_owner, _delta):
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		
		# Check for state transitions
		if not is_on_floor():
			return "Falling"
		elif input_dir != Vector2.ZERO:
			return "Walking"
		elif Input.is_action_just_pressed("dash") and input_dir != Vector2.ZERO:
			return "Dashing"
		elif Input.is_action_just_pressed("slide") and velocity.length() > 3.0:
			return "Sliding"
		
		# Apply friction
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		return ""
	
	return state

func create_walking_state() -> STATE:
	var state = STATE.new()
	state.state_name = "Walking"
	
	state.update_func = func(_owner, _delta):
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Check for state transitions
		if not is_on_floor():
			return "Falling"
		elif input_dir == Vector2.ZERO:
			return "Idle"
		elif Input.is_action_just_pressed("dash") and direction != Vector3.ZERO:
			dash_direction = direction
			return "Dashing"
		elif Input.is_action_just_pressed("slide") and velocity.length() > 3.0:
			slide_direction = direction if direction != Vector3.ZERO else -transform.basis.z
			return "Sliding"
		
		# Apply movement
		if direction:
			var intended_velocity = direction * speed
			velocity.x = intended_velocity.x
			velocity.z = intended_velocity.z
		
		return ""
	
	return state

func create_jumping_state() -> STATE:
	var state = STATE.new()
	state.state_name = "Jumping"
	
	state.enter_func = func(_owner):
		jump_camera_shake = jump_shake_intensity
		air_time = 0.0
	
	state.update_func = func(_owner, delta):
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Air movement
		if direction:
			var intended_velocity = direction * speed * 0.8  # Reduced air control
			velocity.x = lerp(velocity.x, intended_velocity.x, delta * 3.0)
			velocity.z = lerp(velocity.z, intended_velocity.z, delta * 3.0)
		
		# Check for wall sliding
		if detect_wall_collision() and velocity.y < 0:
			return "WallSliding"
		
		# Transition to falling when moving downward
		if velocity.y <= 0:
			return "Falling"
		
		return ""
	
	return state

func create_falling_state() -> STATE:
	var state = STATE.new()
	state.state_name = "Falling"
	
	state.update_func = func(_owner, delta):
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Air movement
		if direction:
			var intended_velocity = direction * speed * 0.8
			velocity.x = lerp(velocity.x, intended_velocity.x, delta * 3.0)
			velocity.z = lerp(velocity.z, intended_velocity.z, delta * 3.0)
		
		# Check for wall sliding
		if detect_wall_collision():
			return "WallSliding"
		
		# Land on floor
		if is_on_floor():
			land_camera_shake = land_shake_intensity
			jump_count = 0
			coyote_timer = coyote_time
			can_wall_jump = false  # Reset wall jump availability when landing
			
			# Determine next state based on input
			if input_dir != Vector2.ZERO:
				return "Walking"
			else:
				return "Idle"
		
		return ""
	
	return state

func create_wall_sliding_state() -> STATE:
	var state = STATE.new()
	state.state_name = "WallSliding"
	
	state.enter_func = func(_owner):
		can_wall_jump = true  # Enable wall jumping when entering wall slide
	
	state.update_func = func(_owner, delta):
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Limited air control when wall sliding
		if direction:
			var parallel_to_wall = direction - direction.dot(wall_normal) * wall_normal
			velocity.x = lerp(velocity.x, parallel_to_wall.x * speed * 0.5, delta * 3.0)
			velocity.z = lerp(velocity.z, parallel_to_wall.z * speed * 0.5, delta * 3.0)
		
		# Wall sliding physics
		velocity.y = max(velocity.y - wall_slide_gravity * delta, -wall_slide_max_speed)
		
		# Check if still against wall
		if not detect_wall_collision():
			can_wall_jump = false  # Disable wall jump when leaving wall
			return "Falling"
		
		# Landing
		if is_on_floor():
			jump_count = 0
			can_wall_jump = false  # Reset wall jump availability when landing
			if input_dir != Vector2.ZERO:
				return "Walking"
			else:
				return "Idle"
		
		return ""
	
	return state

func create_dashing_state() -> STATE:
	var state = STATE.new()
	state.state_name = "Dashing"
	
	state.enter_func = func(_owner):
		current_dash_time = 0.0
		if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect"):
			$SubViewportContainer/SubViewport/Camera3D/ColorRect.show()
	
	state.exit_func = func(_owner):
		if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect"):
			$SubViewportContainer/SubViewport/Camera3D/ColorRect.hide()
	
	state.update_func = func(_owner, delta):
		current_dash_time += delta
		
		if current_dash_time >= dash_time:
			# Dash finished, determine next state
			if is_on_floor():
				var input_dir = Input.get_vector("left", "right", "forward", "backward")
				if input_dir != Vector2.ZERO:
					return "Walking"
				else:
					return "Idle"
			else:
				return "Falling"
		else:
			# Continue dashing
			velocity = dash_direction * (dash_distance / dash_time)
			velocity.y = 0
		
		return ""
	
	return state

func create_sliding_state() -> STATE:
	var state = STATE.new()
	state.state_name = "Sliding"
	
	state.enter_func = func(_owner):
		if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect2"):
			$SubViewportContainer/SubViewport/Camera3D/ColorRect2.show()
		
		slide_timer = 0.0
		slide_velocity = slide_speed
		
		# Adjust collision shape
		var collision_node = get_node_or_null("CollisionShape3D")
		if collision_node and collision_node.shape and collision_node.shape is CapsuleShape3D:
			var collision_shape = collision_node.shape as CapsuleShape3D
			collision_shape.height = slide_collision_height
			collision_node.position.y = -((original_collision_height - slide_collision_height) / 2)
		
		camera_3d.fov = lerp(camera_3d.fov, slide_fov_change, 0.3)
	
	state.exit_func = func(_owner):
		if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect2"):
			$SubViewportContainer/SubViewport/Camera3D/ColorRect2.hide()
		
		# Restore collision shape
		var collision_node = get_node_or_null("CollisionShape3D")
		if collision_node and collision_node.shape and collision_node.shape is CapsuleShape3D:
			var collision_shape = collision_node.shape as CapsuleShape3D
			collision_shape.height = original_collision_height
			collision_node.position.y = 0
		
		camera_3d.fov = lerp(camera_3d.fov, 75.0, 0.2)
	
	state.update_func = func(_owner, delta):
		slide_timer += delta
		slide_velocity = max(slide_velocity - slide_friction * delta, 2.0)
		
		velocity.x = slide_direction.x * slide_velocity
		velocity.z = slide_direction.z * slide_velocity
		
		# Check for slide end conditions
		if slide_timer >= slide_duration or slide_velocity <= 2.0 or Input.is_action_just_released("slide"):
			var input_dir = Input.get_vector("left", "right", "forward", "backward")
			if input_dir != Vector2.ZERO:
				return "Walking"
			else:
				return "Idle"
		
		# Check if we left the ground
		if not is_on_floor():
			return "Falling"
		
		return ""
	
	return state

func _input(event):
	if event is InputEventMouseMotion:
		# Apply slow motion effect to camera movement
		var modified_sensitivity = sensitivity * camera_lerp_speed
		rotate_y(-event.relative.x * modified_sensitivity)
		var pitch_change = -event.relative.y * modified_sensitivity
		pitch = clamp(pitch + pitch_change, -PI/2, PI/2)
		head.rotation.x = lerp(head.rotation.x, pitch, camera_lerp_speed * 0.1)
	
	# Pass input to state machine
	state_machine.handle_input(event)

func _physics_process(delta):
	# Track floor state for landing detection
	was_on_floor = is_on_floor()
	
	# Update timers
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		air_time += delta
		
		# Start slow motion after threshold during jumps
		if air_time > air_time_threshold and state_machine.is_state("Jumping") and camera_lerp_speed == 1.0:
			camera_lerp_speed = jump_slowmo_factor
			slowmo_timer = 0.0
	
	# Handle jump buffer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		handle_jump_input()
	
	# Update slow motion
	update_slow_motion(delta)
	
	# Apply gravity (except when dashing or sliding)
	if not state_machine.is_state("Dashing") and not state_machine.is_state("Sliding"):
		apply_gravity(delta)
	
	# Update state machine
	state_machine.update(delta)
	
	# Handle camera effects
	update_camera_effects(delta)
	
	# Head bobbing
	update_head_bobbing(delta)
	
	move_and_slide()

func handle_jump_input():
	if jump_buffer_timer > 0 and not state_machine.is_state("Sliding"):
		var can_jump = false
		var new_state = ""
		
		# Ground jump or coyote time
		if (is_on_floor() or coyote_timer > 0) and jump_count == 0:
			can_jump = true
			velocity.y = JUMP_VELOCITY
			jump_count = 1
			coyote_timer = 0
			new_state = "Jumping"
			
			# Exit dash if dashing
			if state_machine.is_state("Dashing"):
				current_dash_time = dash_time
		
		# Wall jump (only available while wall sliding)
		elif can_wall_jump and state_machine.is_state("WallSliding"):
			can_jump = true
			velocity.y = double_jump_velocity
			jump_count = 1  # Reset jump count since this is a wall jump, not a double jump
			can_wall_jump = false  # Use up the wall jump
			new_state = "Jumping"
			jump_camera_shake = jump_shake_intensity * 1.5
			
			# Add some horizontal velocity away from the wall for better wall jumping
			velocity += wall_normal * speed * 0.5
		
		if can_jump:
			jump_buffer_timer = 0
			state_machine.change_state(new_state)

func apply_gravity(delta):
	if not is_on_floor():
		var gravity_to_apply = GRAVITY
		
		# Wall sliding gravity reduction
		if state_machine.is_state("WallSliding"):
			gravity_to_apply = wall_slide_gravity
		else:
			# Variable jump height
			var gravity_multiplier = 1.0
			if velocity.y > 0 and Input.is_action_pressed("jump") and jump_count == 1:
				gravity_multiplier = 0.6
			elif velocity.y < 0:
				gravity_multiplier = 1.4
			
			gravity_to_apply *= gravity_multiplier
		
		velocity.y -= gravity_to_apply * delta

func detect_wall_collision() -> bool:
	if is_on_floor() or state_machine.is_state("Dashing") or state_machine.is_state("Sliding"):
		return false
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		
		if abs(normal.y) < 0.3:  # Wall if normal is mostly horizontal
			var velocity_towards_wall = -velocity.dot(normal)
			
			if velocity_towards_wall > -2.0:
				wall_normal = normal
				return true
	
	return false

func update_slow_motion(delta):
	if camera_lerp_speed < 1.0:
		slowmo_timer += delta
		if slowmo_timer >= jump_slowmo_duration:
			camera_lerp_speed = 1.0
		else:
			var slowmo_progress = slowmo_timer / jump_slowmo_duration
			camera_lerp_speed = lerp(jump_slowmo_factor, 1.0, smoothstep(0.7, 1.0, slowmo_progress))

func update_camera_effects(delta):
	var shake_lerp_speed = camera_lerp_speed * 8.0
	var land_lerp_speed = camera_lerp_speed * 10.0
	
	# Jump shake
	if jump_camera_shake > 0:
		jump_camera_shake = lerp(jump_camera_shake, 0.0, delta * shake_lerp_speed)
		var shake_offset = Vector3(
			randf_range(-jump_camera_shake, jump_camera_shake),
			randf_range(-jump_camera_shake, jump_camera_shake),
			0
		)
		camera_3d.position = lerp(camera_3d.position, shake_offset, camera_lerp_speed)
	# Land shake
	elif land_camera_shake > 0:
		land_camera_shake = lerp(land_camera_shake, 0.0, delta * land_lerp_speed)
		var shake_offset = Vector3(
			randf_range(-land_camera_shake, land_camera_shake),
			randf_range(-land_camera_shake * 0.5, 0),
			0
		)
		camera_3d.position = lerp(camera_3d.position, shake_offset, camera_lerp_speed)
	else:
		camera_3d.position = lerp(camera_3d.position, Vector3.ZERO, camera_lerp_speed)
	
	# Camera tilt
	update_camera_tilt(delta)

func update_camera_tilt(delta):
	var target_tilt = 0.0
	var target_crouch = 0.0
	var tilt_lerp_speed = 5.0 * camera_lerp_speed
	
	if state_machine.is_state("Sliding"):
		var slide_dot = slide_direction.dot(transform.basis.x)
		target_tilt = slide_dot * deg_to_rad(slide_tilt_angle)
		target_crouch = slide_camera_lower
	elif state_machine.is_state("WallSliding"):
		var wall_side = wall_normal.dot(transform.basis.x)
		target_tilt = wall_side * deg_to_rad(wall_slide_tilt_angle)
	else:
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		target_tilt = -input_dir.x * deg_to_rad(movement_tilt_angle)
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * tilt_lerp_speed)
	camera_crouch_offset = lerp(camera_crouch_offset, target_crouch, delta * 8.0 * camera_lerp_speed)
	
	head.rotation.z = camera_tilt
	head.position.y = -camera_crouch_offset

func update_head_bobbing(delta):
	if is_on_floor() and velocity.length() > 0 and not state_machine.is_state("Dashing") and not state_machine.is_state("Sliding"):
		t_bob += delta * velocity.length()
		var bob_offset = head_bob(t_bob, velocity.length(), speed)
		camera_3d.transform.origin = bob_offset
	else:
		camera_3d.transform.origin = head_bob(t_bob, velocity.length(), speed)

func head_bob(time, velocity_length, speed_val):
	var speed_ratio = clamp(velocity_length / speed_val, 0.0, 1.0)
	var current_bob_amp = bob_amp * clamp(sqrt(speed_ratio), 0.3, 1.0)
	
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * current_bob_amp
	pos.x = cos(time * bob_freq / 2) * current_bob_amp * 0.5
	
	pos *= lerp(0.5, 1.0, speed_ratio)
	
	return pos
