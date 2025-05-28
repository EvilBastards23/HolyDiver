extends CharacterBody3D


const JUMP_VELOCITY = 7.6
# Child node reference
@onready var head = $head
@onready var camera_3d = $head/Camera3D

# Sensitivity and movement variables
@export var  sensitivity:float = 0.003
@export var bob_freq = 1
var bob_amp = 0.01


# Global variables that used in code
var t_bob:float = 0.0
var speed :float= 10.0
var gravity = 12.0
var is_jumping:bool = false

var is_dashing:bool = false
var dash_direction = Vector3.ZERO
@export var dash_distance:float = 15.0
@export var dash_time:float = 0.1
var current_dash_time:float = 0.0



# Remove cursor
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
# Rotating camera using mouse
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)


func _physics_process(delta):
	# Add gravity unless dashing
	if not is_on_floor() and not is_dashing:
		is_jumping = false
		velocity.y -= gravity * delta

	# Jump
	if is_on_floor() and not is_jumping and Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Dash logic
	if Input.is_action_just_pressed("dash") and not is_dashing and direction != Vector3.ZERO:
		is_dashing = true
		current_dash_time = 0.0
		dash_direction = direction
		camera_3d.fov = lerp(camera_3d.fov, 90.0, 0.2)
		$SubViewportContainer/SubViewport/Camera3D/ColorRect.show()

	if is_dashing:
		current_dash_time += delta
		
		if current_dash_time >= dash_time:
			is_dashing = false
			$SubViewportContainer/SubViewport/Camera3D/ColorRect.hide()
		else:
			velocity = dash_direction * (dash_distance / dash_time)
			velocity.y = 0  # Lock vertical motion during dash

	# Only move normally if not dashing
	if not is_dashing:
		camera_3d.fov = lerp(camera_3d.fov, 75.0, 0.1)
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

	# Head bobbing
	if is_on_floor() and velocity.length() > 0 and not is_dashing:
		t_bob += delta * velocity.length()
		camera_3d.transform.origin = head_bob(t_bob, velocity.length(), speed)
	else:
		camera_3d.transform.origin = head_bob(t_bob, velocity.length(), speed)

	move_and_slide()


func head_bob(time, velocity_length, speed):
	# Subtle and non-linear bobbing based on speed
	var speed_ratio = clamp(velocity_length / speed, 0.0, 1.0)
	var current_bob_amp = bob_amp * clamp(sqrt(speed_ratio), 0.3, 1.0)
	
	# Add slight sway for vertical and horizontal bobbing
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * current_bob_amp
	pos.x = cos(time * bob_freq / 2) * current_bob_amp * 0.5 # reduce horizontal sway
	
	# Smooth damping to reduce jitter at low velocity
	pos *= lerp(0.5, 1.0, speed_ratio)
	
	return pos


	
	
	
	
