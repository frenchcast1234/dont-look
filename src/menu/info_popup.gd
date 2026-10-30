extends Panel

func _on_next_pressed() -> void:
	%Info.text = "Press 1, 2, 3 or 4 to use your boosts."
	$Next.visible = false
	$Last.visible = true

func _on_last_pressed() -> void:
	%Info.text = "Use ZQSD (WASD) to move trough the maze."
	$Last.visible = false
	$Next.visible = true
