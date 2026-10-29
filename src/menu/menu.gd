extends Control

func _ready() -> void:
	if not FileAccess.file_exists("user://save_game.dat"):
		var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
		file.store_string("0")
	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	var content = file.get_as_text()
	$Best.text = "Best score: %d" % int(content)
	$Popup.visible = false
	$Popup2.visible = false

func _on_play_button_pressed() -> void:
	# Autoload.get_node("Click").play()
	$Popup.visible = true

func _on_easy_pressed() -> void:
	# Autoload.get_node("Click").play()
	get_tree().change_scene_to_file("res://src/game/game.tscn")
func _on_normal_pressed() -> void:
	# Autoload.get_node("Click").play()
	get_tree().change_scene_to_file("res://src/game/game.tscn")
func _on_difficult_pressed() -> void:
	# Autoload.get_node("Click").play()
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
	monster_count: int,
	initial_boosts_count: int,
	boosts_boost: int
) -> void:
	Stats.monster_speed = monster_speed
	Stats.player_speed = player_speed
	Stats.player_jump_force = player_jump_force
	Stats.initial_map_size = initial_map_size
	Stats.initial_collectables = initial_collectables
	Stats.complex_map = complex_map
	Stats.monster_count = monster_count
	Stats.is_custom = true
	for x in Stats.boosts.keys():
		Stats.boosts[x]["count"] = initial_boosts_count
	Stats.boosts_boost = boosts_boost
	get_tree().change_scene_to_file("res://src/game/game.tscn")
