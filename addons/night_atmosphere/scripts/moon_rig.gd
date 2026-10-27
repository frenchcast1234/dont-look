@tool
extends DirectionalLight3D
## Moonlight, plus the volumetric fog that turns it into visible shafts.
##
## Godot's volumetric fog is per-light, so a moon aimed through a window or a gap in
## the trees throws a real shaft that moves with the camera. It costs one property
## on the light and a handful on the environment.
##
## This node is the light. Aim it by rotating it; a DirectionalLight3D ignores its
## position, so where you place it only affects where the gizmo sits.
##
## Requires the Forward+ renderer. Volumetric fog is not available in Compatibility.

@export_group("Moon")
@export var moon_color := Color(0.62, 0.72, 1.0):
	set(v):
		moon_color = v
		_apply()
@export_range(0.0, 4.0, 0.01) var moon_energy := 0.35:
	set(v):
		moon_energy = v
		_apply()
## Softens shadow edges. Moonlight is a small source, so keep this low, but not at
## zero or every shadow is razor sharp and reads as a spotlight.
@export_range(0.0, 5.0, 0.05) var softness := 0.6:
	set(v):
		softness = v
		_apply()
@export var cast_shadows := true:
	set(v):
		cast_shadows = v
		_apply()

@export_group("Shafts")
## How strongly this light shows up in the fog. Above about 2 it stops looking like
## light and starts looking like smoke.
@export_range(0.0, 8.0, 0.05) var shaft_strength := 1.6:
	set(v):
		shaft_strength = v
		_apply()
## Sets volumetric fog up on the scene's WorldEnvironment. Off leaves it untouched.
@export var manage_volumetric_fog := true:
	set(v):
		manage_volumetric_fog = v
		_apply()
@export_range(0.0, 0.2, 0.001) var fog_density := 0.022:
	set(v):
		fog_density = v
		_apply()
## Positive values push light forward through the fog, which is what makes a shaft
## brighten as you look along it. At 0 the scattering is even and reads flat.
@export_range(-0.9, 0.9, 0.01) var anisotropy := 0.4:
	set(v):
		anisotropy = v
		_apply()
@export var fog_albedo := Color(0.78, 0.84, 0.95):
	set(v):
		fog_albedo = v
		_apply()
## Meters the fog volume reaches.
##
## This is a QUALITY setting as much as a range one. Volumetric fog is computed in
## a fixed froxel grid stretched over this distance, so doubling it halves the
## depth resolution and the fog starts to look like stacked slabs. Keep it just
## long enough to cover the shot.
##
## If it still looks blocky, raise the grid itself in Project Settings under
## Rendering > Environment > Volumetric Fog (volume_size and volume_depth, 64 by
## default) and make sure Use Filter is on.
@export var fog_distance := 48.0:
	set(v):
		fog_distance = v
		_apply()

## How the froxels are distributed through the volume. Godot packs them toward the
## camera on a curve, so at the 2.0 default the far half of the volume gets very
## coarse cells and reads as flat slabs that do not blend.
##
## 1.0 spreads them evenly, which is usually the right answer for a scene where the
## interesting fog is 10 to 40 meters out rather than in your face.
@export_range(0.5, 6.0, 0.1) var fog_detail_spread := 1.0:
	set(v):
		fog_detail_spread = v
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	light_color = moon_color
	light_energy = moon_energy
	shadow_enabled = cast_shadows
	light_angular_distance = softness
	# Without this the light is in the scene but not in the air, and no amount of
	# fog density will produce a shaft.
	light_volumetric_fog_energy = shaft_strength

	if not manage_volumetric_fog:
		return
	var env := _environment()
	if env == null:
		return
	env.volumetric_fog_enabled = fog_density > 0.0
	env.volumetric_fog_density = fog_density
	env.volumetric_fog_anisotropy = anisotropy
	env.volumetric_fog_albedo = fog_albedo
	env.volumetric_fog_length = fog_distance
	env.volumetric_fog_detail_spread = fog_detail_spread
	# The fog emits nothing of its own; it only scatters what lights put into it.
	# Raising this fills the scene with even haze and flattens the shafts.
	env.volumetric_fog_emission_energy = 0.0
	# Blends each frame's froxel grid with the last one. It is on by default, but a
	# scene that has had its environment hand-edited may have lost it, and without
	# it the grid edges crawl instead of sitting still.
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.9

func _environment() -> Environment:
	var root := get_tree().get_edited_scene_root() if Engine.is_editor_hint() \
		else get_tree().current_scene
	if root == null:
		return null
	var we := _find_world_env(root)
	return we.environment if we != null else null

static func _find_world_env(from: Node) -> WorldEnvironment:
	var we := from as WorldEnvironment
	if we != null:
		return we
	for c in from.get_children():
		var hit := _find_world_env(c)
		if hit != null:
			return hit
	return null
