extends RayCast3D

@onready var beam_mesh = $BeamMesh
@onready var end_particles = $EndParticles
@onready var beam_particles = $BeamParticles

var tween: Tween
var beam_radius: float = 0.03

func _ready() -> void:
	desactivate(0) 
	
func _process(delta: float) -> void:
	var cast_point
	force_raycast_update()
	
	if is_colliding():
		cast_point = to_local(get_collision_point())
		
		beam_mesh.mesh.height = cast_point.z
		beam_mesh.position.z = cast_point.z / 2

		end_particles.position.z = cast_point.z

		beam_particles.position.z = cast_point.z / 2
		
		var particles_amout = snapped(abs(cast_point.z) * 50, 1)
		if particles_amout > 1:
			beam_particles.amount = particles_amout
		else:
			beam_particles.amount = 1
		beam_particles.process_material.set_emission_box_extents(
			Vector3(beam_mesh.mesh.top_radius, abs(cast_point.z) / 2, beam_mesh.mesh.top_radius)
		)

func activate(time: float):
	tween = get_tree().create_tween()
	visible = true
	beam_particles.emitting = true
	end_particles.emitting = true
	tween.set_parallel(true)
	tween.tween_property(beam_mesh.mesh, "top_radius", beam_radius, time)
	tween.tween_property(beam_mesh.mesh, "bottom_radius", beam_radius, time)
	tween.tween_property(beam_particles.process_material, "scale_min", 1, time)
	tween.tween_property(end_particles.process_material, "scale_min", 1, time)
	await tween.finished
	
func desactivate(time: float):
	tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam_mesh.mesh, "top_radius", 0.0, time)
	tween.tween_property(beam_mesh.mesh, "bottom_radius", 0.0, time)
	tween.tween_property(beam_particles.process_material, "scale_min", 0, time)
	tween.tween_property(end_particles.process_material, "scale_min", 0, time)
	await tween.finished
	visible = false
	beam_particles.emitting = false
	end_particles.emitting = false
