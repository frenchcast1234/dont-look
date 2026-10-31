extends CharacterBody3D

var mouse_sensitivity: float = 0.005
var gravity: float = 9.8

var head: Node3D
var pitch: float = 0.0

func _ready() -> void:
	head = $Head
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$MeshInstance3D.visible = false
	if OS.has_feature("web"):
		mouse_sensitivity = 0.003

func _unhandled_input(event) -> void:
	if event is InputEventMouseMotion:
		# rotation horizontale du corps
		rotate_y(-event.screen_relative.x * mouse_sensitivity)
		# rotation verticale de la tête
		pitch = clamp(pitch - event.screen_relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = pitch
	elif event is InputEventKey and event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO

	var forward = -transform.basis.z
	var right = transform.basis.x

	if Input.is_action_pressed("forward"):
		direction += forward
	if Input.is_action_pressed("back"):
		direction -= forward
	if Input.is_action_pressed("left"):
		direction -= right
	if Input.is_action_pressed("right"):
		direction += right

	direction = direction.normalized()

	# mouvement horizontal
	velocity.x = direction.x * Stats.player_speed * Stats.speed_mult * delta
	velocity.z = direction.z * Stats.player_speed * Stats.speed_mult * delta

	# gravité et saut
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		# Autoload.get_node("Jump").play()
		velocity.y = Stats.player_jump_force * delta

	move_and_slide()
