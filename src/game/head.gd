extends Node3D

var is_dead: bool = false
var target: Vector3

func _process(delta: float) -> void:
	if not is_dead: return
	var to_player: Vector3 = target - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.001:
		var target_yaw: float = atan2(-to_player.x, -to_player.z)
		global_rotation.y = rotate_toward(global_rotation.y, target_yaw, delta * 5.0)   
