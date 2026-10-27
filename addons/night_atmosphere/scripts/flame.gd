@tool
extends Node3D
## Wrapper for the flame quad and its light, so a candle becomes a hearth by
## changing one number instead of editing a mesh, a material and a light.
##
## It also makes the mesh and material unique per instance. Without that, every
## flame in a scene shares one material and setting the seed on one sets it on all
## of them, which is exactly the case where you wanted them different.
##
## The shader is UV based, so scaling the quad scales the pattern with it. A big
## flame with candle settings looks like a candle filmed close up, which is why
## `size` also nudges the noise and the rise speed unless you turn that off.

## Width and height of the flame in meters. The base sits at this node's origin.
@export var size := Vector2(0.16, 0.3):
	set(v):
		size = v
		_apply_mesh()
		_apply_material()
		_apply_light()
## Scales noise detail and rise speed with `size`, so a hearth does not look like a
## magnified candle. Turn off if you want to set those by hand.
@export var scale_with_size := true:
	set(v):
		scale_with_size = v
		_apply_material()

@export_group("Shape")
## Width at the base, in UV. Below about 0.4 it reads as a wisp.
@export_range(0.1, 1.0, 0.01) var width := 0.62:
	set(v):
		width = v
		_apply_material()
## How sharply it pinches toward the tip. Lower is taller and thinner.
@export_range(0.1, 3.0, 0.05) var taper := 1.15:
	set(v):
		taper = v
		_apply_material()
## How much the noise eats into the silhouette. This is what makes it read as flame
## rather than as a leaf.
@export_range(0.0, 1.0, 0.01) var bite := 0.42:
	set(v):
		bite = v
		_apply_material()
## Edge hardness. High is cel shaded, low is a soft glow.
@export_range(0.5, 40.0, 0.5) var edge := 9.0:
	set(v):
		edge = v
		_apply_material()
## Fraction of the height taken off the very tip. The silhouette already tapers to
## a point, so this only needs to be large enough to stop the noise leaving a speck
## up there. Raising it visibly shortens the flame and removes the point.
@export_range(0.0, 0.4, 0.005) var tip_fade := 0.05:
	set(v):
		tip_fade = v
		_apply_material()
## Fraction faded out at the base, so it does not sit on the wick as a flat cut.
@export_range(0.0, 0.4, 0.005) var base_fade := 0.12:
	set(v):
		base_fade = v
		_apply_material()

@export_group("Motion")
## Feature size of the noise. Lower means larger, slower shapes.
@export var noise_scale := 3.2:
	set(v):
		noise_scale = v
		_apply_material()
## How fast the flame climbs. Big fires read slower than small ones.
@export var rise_speed := 1.6:
	set(v):
		rise_speed = v
		_apply_material()
@export_range(0.0, 0.4, 0.005) var sway := 0.06:
	set(v):
		sway = v
		_apply_material()
@export var sway_speed := 1.9:
	set(v):
		sway_speed = v
		_apply_material()
## Offsets this flame in the noise field. Two flames sharing a seed move in step.
@export var seed_value := 0.0:
	set(v):
		seed_value = v
		_apply_material()
## Picks a random seed on ready, so a row of torches never syncs up.
@export var random_seed := true

@export_group("Color")
@export var core_color := Color(1.0, 0.96, 0.80):
	set(v):
		core_color = v
		_apply_material()
@export var mid_color := Color(1.0, 0.63, 0.18):
	set(v):
		mid_color = v
		_apply_material()
@export var rim_color := Color(0.85, 0.19, 0.03):
	set(v):
		rim_color = v
		_apply_material()
@export_range(0.0, 8.0, 0.05) var brightness := 2.4:
	set(v):
		brightness = v
		_apply_material()

@export_group("Light")
@export var light_enabled := true:
	set(v):
		light_enabled = v
		_apply_light()
## Brightness of the child FlickerLight.
@export_range(0.0, 12.0, 0.05) var light_energy := 1.2:
	set(v):
		light_energy = v
		_apply_light()
## Reach in meters. Left at 0 it is derived from `size`, which keeps a hearth from
## lighting the same radius as a candle.
@export var light_range := 0.0:
	set(v):
		light_range = v
		_apply_light()
## Where up the flame the light sits, as a fraction of height.
@export_range(0.0, 1.0, 0.01) var light_height := 0.55:
	set(v):
		light_height = v
		_apply_light()

var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _light: OmniLight3D

func _ready() -> void:
	if random_seed and not Engine.is_editor_hint():
		seed_value = randf() * 100.0
	_resolve()
	_apply_mesh()
	_apply_material()
	_apply_light()

func _resolve() -> void:
	if _quad == null:
		_quad = get_node_or_null("Quad") as MeshInstance3D
	if _light == null:
		_light = get_node_or_null("FlickerLight") as OmniLight3D
	if _quad == null or _quad.mesh == null:
		return
	# Unique per instance. The scene marks both resource_local_to_scene, but a node
	# assembled by hand will not have picked that up.
	if not _quad.mesh.resource_local_to_scene:
		_quad.mesh = _quad.mesh.duplicate()
		_quad.mesh.resource_local_to_scene = true
	var m := _quad.mesh as QuadMesh
	if m != null and m.material is ShaderMaterial:
		if not m.material.resource_local_to_scene:
			m.material = m.material.duplicate()
			m.material.resource_local_to_scene = true
		_mat = m.material as ShaderMaterial

func _apply_mesh() -> void:
	if not is_inside_tree():
		return
	_resolve()
	if _quad == null:
		return
	var m := _quad.mesh as QuadMesh
	if m == null:
		return
	m.size = size
	# Half the height, so the wick end sits on this node's origin rather than the
	# flame being centered on it.
	m.center_offset = Vector3(0, size.y * 0.5, 0)

func _apply_material() -> void:
	if not is_inside_tree():
		return
	_resolve()
	if _mat == null:
		return
	# A candle is 0.3 m tall. Anything larger gets proportionally coarser noise and
	# a slower climb, which is what stops a hearth looking like a magnified candle.
	var k := 1.0
	if scale_with_size:
		k = clampf(0.3 / maxf(size.y, 0.01), 0.25, 2.0)
	_mat.set_shader_parameter("width", width)
	_mat.set_shader_parameter("taper", taper)
	_mat.set_shader_parameter("bite", bite)
	_mat.set_shader_parameter("edge", edge)
	_mat.set_shader_parameter("tip_fade", tip_fade)
	_mat.set_shader_parameter("base_fade", base_fade)
	_mat.set_shader_parameter("noise_scale", noise_scale * k)
	_mat.set_shader_parameter("rise_speed", rise_speed * sqrt(k))
	_mat.set_shader_parameter("sway", sway)
	_mat.set_shader_parameter("sway_speed", sway_speed)
	_mat.set_shader_parameter("seed", seed_value)
	_mat.set_shader_parameter("core_color", core_color)
	_mat.set_shader_parameter("mid_color", mid_color)
	_mat.set_shader_parameter("rim_color", rim_color)
	_mat.set_shader_parameter("brightness", brightness)

func _apply_light() -> void:
	if not is_inside_tree():
		return
	_resolve()
	if _light == null:
		return
	_light.visible = light_enabled
	_light.position.y = size.y * light_height
	if "base_energy" in _light:
		_light.base_energy = light_energy
	else:
		_light.light_energy = light_energy
	# A flame lights roughly ten times its own height before it fades out.
	_light.omni_range = light_range if light_range > 0.0 else maxf(size.y * 11.0, 1.0)
