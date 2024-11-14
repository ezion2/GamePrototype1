extends Node3D

# Default pool size
@export var pool_size : int = 7  # Adjust based on your needs

# This will be what our pool is comprised of which will be the dust scene.
@export var particle_scene: PackedScene  # Assign your dust particle scene in the inspector

# Needs to be a dictionary so we can keep track of each particle individually
var particle_pool : Array[Dictionary] = []

# Index to Loop through everything
var next_particle_index : int = 0

# Create pool of particles at the start
func _ready():
	initialize_pool()

func initialize_pool():
	# Loop through the pool, populating it with dust scenes
	for i in pool_size:
		var particle = particle_scene.instantiate() as GPUParticles3D
		
		particle.emitting = false
		particle.one_shot = true
		
		add_child(particle)
		
		particle_pool.append({"particle": particle, "emitting": false})

func get_next_particle() -> Dictionary:
	if particle_pool.is_empty():
		return {}
		
	var particle = particle_pool[next_particle_index]
	next_particle_index = (next_particle_index + 1) % pool_size
	
	# If the particle is not emitting, return said particle, otherwise return empty
	if not particle["emitting"]:
		return particle
	else:
		return {}
	
func kickup_effect() -> void:
	var particle = get_next_particle()
	if !particle.is_empty():
		
		# This will start the emission
		particle["particle"].restart()
		particle["emitting"] = true
		
		# Signal that returns when the particle finishes emitting
		await particle["particle"].finished
		
		particle["emitting"] = false
