@tool
extends OmniLight3D
## A candle, lantern or fire, as light only.
##
## Flicker is layered value noise rather than a random value per frame. Per-frame
## randomness has no continuity, so it strobes instead of guttering.
##
## Three things move together, because in life they are one event: the flame leans,
## so it gets brighter, whiter and closer to one wall at the same moment.
##   energy    how bright
##   color    warmer when low, whiter on a flare
##   position  a centimeter or two, which is what makes cast shadows crawl
##
## The position drift does more than it looks like it should. A still light with a
## varying brightness still reads as electrical.

@export_group("Flicker")
@export var base_energy := 1.6:
	set(v):
		base_energy = v
		_refresh_static()
## Swing as a fraction of base. 0.25 is a steady candle in still air, 0.5 guttering,
## above that reads as wind.
@export_range(0.0, 1.0, 0.01) var flicker_amount := 0.28
## Wanders per second. Candles are slower than most people expect.
@export_range(0.1, 12.0, 0.1) var flicker_speed := 2.4
## Fast tremor riding on the slow wander.
@export_range(0.0, 1.0, 0.01) var tremor := 0.35
@export_range(1.0, 20.0, 0.5) var tremor_speed := 9.0

@export_group("Gusts")
## Every so often it nearly goes out. 0 disables.
@export_range(0.0, 1.0, 0.01) var gust_depth := 0.45
## Average seconds between gusts, randomized around this value.
@export var gust_interval := 6.0
@export var gust_length := 0.7

@export_group("Color")
@export var warm_color := Color(1.0, 0.72, 0.36):
	set(v):
		warm_color = v
		_refresh_static()
## Shifted toward on a flare. Slightly whiter, never blue.
@export var flare_color := Color(1.0, 0.87, 0.62)

@export_group("Movement")
## Meters of drift. 0.02 is plenty; 0.1 looks like a firefly.
@export_range(0.0, 0.2, 0.005) var drift := 0.02

@export_group("Editor")
## Animate in the editor as well. Useful when dressing a room, distracting otherwise.
@export var preview_in_editor := false

var _noise := FastNoiseLite.new()
var _t := 0.0
var _origin := Vector3.ZERO
var _gust_at := 0.0
var _gust_until := -1.0
var _seed_offset := 0.0

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.frequency = 1.0
	# Offsetting where each light samples one shared noise field is cheaper than a
	# generator each, and stops a shelf of candles pulsing as one object.
	_seed_offset = float(get_instance_id() % 9973) * 0.37
	_origin = position
	_gust_at = _next_gust()
	_refresh_static()

func _refresh_static() -> void:
	light_energy = base_energy
	light_color = warm_color

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_t += delta

	var slow := _noise.get_noise_2d(_seed_offset, _t * flicker_speed)
	var fast := _noise.get_noise_2d(_seed_offset + 100.0, _t * tremor_speed)
	var swing := (slow + fast * tremor) * flicker_amount

	# A gust is a smooth dip and recovery. A step reads as a dropped frame.
	var gust := 0.0
	if _t >= _gust_at and _gust_until < 0.0:
		_gust_until = _t + gust_length
	if _gust_until >= 0.0:
		if _t >= _gust_until:
			_gust_until = -1.0
			_gust_at = _t + _next_gust()
		else:
			var p := 1.0 - (_gust_until - _t) / maxf(gust_length, 0.01)
			gust = sin(p * PI) * gust_depth

	light_energy = base_energy * clampf(1.0 + swing - gust, 0.02, 2.0)
	light_color = warm_color.lerp(flare_color, clampf(swing * 1.6, 0.0, 1.0))

	if drift > 0.0:
		position = _origin + Vector3(
			_noise.get_noise_2d(_seed_offset + 300.0, _t * flicker_speed) * drift,
			_noise.get_noise_2d(_seed_offset + 600.0, _t * flicker_speed) * drift * 0.5,
			_noise.get_noise_2d(_seed_offset + 900.0, _t * flicker_speed) * drift)

func _next_gust() -> float:
	return gust_interval * randf_range(0.55, 1.6)
