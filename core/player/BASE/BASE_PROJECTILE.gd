extends CharacterBody3D
class_name PROJECTILE

@export var projectile_speed: float = 20.0


func _ready() -> void:
	pass

#
func _physics_process(_delta: float) -> void:
	var movement_direction = -transform.basis.z.normalized()

	velocity = movement_direction * projectile_speed
	move_and_slide()
	
