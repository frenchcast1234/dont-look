extends CharacterBody3D
signal game_over

var can_move: bool = false
const SPEED: int = 200
var tween: Tween
var last: Array

func _ready() -> void:
	await get_tree().create_timer(1).timeout
	$Wait.start()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if can_move:
		can_move = false
		var angles: Array = []
		if not $Front.is_colliding(): angles.append(0)
		if not $Left.is_colliding(): angles.append(-90)
		if not $Right.is_colliding(): angles.append(90)
		if angles.is_empty():
			if $Back.is_colliding():
				can_move = true
				return
			angles.append(180)
		rotate_y(deg_to_rad(angles.pick_random()))
		if tween and tween.is_valid():
			tween.kill()
		tween = create_tween()
		tween.tween_property(self, "global_position", global_position + global_transform.basis * Vector3.FORWARD, 0.2)

	move_and_slide()

func _on_wait_timeout() -> void:
	can_move = true

func _process(delta: float) -> void:
	if $Head/Vision.is_colliding():
		print("collide")
		var body = $Head/Vision.get_collider()
		if body.is_in_group("player"):
			print("game over")
			game_over.emit()
