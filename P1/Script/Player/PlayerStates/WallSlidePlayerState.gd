class_name WallSlidePlayerState
extends PlayerMovementState

# TODO: Slide on walls that are 90 degrees from the ground
var wall_normal : Vector3

func enter(_msg := {}) -> void:
	ANIMATION_STATE_MACHINE.travel("wall_slide", true)
	
	PLAYER.is_wall_slide = true
	PLAYER.velocity = Vector3.ZERO
	
	# Extract wall information from message
	wall_normal = _msg.get("wall_normal", Vector3.ZERO)
	var target_position: Vector3 = _msg.get("target_position", PLAYER.global_position)
	
	# Calculate and apply rotation to face the wall
	var target_rotation: float = atan2(-wall_normal.x, -wall_normal.z)
	PLAYER.MESH_ROOT.rotation.y = target_rotation
	PLAYER.COLLIDER.rotation.y = target_rotation
	
	# Adjust player position to the wall
	PLAYER.global_position = Vector3(target_position.x, PLAYER.global_position.y, target_position.z)
	
	# Store previous wall information
	PLAYER.previous_wall = {
		"prev_rid": _msg.get("prev_surface", {}).get("prev_rid", {}),
		"prev_normal": _msg.get("prev_surface", {}).get("prev_normal", {})
	}
	
	_play_wall_slide_sound()
	
func exit() -> void:
	PLAYER.movement_direction = Vector3.ZERO
	PLAYER.is_wall_slide = false
	wall_slide_sfx.stop()
	
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		transition.emit("WallJumpPlayerState", {"wall_normal": wall_normal})
		
	elif event.is_action_pressed("dash"):
		transition.emit("AirbornePlayerState")
		
	
func physics_update(delta: float) -> void:
	apply_wall_slide_gravity(delta)
	PLAYER.update_velocity(delta)
	PLAYER.WALL_RAYCAST.force_raycast_update()
	
	if PLAYER.is_on_floor() or PLAYER._snapped_to_stairs_last_frame:
		handle_grounded_state()
	elif not PLAYER.WALL_RAYCAST.is_colliding():
		transition.emit("AirbornePlayerState")
	
	_update_wall_slide_volume(delta)
	
func handle_grounded_state() -> void:
	PLAYER.previous_wall.clear()
	
	ANIMATION_STATE_MACHINE.travel("idle_walk")
	if PLAYER.velocity.length_squared() == 0:
		transition.emit("IdlePlayerState")
	elif PLAYER.is_movement_ongoing():
		transition.emit("SprintingPlayerState" if Input.is_action_pressed("sprint") else "WalkingPlayerState")
		
func apply_wall_slide_gravity(delta) -> void:
	PLAYER.velocity.y += PLAYER.expDecay(0.0, -1.0, 0.5, delta)
	PLAYER.velocity.y = clamp(PLAYER.velocity.y, -5, 5000)

# Sound properties
@export_subgroup("SFX Volume")
@export var max_volume_db: float = 2.0  # Max volume in dB
@export var min_volume_db: float = -5.0  # Min volume in dB
@onready var wall_slide_sfx: AudioStreamPlayer3D = %wall_slide_sfx

func _play_wall_slide_sound() -> void:
	wall_slide_sfx.play()

func _update_wall_slide_volume(delta) -> void:
	#var velocity_length = int(PLAYER.velocity.length())
	if PLAYER.velocity.length_squared() > 0:
		#var volume = lerp(min_volume_db, max_volume_db, 2 * delta)
		var volume = PLAYER.expDecay(min_volume_db, max_volume_db, 2, delta)
		wall_slide_sfx.volume_db = volume
	else:
		wall_slide_sfx.volume_db = min_volume_db
