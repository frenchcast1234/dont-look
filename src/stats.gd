extends Node

var monster_speed: float = 0.2
var player_speed: int = 280
var player_jump_force: int = 280
var initial_map_size: int = 8
var initial_collectables: int = 3
var complex_map: bool = true
var monster_count: int = 1
var is_custom: bool = false
var boosts: Dictionary = {
	"boot": { "count": 2 },
	"map": { "count": 2 },
	"compass": { "count": 2 },
	"stone": { "count": 2 }
}
