extends CharacterBody3D


const JUMP_VELOCITY = 5.6
# Child node reference
@onready var head = $head
@onready var camera_3d = $head/Camera3D

# Sensitivity and movement variables
@export var  sensitivity:float = 0.003
@export var bob_freq = 1
var bob_amp = 0.01


# Constant for speeds
const walk_speed = 8.0
const sprint_speed = 16.0

# Global variables that used in code
var t_bob:float = 0.0
var speed :float= 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_jumping:bool = false

# Remove cursor
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pass
	
# Rotating camera using mouse
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		is_jumping = false
		velocity.y -= gravity * delta
		
	# Handle sprinting
	if is_on_floor():
		if Input.is_action_pressed("sprint"):
			speed = sprint_speed
		else:
			speed = walk_speed
	
	# Handle jumping
	if is_on_floor() and not is_jumping and Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Calculating speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Head bobbing effect while moving
	if is_on_floor() and velocity.length() > 0:
		t_bob += delta * velocity.length()
		camera_3d.transform.origin = head_bob(t_bob,velocity.length(),speed)
	else:
		# Reset head bob when not moving or in air
		camera_3d.transform.origin = head_bob(t_bob,velocity.length(),speed)
	
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

	
