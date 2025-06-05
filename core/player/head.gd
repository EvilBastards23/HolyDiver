extends Node3D

@onready var camera_3d: Camera3D = $recoil/Camera3D
@onready var camera_3dd: Camera3D = $"../SubViewportContainer/SubViewport/Camera3D"
@onready var sub_viewport: SubViewport = $"../SubViewportContainer/SubViewport"

func _ready() -> void:
	var screen_size = DisplayServer.screen_get_size()
	
	# Set window size
	DisplayServer.window_set_size(screen_size)
	
	# Set SubViewport size
	sub_viewport.size = screen_size

func _process(_delta: float) -> void:
	camera_3dd.global_transform = camera_3d.global_transform
