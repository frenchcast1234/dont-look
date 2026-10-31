extends Control

func _on_button_pressed() -> void:
	get_tree().paused = false
	# Autoload.get_node("Click").play()
	get_tree().change_scene_to_file("res://src/menu/menu.tscn")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		visible = not visible
		if visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_tree().paused = not get_tree().paused
