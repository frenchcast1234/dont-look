extends Control

func _on_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/menu/menu.tscn")
