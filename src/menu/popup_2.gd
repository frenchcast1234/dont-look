extends Panel
signal done(
	monster_speed: float,
	player_speed: int,
	player_jump_force: int,
	initial_map_size: int,
	initial_collectables: int,
	complex_map: bool,
	monster_count: int,
	initial_boosts_count: int,
	boosts_boost: int
)

var step: int = 0
var monster_speed: float
var player_speed: int
var player_jump_force: int
var initial_map_size: int
var initial_collectables: int
var complex_map: bool
var monster_count: int
var initial_boosts_count: int
var boosts_boost: int

func _on_ok_pressed() -> void:
	step += 1
	match step:
		1:
			monster_speed = %HSlider.value
			%HSlider.step = 1
			%HSlider.min_value = 1
			%HSlider.max_value = 500
			%HSlider.value = Stats.player_speed
			%Setting.text = "Choose your speed"
		2:
			player_speed = %HSlider.value
			%HSlider.min_value = 1
			%HSlider.max_value = 400
			%HSlider.value = Stats.player_jump_force
			%Setting.text = "Choose your jump force"
		3:
			player_jump_force = %HSlider.value
			%HSlider.min_value = 3
			%HSlider.max_value = 50
			%HSlider.value = Stats.initial_map_size
			%Setting.text = "Choose an initial map size"
		4:
			initial_map_size = %HSlider.value
			%HSlider.min_value = 1
			%HSlider.max_value = 10
			%HSlider.value = Stats.initial_collectables
			%Setting.text = "Choose initial collectables count"
		5:
			initial_collectables = %HSlider.value
			%HSlider.min_value = 0
			%HSlider.max_value = 1
			%HSlider.value = Stats.complex_map
			%Setting.text = "Are maps complex?"
		6:
			complex_map = %HSlider.value
			%HSlider.min_value = 1
			%HSlider.max_value = 3
			%HSlider.value = Stats.monster_count
			%Setting.text = "Choose the monster count"
		7:
			monster_count = %HSlider.value
			%HSlider.min_value = 0
			%HSlider.max_value = 10
			%HSlider.value = 2
			%Setting.text = "Choose initial boosts count"
		8: 
			initial_boosts_count = %HSlider.value
			%HSlider.value = 2
			%Setting.text = "Choose boosts count you get"
		_: 
			boosts_boost = %HSlider.value
			done.emit(
				monster_speed,
				player_speed,
				player_jump_force,
				initial_map_size,
				initial_collectables,
				complex_map,
				monster_count,
				initial_boosts_count,
				boosts_boost
			)
	# Autoload.get_node("Click").play()
