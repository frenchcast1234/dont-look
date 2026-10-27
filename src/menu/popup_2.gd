extends Panel
signal done(
	monster_speed: float,
	player_speed: int,
	player_jump_force: int,
	initial_map_size: int,
	initial_collectables: int,
	complex_map: bool,
	monster_count: int
)

var step: int = 0
var monster_speed: float
var player_speed: int
var player_jump_force: int
var initial_map_size: int
var initial_collectables: int
var complex_map: bool
var monster_count: int

func _on_ok_pressed() -> void:
	step += 1
	match step:
		1:
			monster_speed = %HSlider.value
			%Setting.text = "Choose your speed"
		2:
			player_speed = %HSlider.value
			%Setting.text = "Choose your jump force"
		3:
			player_jump_force = %HSlider.value
			%Setting.text = "Choose an initial map size"
		4:
			initial_map_size = %HSlider.value
			%Setting.text = "Choose initial collectables count"
		5:
			initial_collectables = %HSlider.value
			%Setting.text = "Are maps complex?"
		6:
			complex_map = %Slider.value
			%Setting.text = "Choose the monster count"
		7:
			done.emit(
				monster_speed,
				player_speed,
				player_jump_force,
				initial_map_size,
				initial_collectables,
				complex_map,
				monster_count
			)
