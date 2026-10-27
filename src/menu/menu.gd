extends Control

func _ready() -> void:
	$Popup.visible = false
	$Popup2.visible = false

func _on_play_button_pressed() -> void:
	$Popup.visible = true

func _on_easy_pressed() -> void:
	Stats.boss_speed = 0.25
	print(Stats.boss_speed)
	get_tree().change_scene_to_file("res://src/game/game.tscn")
func _on_normal_pressed() -> void:
	Stats.boss_speed = 0.2
	get_tree().change_scene_to_file("res://src/game/game.tscn")
func _on_difficult_pressed() -> void:
	Stats.boss_speed = 0.15
	get_tree().change_scene_to_file("res://src/game/game.tscn")
func _on_custom_pressed() -> void:
	$Popup2.visible = true
	$Popup.visible = false

func _process(delta: float) -> void:
	if not $Popup2.visible: return
	$Popup2/VBoxContainer/Label2.text = str($Popup2/VBoxContainer/HSlider.value)

func _on_popup_2_done(
	monster_speed: float, 
	player_speed: int, 
	player_jump_force: int, 
	initial_map_size: int, 
	initial_collectables: int, 
	complex_map: bool, 
	monster_count: int
) -> void:
	pass # Replace with function body.
