extends Node3D

@onready var target = $CharacterBody3D  # This is your player
var target_position = Vector3.ZERO

func _process(_delta):
	target_position =target.global_transform.origin
