extends Panel

var infos: Array[Dictionary] = [
	{ "text": "Use ZQSD (WASD) to move trough the maze.", "next": true, "last": false },
	{ "text": "Press 1, 2, 3 or 4 to use your boosts.", "next": true, "last": true },
	{ "text": "Press E to toggle the pause menu.", "next": false, "last": true },
]
var index: int = 0

func _ready() -> void:
	%Info.text = infos[index].text
	$Next.visible = infos[index].next
	$Last.visible = infos[index].last

func _on_next_pressed() -> void:
	index += 1
	%Info.text = infos[index].text
	$Next.visible = infos[index].next
	$Last.visible = infos[index].last

func _on_last_pressed() -> void:
	index -= 1
	%Info.text = infos[index].text
	$Next.visible = infos[index].next
	$Last.visible = infos[index].last
