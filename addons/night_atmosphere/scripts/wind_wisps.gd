@tool
extends MultiMeshInstance3D
## Motes of dust and pollen carried on the air.
##
## Each wisp crosses the volume, fades in, fades out and re-enters on the upwind
## face, so the flow is continuous and nothing pops. They are stretched along their
## own velocity, which turns a dot into a streak and makes the wind direction
## readable without any other cue.
##
## Optional integration: if a node in the group "weather" exposes a float property
## named `wind`, it is added to the base speed. Without one, `base_wind` is used.

## The quad and its material, used as the MultiMesh's draw pass. Shared between
## instances is correct here: it is only ever read.
@export var draw_mesh: Mesh:
	set(v):
		draw_mesh = v
		_build()

@export var count := 60:
	set(v):
		count = v
		_build()
@export var area := Vector3(20, 6, 20):
	set(v):
		area = v
		_build()

@export_group("Wind")
## Direction of travel. Normalised; a little Y gives an updraft.
@export var direction := Vector3(1, 0.06, 0.35)
## Meters per second with no weather node present.
@export var base_wind := 0.9
## How much a weather node's `wind` value adds on top.
@export var weather_wind := 2.2
## Sideways drift, so they do not travel in parallel lines.
@export var turbulence := 0.5

@export_group("Look")
@export var length_range := Vector2(0.25, 0.7)
@export var width_range := Vector2(0.012, 0.03)
@export_range(0.0, 1.0, 0.01) var opacity := 0.5
@export var color_a := Color(0.78, 0.84, 0.95)
@export var color_b := Color(0.95, 0.92, 0.80)

@export_group("Editor")
@export var preview_in_editor := true

class Wisp:
	var pos: Vector3
	var vel: Vector3
	var life: float
	var age: float
	var length: float
	var width: float
	var tint: Color
	var phase: float

var _wisps: Array[Wisp] = []
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _weather: Node
var _t := 0.0

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.frequency = 1.0
	_build()

## See the note in fireflies.gd: the MultiMesh is built here so nothing has to be
## duplicated or deserialized.
func _build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = draw_mesh
	mm.instance_count = maxi(count, 0)
	multimesh = mm
	_rng.seed = hash(name) + 7
	_wisps.clear()
	for i in count:
		var w := Wisp.new()
		_respawn(w, true)
		_wisps.append(w)
	_update(0.0)

## `anywhere` seeds the first fill across the whole volume. After that a wisp
## re-enters from the upwind face, or the flow visibly restarts.
func _respawn(w: Wisp, anywhere: bool) -> void:
	var dir := direction.normalized()
	var half := area * 0.5
	if anywhere:
		w.pos = Vector3(_rng.randf_range(-half.x, half.x),
			_rng.randf_range(-half.y, half.y), _rng.randf_range(-half.z, half.z))
	else:
		w.pos = -dir * half.length() * 0.6 + Vector3(
			_rng.randf_range(-half.x, half.x) * 0.8,
			_rng.randf_range(-half.y, half.y),
			_rng.randf_range(-half.z, half.z) * 0.8)
	w.life = _rng.randf_range(4.0, 11.0)
	w.age = _rng.randf() * w.life if anywhere else 0.0
	w.length = _rng.randf_range(length_range.x, length_range.y)
	w.width = _rng.randf_range(width_range.x, width_range.y)
	w.tint = color_a.lerp(color_b, _rng.randf())
	w.phase = _rng.randf() * 1000.0
	w.vel = Vector3.ZERO

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_update(delta)

func _wind_speed() -> float:
	# get_tree() is null until the node is in the tree, and an exported setter can
	# fire during scene load.
	if _weather == null and is_inside_tree():
		_weather = get_tree().get_first_node_in_group("weather")
	if _weather == null:
		return base_wind
	var w = _weather.get("wind")
	if typeof(w) != TYPE_FLOAT and typeof(w) != TYPE_INT:
		return base_wind
	return base_wind + float(w) * weather_wind

func _update(delta: float) -> void:
	if multimesh == null or _wisps.is_empty():
		return
	var n := mini(_wisps.size(), multimesh.instance_count)
	_t += delta
	var dir := direction.normalized()
	var speed := _wind_speed()
	var half := area * 0.5

	for i in n:
		var w: Wisp = _wisps[i]
		w.age += delta
		if w.age >= w.life or absf(w.pos.x) > half.x * 1.6 \
				or absf(w.pos.z) > half.z * 1.6:
			_respawn(w, false)

		var curl := Vector3(
			_noise.get_noise_2d(w.phase, _t * 0.4),
			_noise.get_noise_2d(w.phase + 61.0, _t * 0.3) * 0.5,
			_noise.get_noise_2d(w.phase + 122.0, _t * 0.4)) * turbulence
		w.vel = dir * speed + curl
		w.pos += w.vel * delta

		# Fade over the first and last fifth of life, so nothing appears or
		# disappears on screen.
		var p := clampf(w.age / maxf(w.life, 0.01), 0.0, 1.0)
		var alpha := clampf(minf(p / 0.2, (1.0 - p) / 0.2), 0.0, 1.0) * opacity

		# X runs down the streak, matching the shader's long axis to the velocity.
		var along := w.vel.normalized() if w.vel.length() > 0.001 else dir
		var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var side := along.cross(up).normalized()
		var basis := Basis(along * w.length, side.cross(along).normalized() * w.width,
			side * w.width)
		multimesh.set_instance_transform(i, Transform3D(basis, w.pos))
		multimesh.set_instance_color(i, Color(w.tint.r, w.tint.g, w.tint.b, alpha))
