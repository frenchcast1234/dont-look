extends Panel

var speed = Stats.player_speed
var stone_active: bool = false
@export var stone: PackedScene
var last_stone_frame: int = 0

func _process(delta: float) -> void:
	if stone_active: last_stone_frame += 1
	if stone_active and last_stone_frame >= Engine.get_frames_per_second() / 4:
		last_stone_frame = 0
		var obj = stone.instantiate()
		obj.position = get_tree().current_scene.get_node("Player").position
		get_tree().current_scene.get_node("Stones").add_child(obj)
	
	if Input.is_action_just_pressed("inventory_1"):
		if Stats.boosts["boot"]["count"] <= 0: return
		Stats.player_speed *= 1.2
		Stats.boosts["boot"]["count"] -= 1
		$SpeedTimer.start($SpeedTimer.wait_time)
	elif Input.is_action_just_pressed("inventory_2"):
		if Stats.boosts["map"]["count"] <= 0: return
		for obj in get_tree().current_scene.get_node("Objects").get_children():
			obj.get_node("CSGSphere3D").material.no_depth_test = true
		Stats.boosts["map"]["count"] -= 1
		$MapTimer.start($MapTimer.wait_time)
	elif Input.is_action_just_pressed("inventory_3"):
		if Stats.boosts["compass"]["count"] <= 0: return
		for obj in get_tree().current_scene.get_node("Monsters").get_children():
			obj.get_node("Compass").activate(1)
		Stats.boosts["compass"]["count"] -= 1
		$CompassTimer.start($CompassTimer.wait_time)
	elif Input.is_action_just_pressed("inventory_4"):
		if Stats.boosts["stone"]["count"] <= 0: return
		Stats.boosts["stone"]["count"] -= 1
		stone_active = true
		$StoneTimer.start($StoneTimer.wait_time)
	$HBoxContainer/Boot/Count.text = str(Stats.boosts["boot"]["count"])
	$HBoxContainer/Map/Count.text = str(Stats.boosts["map"]["count"])
	$HBoxContainer/Compass/Count.text = str(Stats.boosts["compass"]["count"])
	$HBoxContainer/Stone/Count.text = str(Stats.boosts["stone"]["count"])

func _on_speed_timer_timeout() -> void:
	Stats.player_speed = speed

func _on_map_timer_timeout() -> void:
	for obj in get_tree().current_scene.get_node("Objects").get_children():
		obj.get_node("CSGSphere3D").material.no_depth_test = false

func _on_compass_timer_timeout() -> void:
	for obj in get_tree().current_scene.get_node("Monsters").get_children():
		obj.get_node("Compass").desactivate(1)

func _on_stone_timer_timeout() -> void:
	stone_active = false
