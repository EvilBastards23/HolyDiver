extends CharacterBody3D

@export var speed = 3.0
var nav_agent: NavigationAgent3D
var anim_player: AnimationPlayer  # Use AnimationPlayer3D if that's what your model has

func _ready():
	nav_agent = $NavigationAgent3D
	anim_player = $MeshInstance3D/testEnemyForHolyDiver/AnimationPlayer  
	add_to_group("enemy")

func _physics_process(_delta):
	var core = get_tree().get_root().get_node("core")
	if core:
		var target_position = core.target_position
		nav_agent.target_position = target_position
		
		# Calculate direction on XZ plane only (ignore Y for flat rotation)
		var enemy_position = global_transform.origin
		var look_direction = (core.target_position - enemy_position)
		look_direction.y = 0  # ignore vertical difference

		if look_direction.length() > 0.1:
			# Look at the player smoothly (optional)
			look_at(core.target_position, Vector3.UP)
			# Force upright (optional, if your model tilts)
			rotation.x = 0
			rotation.z = 0


		if not nav_agent.is_navigation_finished():
			var direction = (nav_agent.get_next_path_position() - global_position).normalized()
			velocity = direction * speed
			move_and_slide()

			# 🔁 Play run animation when moving
			if not anim_player.is_playing() or anim_player.current_animation != "Run":
				anim_player.play("run")
		else:
			velocity = Vector3.ZERO
			# ⏹ Stop animation if not moving
			if anim_player.is_playing():
				anim_player.stop()
