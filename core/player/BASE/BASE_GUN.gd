extends Node3D
class_name GUN


@export var projectile_scene: PackedScene
@export var recoil: float = 0.0
@export var fire_rate: float = 0.1
@export var muzzle_flash: GPUParticles3D
@export var gun_barrel: Node3D
@export var player: CharacterBody3D

var can_shoot: bool = true
var fire_timer: float = 0.0

func _process(delta: float) -> void:
	# Update fire timer
	if not can_shoot:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_shoot = true
	
	# Check for shooting input
	if Input.is_action_pressed("fire") and can_shoot:
		shoot_with_gun()

func shoot_with_gun() -> void:
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	# Trigger muzzle flash
	muzzle_flash.emitting = true
	
	# Set projectile position to gun barrel
	projectile.global_position = gun_barrel.global_position
	

	var recoil_node = get_parent()  # This should be the recoil node
	var combined_y_rotation = player.global_rotation.y
	var combined_x_rotation = player.head.rotation.x + recoil_node.rotation.x
	projectile.global_rotation.y = combined_y_rotation
	projectile.global_rotation.x = combined_x_rotation
	
	# Apply recoil AFTER setting projectile direction
	get_parent().recoilFire()
	
	# Set cooldown for next shot
	can_shoot = false
	fire_timer = fire_rate
