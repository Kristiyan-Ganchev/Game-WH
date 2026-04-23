extends CharacterBody3D


var knockback_velocity = Vector3.ZERO

func _physics_process(delta):
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = lerp(knockback_velocity, Vector3.ZERO, delta * 10.0)
	
	move_and_slide()

func die(force: Vector3):
	knockback_velocity = force
