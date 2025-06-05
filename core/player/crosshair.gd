extends Control
class_name AutoCrosshair

@export var crosshair_color: Color = Color.WHITE
@export var crosshair_size: float = 20.0
@export var crosshair_thickness: float = 2.0
@export var gun_barrel: Node3D  # Drag your gun barrel here
@export var camera: Camera3D  # Drag your camera here
@export var projection_distance: float = 100.0  # How far to project the aim point

var crosshair_position: Vector2

func _ready():
	# Set up the crosshair to cover full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun_barrel = $"../head/recoil/hand_with_deagleaaa".gun_barrel

func _draw():
	# Draw horizontal line
	draw_line(
		Vector2(crosshair_position.x - crosshair_size/2, crosshair_position.y),
		Vector2(crosshair_position.x + crosshair_size/2, crosshair_position.y),
		crosshair_color,
		crosshair_thickness
	)
	
	# Draw vertical line
	draw_line(
		Vector2(crosshair_position.x, crosshair_position.y - crosshair_size/2),
		Vector2(crosshair_position.x, crosshair_position.y + crosshair_size/2),
		crosshair_color,
		crosshair_thickness
	)

func _process(_delta):
	if gun_barrel and camera:
		# Calculate where the gun barrel is pointing
		var barrel_forward_direction = -gun_barrel.global_transform.basis.z
		var aim_point = gun_barrel.global_position + barrel_forward_direction * projection_distance
		
		# Project the 3D aim point to 2D screen coordinates
		crosshair_position = camera.unproject_position(aim_point)
		
		# Keep crosshair on screen
		var viewport_size = get_viewport().size
		crosshair_position = crosshair_position.clamp(Vector2.ZERO, viewport_size)
	else:
		# Fallback to center if references are missing
		crosshair_position = get_viewport().size / 2
	
	# Redraw the crosshair
	queue_redraw()

# Optional: Handle screen resize
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
