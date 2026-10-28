extends Node3D

var grid_size: int = Stats.initial_map_size
@export var wall_scene: PackedScene
@export var object_scene: PackedScene
@export var monster_scene: PackedScene
var collected: int = 0
var to_collect: int = Stats.initial_collectables
var rounds: int = 1
var best_score: int

func generate_grid(size: int, is_complex: bool, objects: int, mcount: int) -> Array:
	var grid := []
	var nb: int = 0
	
	var arr: Array = []
	for x in range(size * 2 + 1):
		arr.append(-1)
	grid.append(arr)
	for i in range(size):
		var add := []
		for j in range(size):
			add.append(-1)
			add.append(nb)
			nb += 1
		add.append(-1)
		grid.append(add)
		
		var add2 := []
		for j in range(size):
			add2.append(-1)
			add2.append(-1)
		add2.append(-1)
		grid.append(add2)
		
	var types: int = size * size -1
	while types > 0:
		var x: int = (randi() % (size * 2 - 1)) + 1
		var y: int = (randi() % (size * 2 - 1)) + 1
		if grid[x][y] != -1 or (x + y) % 2 == 0:
			continue
		if grid[x-1][y] != grid[x+1][y] and\
		grid[x-1][y] != -1 and\
		grid[x+1][y] != -1:
			grid[x][y] = grid[x-1][y]
			nb = grid[x+1][y]
		elif grid[x][y-1] != grid[x][y+1] and\
		grid[x][y-1] != -1 and\
		grid[x][y+1] != -1:
			grid[x][y] = grid[x][y-1]
			nb = grid[x][y+1]
		else:
			continue
		for row in grid:
			for k in row.size():
				if row[k] == nb:
					row[k] = grid[x][y]
		types -= 1
	
	if is_complex:
		var complexed: int = 0
		while complexed < size / 2:
			var x: int = (randi() % (size * 2 - 1)) + 1
			var y: int = (randi() % (size * 2 - 1)) + 1
			if grid[x][y] != -1: continue
			if (grid[x-1][y] == -1 and grid[x+1][y] == -1 and grid[x][y-1] != -1 and grid[x][y+1] != -1) or\
			(grid[x][y-1] == -1 and grid[x][y+1] == -1 and grid[x-1][y] != -1 and grid[x+1][y] != -1):
				grid[x][y] = 0
				complexed += 1
	
	var placed: int = 0
	while placed < objects:
		var x: int = (randi() % (size * 2 - 1)) + 1
		var y: int = (randi() % (size * 2 - 1)) + 1
		if grid[x][y] < 0:
			continue
		grid[x][y] = -2
		placed += 1
	
	placed = 0
	while placed < mcount:
		var x: int = (randi() % (size - 1)) + 1
		var y: int = (randi() % (size - 1)) + 1
		if grid[x][y] < 0:
			continue
		grid[x][y] = -3
		placed += 1
		
	while true:
		var x: int = (randi() % (size - 1)) + 1 + size
		var y: int = (randi() % (size - 1)) + 1 + size
		if grid[x][y] < 0:
			continue
		grid[x][y] = -4
		break
	
	return grid

func _ready() -> void:
	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	var content = file.get_as_text()
	best_score = int(content)
	$CanvasLayer/Collected.text = "%d/%d" % [collected, to_collect]
	create()

func create() -> void:
	for child in $Walls.get_children():
		child.queue_free()
	var grid := generate_grid(grid_size, Stats.complex_map, to_collect, Stats.monster_count)
	$Ground/CSGBox3D.size = Vector3(
		grid_size * 2 + 1,
		1,
		grid_size * 2 + 1
	)
	$Ground/CollisionShape3D.shape.size = Vector3(
		grid_size * 2 + 1,
		1,
		grid_size * 2 + 1
	)
	for i in range(grid.size()):
		for j in range(grid[0].size()):
			if grid[i][j] == -1:
				var wall: StaticBody3D = wall_scene.instantiate()
				wall.position = Vector3(
					i - grid_size,
					1.5,
					j - grid_size
				)
				$Walls.add_child(wall)
			elif grid[i][j] == -2:
				var obj: StaticBody3D = object_scene.instantiate()
				obj.position = Vector3(
					i - grid_size,
					1,
					j - grid_size
				)
				$Objects.add_child(obj)
			elif grid[i][j] == -3:
				var obj = monster_scene.instantiate()
				obj.position = Vector3(
					i - grid_size,
					4,
					j - grid_size
				)
				obj.game_over.connect(func():
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					$Player/Head.is_dead = true
					$Player/Head.target = obj.global_position
					$CanvasLayer/GameOver.visible = true
					$CanvasLayer/GameOver/VBoxContainer/Rounds.text = "Rounds: %d" % rounds
					Autoload.get_node("Death").play()
					get_tree().paused = true
				)
				$Monsters.add_child(obj)
			elif grid[i][j] == -4:
				$Player.position = Vector3(
					i - grid_size,
					2,
					j - grid_size
				)
				$Player.velocity = Vector3.ZERO

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("obj"):
		body.queue_free()
		collected += 1
		Autoload.get_node("Object").play()
		$CanvasLayer/Collected.text = "%d/%d" % [collected, to_collect]
		if collected >= to_collect:
			if rounds > best_score and not Stats.is_custom:
				var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
				file.store_string(str(rounds))
			grid_size += 5
			rounds += 1
			to_collect += 1
			collected = 0
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			$CanvasLayer/Collected.text = "%d/%d" % [collected, to_collect]
			create()
