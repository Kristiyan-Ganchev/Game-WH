extends CharacterBody3D


@export_group("Speeds")
@export var look_speed : float = 0.002
@export var speed : float = 15.0
@export var mov_accel: float = 3.0
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 10.0

@export_group("head bob")
@export var bob_freq = 1.0
@export var bob_amp = 0.08
@export var base_height = 1.0
var t_bob = 0.0
var target_y = 0.0

@onready var head = $Head
@onready var arms: Node3D = $Head/Arms
@onready var edge_checker = $EdgeChecker
@onready var wall_checker = $WallChecker
@onready var timer: Timer = $Timer
@onready var interactable_cast: ShapeCast3D = $Head/RayCast3D
@onready var grab_point: Marker3D = $Head/Marker3D
@onready var hook: StaticBody3D = $Head/Marker3D/Hook

var joint: Generic6DOFJoint3D

var pos: Vector3
var target_pos: Vector3
var look_rotation : Vector2
var mouse_captured: bool = false
var is_grabbing = false
var grabbed_object: Node3D

func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

func _unhandled_input(event: InputEvent) -> void:
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
		if is_grabbing:
			print("throw")
		arms.play()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		if $LockOn.is_locked_on:
			$LockOn.handle_mouse_switch(event.relative)
		else:
			rotate_look(event.relative)

func _physics_process(delta: float) -> void:
	if timer.time_left > 0:
		position = pos.lerp(target_pos,1-timer.time_left)
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta
			
		if Input.is_action_just_pressed("interact") and !is_grabbing:
			handle_grab()
		elif Input.is_action_just_pressed("interact") and is_grabbing:
			handle_let_go()
		handle_jump()
		handle_edge_climb(delta)
		handle_movement(delta)
		handle_head_bob(delta)
		move_and_slide()

func handle_grab():
	if interactable_cast.is_colliding():
		joint = Generic6DOFJoint3D.new()
		joint.exclude_nodes_from_collision = false
		is_grabbing = true
		grab_point.add_child(joint)
		joint.node_a = hook.get_path()
		joint.node_b = interactable_cast.get_collider(0).get_path()
		grabbed_object = interactable_cast.get_collider(0)
		
		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_STIFFNESS, 200.0)
		joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_SPRING_DAMPING, 15.0)
		
		joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	
func handle_let_go():
	is_grabbing = false
	if joint != null:
		joint.queue_free()
		joint = null
		grabbed_object = null
	
func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func handle_edge_climb(delta:float):
	if Input.is_action_just_pressed("jump") and !is_on_floor() and (!edge_checker.has_overlapping_bodies() and wall_checker.has_overlapping_bodies()):
		timer.start()
		pos = position
		target_pos = edge_checker.global_position

func handle_head_bob(delta:float) -> void:
	if is_on_floor() and velocity.length() > 0.1:
		t_bob += delta * velocity.length() * bob_freq
		target_y = base_height + (sin(t_bob) * bob_amp)
	else:
		target_y = base_height
		
	head.transform.origin.y = lerp(head.transform.origin.y, target_y, delta * 10.0)

func handle_movement(delta:float):
	var input_dir := Input.get_vector("m_left", "m_right", "m_forward", "m_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = lerp(velocity.x,direction.x * speed, mov_accel*delta)
		velocity.z = lerp(velocity.z,direction.z * speed, mov_accel*delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func sync_look_angles():
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
