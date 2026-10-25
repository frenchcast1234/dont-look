extends Node3D

@export var grid_size: int = 30
@export var wall_scene: PackedScene
@export var object_scene: PackedScene
var collected: int = 0
var to_collect: int = 5

func generate_grid(size: int, objects: int) -> Array:
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
	
	var placed: int = 0
	while placed < objects:
		var x: int = (randi() % (size * 2 - 1)) + 1
		var y: int = (randi() % (size * 2 - 1)) + 1
		if grid[x][y] < 0:
			continue
		grid[x][y] = -2
		placed += 1
		
	while true:
		var x: int = (randi() % (size - 1)) + 1
		var y: int = (randi() % (size - 1)) + 1
		if grid[x][y] < 0:
			continue
		grid[x][y] = -3
		break
		
	while true:
		var x: int = (randi() % (size - 1)) + 1 + size
		var y: int = (randi() % (size - 1)) + 1 + size
		if grid[x][y] < 0:
			continue
		grid[x][y] = -4
		break
	
	return grid

func _ready() -> void:
	$Monster.game_over.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		$CanvasLayer/GameOver.visible = true
		get_tree().paused = true
	)
	var grid := generate_grid(grid_size, to_collect)
	for i in range(grid_size * 2 + 1):
		for j in range(grid_size * 2 + 1):
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
				$Monster.position = Vector3(
					i - grid_size,
					4,
					j - grid_size
				)
			elif grid[i][j] == -4:
				$Player.position = Vector3(
					i - grid_size,
					4,
					j - grid_size
				)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("obj"):
		body.queue_free()
		collected += 1
		$CanvasLayer/Collected.text = "%d/%d" % [collected, to_collect]
