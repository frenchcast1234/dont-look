@tool
extends Node3D
## Wrapper for the mist sheet, so the settings you actually reach for sit at the top
## of the inspector instead of four clicks down inside the material.
##
## It also makes the mesh and material unique per instance. Without that, several
## mist planes dropped into one scene share a single material and setting the
## density on one sets it on all of them.
##
## Only the common controls are mirrored here. Noise scales, the second layer and
## the near fade stay on the material, where they belong: they are set once for a
## look and then left alone, and duplicating every uniform as an export is how the
## two end up disagreeing.

@export var size := Vector2(30, 30):
	set(v):
		size = v
		_apply_mesh()
## Height of the sheet above this node. Ankle to knee reads as ground mist; higher
## starts to look like a cloud layer.
@export var height := 0.35:
	set(v):
		height = v
		_apply_mesh()

@export_group("Look")
@export_range(0.0, 1.0, 0.01) var density := 0.32:
	set(v):
		density = v
		_apply_material()
@export var color := Color(0.72, 0.78, 0.86):
	set(v):
		color = v
		_apply_material()
## How hard the noise threshold is. Above about 2 it starts finding edges in the
## noise rather than shapes.
@export_range(0.5, 4.0, 0.05) var contrast := 1.5:
	set(v):
		contrast = v
		_apply_material()
## Meters of fade where the mist meets solid geometry. This is what stops it being
## a visible rectangle, so keep it above about 0.5.
@export_range(0.05, 4.0, 0.05) var soft_fade := 1.1:
	set(v):
		soft_fade = v
		_apply_material()
## How far in from the plane edge it fades out, as a fraction.
@export_range(0.0, 0.5, 0.01) var edge_fade := 0.22:
	set(v):
		edge_fade = v
		_apply_material()

@export_group("Motion")
@export var drift := Vector2(0.012, 0.006):
	set(v):
		drift = v
		_apply_material()

var _sheet: MeshInstance3D
var _mat: ShaderMaterial

func _ready() -> void:
	_resolve()
	_apply_mesh()
	_apply_material()

func _resolve() -> void:
	if _sheet == null:
		_sheet = get_node_or_null("Sheet") as MeshInstance3D
	if _sheet == null or _sheet.mesh == null:
		return
	# Unique per instance. The scene marks both resource_local_to_scene, but a node
	# built by hand or duplicated in the editor may not have picked that up.
	if not _sheet.mesh.resource_local_to_scene:
		_sheet.mesh = _sheet.mesh.duplicate()
		_sheet.mesh.resource_local_to_scene = true
	var m := _sheet.mesh as PlaneMesh
	if m != null and m.material is ShaderMaterial:
		if not m.material.resource_local_to_scene:
			m.material = m.material.duplicate()
			m.material.resource_local_to_scene = true
		_mat = m.material as ShaderMaterial

func _apply_mesh() -> void:
	if not is_inside_tree():
		return
	_resolve()
	if _sheet == null:
		return
	var m := _sheet.mesh as PlaneMesh
	if m == null:
		return
	m.size = size
	_sheet.position.y = height

func _apply_material() -> void:
	if not is_inside_tree():
		return
	_resolve()
	if _mat == null:
		return
	_mat.set_shader_parameter("density", density)
	_mat.set_shader_parameter("mist_color", color)
	_mat.set_shader_parameter("contrast", contrast)
	_mat.set_shader_parameter("soft_fade", soft_fade)
	_mat.set_shader_parameter("edge_fade", edge_fade)
	_mat.set_shader_parameter("drift", drift)
