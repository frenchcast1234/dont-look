extends VBoxContainer

func _ready() -> void:
	await get_tree().process_frame
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not Storage.Get("sfx"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Storage.Get("music"))
	if Storage.Get("music"):
		$Music.text = "Music: yes"
	else:
		$Music.text = "Music: no"
		
	if Storage.Get("sfx"):
		$SFX.text = "SFX: yes"
	else:
		$SFX.text = "SFX: no"

func _on_music_pressed() -> void:
	Storage.Set("music", not Storage.Get("music"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Storage.Get("music"))
	if Storage.Get("music"):
		$Music.text = "Music: yes"
	else:
		$Music.text = "Music: no"

func _on_sfx_pressed() -> void:
	Storage.Set("sfx", not Storage.Get("sfx"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not Storage.Get("sfx"))
	if Storage.Get("sfx"):
		$SFX.text = "SFX: yes"
	else:
		$SFX.text = "SFX: no"
