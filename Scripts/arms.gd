extends Node3D

@onready var slap_area: Area3D = $rig/Skeleton3D/BoneAttachment3D/Area3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	slap_area.body_entered.connect(_on_slap_body_entered)

func play() -> void:
	anim_player.play("rig|Slap")

func _on_slap_body_entered(body: Node3D) -> void:
	if body.has_method("die"):
		body.die((body.global_position - global_position).normalized() * 2)
		print("Slapped: ", body.name)
	elif body is RigidBody3D:
		var direction = (body.global_position - global_position).normalized()
		body.apply_central_impulse(direction * 5.0)
