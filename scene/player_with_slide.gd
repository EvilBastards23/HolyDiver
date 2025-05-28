extends CharacterBody3D

const JUMP_VELOCITY = 7.6

# Child node references
@onready var head = $head
@onready var camera_3d = $head/Camera3D

# Sensitivity and movement variables
@export var sensitivity: float = 0.003
@export var bob_freq = 1
var bob_amp = 0.01

# Global variables
var t_bob: float = 0.0
var speed: float = 10.0
var gravity = 12.0
var is_jumping: bool = false
var is_dashing: bool = false
var dash_direction = Vector3.ZERO
@export var dash_distance: float = 15.0
@export var dash_time: float = 0.1
var current_dash_time: float = 0.0

# Slide mechanics
var is_sliding: bool = false
var slide_direction = Vector3.ZERO
@export var slide_speed: float = 12.0
@export var slide_friction: float = 8.0
@export var slide_duration: float = 1.5
@export var slide_fov_change: float = 85.0
var slide_timer: float = 0.0
var slide_velocity: float = 0.0
var original_collision_height: float
var slide_collision_height: float = 0.5

# Camera tilting for slide and movement
var camera_tilt: float = 0.0
@export var slide_tilt_angle: float = 5.0
@export var movement_tilt_angle: float = 2.0
var camera_crouch_offset: float = 0.0
@export var slide_camera_lower: float = 0.5

# Wall sliding and unstuck mechanics
@export var wall_slide_enabled: bool = true
@export var wall_slide_speed: float = 0.8  # How much speed is maintained when sliding along walls
@export var unstuck_force: float = 2.0     # Force applied to push away from walls
@export var wall_detection_distance: float = 0.6  # How far to check for walls
var last_wall_normal: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var was_stuck: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	setup_collision_shape()

# Rotating camera using mouse
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	# Add gravity unless dashing or sliding
	if not is_on_floor() and not is_dashing and not is_sliding:
		is_jumping = false
		velocity.y -= gravity * delta
	
	# Jump (can't jump while sliding)
	if is_on_floor() and not is_jumping and Input.is_action_pressed("jump"):
		if is_sliding:
			end_slide()
		velocity.y = JUMP_VELOCITY
		is_jumping = true
	
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Slide input (crouch while moving forward)
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not is_dashing and velocity.length() > 3.0:
		start_slide(direction if direction != Vector3.ZERO else -transform.basis.z)
	
	# End slide early if crouch is released
	if is_sliding and Input.is_action_just_released("slide"):
		end_slide()
	
	# Dash logic (can't dash while sliding)
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_sliding and direction != Vector3.ZERO:
		is_dashing = true
		current_dash_time = 0.0
		dash_direction = direction
		camera_3d.fov = lerp(camera_3d.fov, 90.0, 0.2)
		if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect"):
			$SubViewportContainer/SubViewport/Camera3D/ColorRect.show()
	
	# Handle dashing
	if is_dashing:
		current_dash_time += delta
		if current_dash_time >= dash_time:
			is_dashing = false
			if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect"):
				$SubViewportContainer/SubViewport/Camera3D/ColorRect.hide()
		else:
			velocity = dash_direction * (dash_distance / dash_time)
			velocity.y = 0
	
	# Handle sliding
	elif is_sliding:
		handle_slide(delta)
	
	# Normal movement (only if not dashing or sliding)
	elif not is_dashing:
		camera_3d.fov = lerp(camera_3d.fov, 75.0, 0.1)
		if direction:
			# Apply wall sliding logic
			var intended_velocity = direction * speed
			intended_velocity = handle_wall_sliding(intended_velocity, delta)
			velocity.x = intended_velocity.x
			velocity.z = intended_velocity.z
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
	
	# Handle camera tilt (now includes movement tilt)
	update_camera_tilt(delta, input_dir)
	
	# Head bobbing (disabled during slide and dash)
	if is_on_floor() and velocity.length() > 0 and not is_dashing and not is_sliding:
		t_bob += delta * velocity.length()
		camera_3d.transform.origin = head_bob(t_bob, velocity.length(), speed)
	else:
		camera_3d.transform.origin = head_bob(t_bob, velocity.length(), speed)
	
	move_and_slide()

func handle_wall_sliding(intended_velocity: Vector3, delta: float) -> Vector3:
	if not wall_slide_enabled:
		return intended_velocity
	
	# Check if we're colliding with walls
	var wall_normal = Vector3.ZERO
	var is_hitting_wall = false
	
	# Use raycast to detect walls in movement direction
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = global_position + intended_velocity.normalized() * wall_detection_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]  # Don't hit ourselves
	query.collision_mask = 1  # Adjust collision mask as needed
	
	var result = space_state.intersect_ray(query)
	
	if result:
		wall_normal = result.normal
		is_hitting_wall = true
		last_wall_normal = wall_normal
	
	# Check for stuck condition (very low movement despite input)
	var current_speed = Vector3(velocity.x, 0, velocity.z).length()
	var intended_speed = intended_velocity.length()
	
	if intended_speed > 1.0 and current_speed < 0.5:
		stuck_timer += delta
		if stuck_timer > 0.1:  # Stuck for more than 0.1 seconds
			was_stuck = true
	else:
		stuck_timer = 0.0
		was_stuck = false
	
	# Apply wall sliding or unstuck logic
	if is_hitting_wall or was_stuck:
		if is_hitting_wall:
			# Slide along the wall
			var slide_velocity = intended_velocity - intended_velocity.project(wall_normal)
			slide_velocity *= wall_slide_speed
			
			# Add small push away from wall to prevent sticking
			var push_away = wall_normal * unstuck_force * delta
			slide_velocity += push_away
			
			return slide_velocity
		elif was_stuck and last_wall_normal != Vector3.ZERO:
			# Try to unstuck by moving away from last known wall
			var unstuck_velocity = intended_velocity
			unstuck_velocity += last_wall_normal * unstuck_force
			return unstuck_velocity
	
	return intended_velocity

func setup_collision_shape():
	# Find and setup collision shape
	var collision_node = get_node_or_null("CollisionShape3D")
	if collision_node and collision_node.shape:
		if collision_node.shape is CapsuleShape3D:
			var capsule = collision_node.shape as CapsuleShape3D
			original_collision_height = capsule.height
		else:
			# If not a capsule, disable collision modification
			original_collision_height = 2.0
			print("Warning: Collision shape is not a CapsuleShape3D. Slide collision adjustment disabled.")
	else:
		# Fallback values
		original_collision_height = 2.0
		print("Warning: No CollisionShape3D found. Using default values.")

func start_slide(direction: Vector3):
	if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect2"):
		$SubViewportContainer/SubViewport/Camera3D/ColorRect2.show()
	is_sliding = true
	slide_direction = direction.normalized()
	slide_timer = 0.0
	slide_velocity = slide_speed
	
	# Lower collision shape (with safety checks)
	var collision_node = get_node_or_null("CollisionShape3D")
	if collision_node and collision_node.shape and collision_node.shape is CapsuleShape3D:
		var collision_shape = collision_node.shape as CapsuleShape3D
		collision_shape.height = slide_collision_height
		collision_node.position.y = -((original_collision_height - slide_collision_height) / 2)
	
	# Camera effects
	camera_3d.fov = lerp(camera_3d.fov, slide_fov_change, 0.3)

func end_slide():
	if has_node("SubViewportContainer/SubViewport/Camera3D/ColorRect2"):
		$SubViewportContainer/SubViewport/Camera3D/ColorRect2.hide()
	if not is_sliding:
		return
		
	is_sliding = false
	slide_timer = 0.0
	
	# Restore collision shape (with safety checks)
	var collision_node = get_node_or_null("CollisionShape3D")
	if collision_node and collision_node.shape and collision_node.shape is CapsuleShape3D:
		var collision_shape = collision_node.shape as CapsuleShape3D
		collision_shape.height = original_collision_height
		collision_node.position.y = 0
	
	# Restore camera FOV
	camera_3d.fov = lerp(camera_3d.fov, 75.0, 0.2)

func handle_slide(delta: float):
	slide_timer += delta
	
	# Apply friction to slide velocity
	slide_velocity = max(slide_velocity - slide_friction * delta, 2.0)
	
	# Set velocity based on slide direction and current slide speed
	velocity.x = slide_direction.x * slide_velocity
	velocity.z = slide_direction.z * slide_velocity
	
	# End slide if timer expires or velocity is too low
	if slide_timer >= slide_duration or slide_velocity <= 2.0:
		end_slide()

func update_camera_tilt(delta: float, input_dir: Vector2):
	var target_tilt = 0.0
	var target_crouch = 0.0
	
	if is_sliding:
		# Tilt camera based on slide direction
		var slide_dot = slide_direction.dot(transform.basis.x)
		target_tilt = slide_dot * deg_to_rad(slide_tilt_angle)
		# Lower camera during slide
		target_crouch = slide_camera_lower
	else:
		# Tilt camera based on left/right movement input
		target_tilt = -input_dir.x * deg_to_rad(movement_tilt_angle)
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * 5.0)
	camera_crouch_offset = lerp(camera_crouch_offset, target_crouch, delta * 8.0)
	
	head.rotation.z = camera_tilt
	head.position.y = -camera_crouch_offset

func head_bob(time, velocity_length, speed):
	# Subtle and non-linear bobbing based on speed
	var speed_ratio = clamp(velocity_length / speed, 0.0, 1.0)
	var current_bob_amp = bob_amp * clamp(sqrt(speed_ratio), 0.3, 1.0)
	
	# Add slight sway for vertical and horizontal bobbing
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * current_bob_amp
	pos.x = cos(time * bob_freq / 2) * current_bob_amp * 0.5
	
	# Smooth damping to reduce jitter at low velocity
	pos *= lerp(0.5, 1.0, speed_ratio)
	
	return pos
