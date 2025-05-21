extends Node3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var camera_3dd: Camera3D = $"../SubViewportContainer/SubViewport/Camera3D"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	camera_3dd.global_transform = camera_3d.global_transform
