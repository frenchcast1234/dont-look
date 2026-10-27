@tool
extends MultiMeshInstance3D
## Fireflies drifting inside a box. Drop the scene in, size the box, done.
##
## Driven from GDScript over a MultiMesh rather than GPUParticles3D. The blink is
## the effect, and a blink pattern is easier to tune as a few lines of code than as
## a particle curve. Sixty transforms per frame is not a meaningful cost, and it
## previews in the editor for free.

## The quad and its material, used as the MultiMesh's draw pass. Shared between
## instances is correct here: it is only ever read.
@export var draw_mesh: Mesh:
	set(v):
		draw_mesh = v
		_build()

@export var count := 45:
	set(v):
		count = v
		_build()
## The volume they live in, centered on this node.
@export var area := Vector3(14, 3.5, 14):
	set(v):
		area = v
		_build()

@export_group("Look")
@export var size_min := 0.045
@export var size_max := 0.085
## Each firefly picks a tint between these, so a swarm is not one flat color.
@export var color_a := Color(0.85, 1.0, 0.45)
@export var color_b := Color(1.0, 0.86, 0.35)

@export_group("Blink")
## Average seconds between pulses.
@export var blink_interval := 2.6
@export var blink_length := 0.55
## Brightness between pulses. Zero makes them vanish entirely, which reads as a
## rendering fault rather than as darkness.
@export_range(0.0, 1.0, 0.01) var idle_glow := 0.06

@export_group("Drift")
@export var speed := 0.35
## Meters a firefly wanders from where it started.
@export var wander := 2.4
@export var bob := 0.35

@export_group("Editor")
@export var preview_in_editor := true

class Bug:
	var home: Vector3
	var phase: float
	var rate: float
	var size: float
	var tint: Color
	var next_blink: float
	var blink_until := -1.0

var _bugs: Array[Bug] = []
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _warned := false

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.frequency = 1.0
	_build()

## Builds the MultiMesh in code rather than storing one in the scene.
##
## A MultiMesh saved in a .tscn has to be duplicated per instance to avoid being
## shared, and that duplication copies properties in class order - which can reach
## instance_count before use_colors and transform_format. Those may only change
## while the count is 0, so it errors on load with no stack trace and no obvious
## source. Creating it here means the order is ours and nothing is serialized.
func _build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = draw_mesh
	mm.instance_count = maxi(count, 0)
	multimesh = mm
	_rng.seed = hash(name)
	_bugs.clear()
	for i in count:
		var b := Bug.new()
		b.home = Vector3(
			_rng.randf_range(-area.x, area.x) * 0.5,
			_rng.randf_range(-area.y, area.y) * 0.5,
			_rng.randf_range(-area.z, area.z) * 0.5)
		# Every firefly reads the same noise field from a different offset. Cheaper
		# than one generator each, and it stops the swarm moving as a sheet.
		b.phase = _rng.randf() * 1000.0
		b.rate = _rng.randf_range(0.7, 1.4)
		b.size = _rng.randf_range(size_min, size_max)
		b.tint = color_a.lerp(color_b, _rng.randf())
		b.next_blink = _rng.randf() * blink_interval
		_bugs.append(b)
	_update(0.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_update(delta)

func _update(delta: float) -> void:
	if multimesh == null or _bugs.is_empty():
		return
	# A MultiMesh sub-resource is shared between instances of a scene unless it is
	# marked resource_local_to_scene. Two of these nodes then resize the same
	# MultiMesh and whichever holds more writes past the end, once per frame.
	var n := mini(_bugs.size(), multimesh.instance_count)
	if n < _bugs.size() and not _warned:
		_warned = true
		push_warning("Fireflies %s: %d instances but %d bugs. Is the MultiMesh shared between nodes?"
			% [name, multimesh.instance_count, _bugs.size()])

	_t += delta
	for i in n:
		var b: Bug = _bugs[i]
		var t := _t * speed * b.rate

		# Three noise samples on separate offsets give a path that curls back on
		# itself, which keeps them inside the box without any clamping.
		var off := Vector3(
			_noise.get_noise_2d(b.phase, t),
			_noise.get_noise_2d(b.phase + 51.0, t * 0.7) * (bob / maxf(wander, 0.001)),
			_noise.get_noise_2d(b.phase + 133.0, t)) * wander

		# Long dark gap, short pulse. sin(p * PI) starts and ends at zero so
		# nothing snaps on or off.
		var glow := idle_glow
		if _t >= b.next_blink and b.blink_until < 0.0:
			b.blink_until = _t + blink_length
		if b.blink_until >= 0.0:
			if _t >= b.blink_until:
				b.blink_until = -1.0
				b.next_blink = _t + blink_interval * _rng.randf_range(0.5, 1.8)
			else:
				var p := 1.0 - (b.blink_until - _t) / maxf(blink_length, 0.01)
				glow = maxf(glow, sin(p * PI))

		var basis := Basis.IDENTITY.scaled(Vector3.ONE * b.size)
		multimesh.set_instance_transform(i, Transform3D(basis, b.home + off))
		multimesh.set_instance_color(i, Color(b.tint.r, b.tint.g, b.tint.b, glow))
