extends Node

func Set(key: String, value: Variant):
	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	if not file:
		var tmpfile = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
		tmpfile.store_string("{}")
		file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	var content = file.get_as_text()
	var json: Dictionary = JSON.parse_string(content)
	json[key] = value
	file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	file.store_string(JSON.stringify(json))

func Get(key: String) -> Variant:
	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	if not file:
		return null
	var content = file.get_as_text()
	var json = JSON.parse_string(content)
	print(json)
	if json.has(key):
		return json[key]
	else:
		return null
