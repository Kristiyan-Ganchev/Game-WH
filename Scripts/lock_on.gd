extends Node3D

@onready var base = $".."
@onready var ui = $"../../Control"

@export var lock_on_range: float = 20.0
@export var lock_on_lerp: float = 30.0
@export var switch_sensitivity: float = 40.0
@export var switch_cooldwn: float = 0.25



var is_locked_on: = false
var lock_on_target: Node3D
var switch_cooldown: float = 0.0 

func _ready() -> void:
	ui.visible = false
	pass

func _physics_process(delta: float) -> void:
	if switch_cooldown > 0:
		switch_cooldown -= delta
	if Input.is_action_just_pressed("lock_on"):
		toggle_lock()
		print(is_locked_on)
	if is_locked_on and lock_on_target:
		maintain_lock(delta)

func maintain_lock(delta: float) -> void:
	if !is_instance_valid(lock_on_target) or global_position.distance_to(lock_on_target.global_position) > lock_on_range:
		lock_off()
		return
	var target_pos = lock_on_target.global_position
	var current_transform = base.global_transform
	
	var target_transform = current_transform.looking_at(target_pos,Vector3.UP)
	base.global_transform = current_transform.interpolate_with(target_transform,lock_on_lerp * delta)

func toggle_lock() -> void:
	if is_locked_on:
		lock_off()
	else: 
		check_for_targets()
	
func lock_off() -> void:
	if is_locked_on and lock_on_target and lock_on_target.has_method("selected"):
		lock_on_target.selected(false)
	is_locked_on = false
	lock_on_target = null
	ui.visible = false
	
	if base.has_method("sync_look_angles"):
		base.sync_look_angles()

func check_for_targets() -> void:
	var camera = get_viewport().get_camera_3d()
	var best_target = null
	var min_angle = INF

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if camera.is_position_in_frustum(enemy.global_position):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= lock_on_range:
				if not has_line_of_sight(enemy):
					continue
					
				var dir_to_enemy = (enemy.global_position - base.global_position).normalized()
				var cam_forward = -base.global_transform.basis.z
				var angle = cam_forward.angle_to(dir_to_enemy)

				if angle < min_angle:
					min_angle = angle
					best_target = enemy
	if best_target:
		select_new_target(best_target)

func switch_target_by_direction(direction: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera or not lock_on_target: return
	
	var current_screen_pos = camera.unproject_position(lock_on_target.global_position)
	
	var best_candidate = null
	var min_screen_dist = INF

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if enemy == lock_on_target: continue
		
		if camera.is_position_in_frustum(enemy.global_position):
			if global_position.distance_to(enemy.global_position) <= lock_on_range:
				if not has_line_of_sight(enemy): continue
				
				var enemy_screen_pos = camera.unproject_position(enemy.global_position)
				
				if (direction > 0 and enemy_screen_pos.x > current_screen_pos.x) or \
				   (direction < 0 and enemy_screen_pos.x < current_screen_pos.x):
					
					var d = current_screen_pos.distance_to(enemy_screen_pos)
					if d < min_screen_dist:
						min_screen_dist = d
						best_candidate = enemy
						
	if best_candidate:
		select_new_target(best_candidate)
		
func select_new_target(new_target: Node3D) -> void:
	if lock_on_target and lock_on_target.has_method("selected"):
		lock_on_target.selected(false)
		
	lock_on_target = new_target
	is_locked_on = true
	ui.visible = true
	
	if lock_on_target.has_method("selected"):
		lock_on_target.selected(true)
		
func handle_mouse_switch(relative: Vector2) -> void:
	if is_locked_on and switch_cooldown <= 0:
		if abs(relative.x) > switch_sensitivity:
			switch_target_by_direction(sign(relative.x))
			switch_cooldown = switch_cooldwn
		
func has_line_of_sight(target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(base.global_position, target.global_position)
	query.exclude = [get_parent().get_rid()]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result.collider == target
