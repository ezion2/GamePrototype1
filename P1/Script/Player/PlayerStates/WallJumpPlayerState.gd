class_name WallJumpPlayerState
extends PlayerMovementState

# Export variables for player movement modifiers
@export_group("Player Movement Modifiers")
@export var air_control: float = 0.15
@export_range(0.001, 0.015, 0.001) var INPUT_MULTIPLIER: float = 0.001
@export_range(1.0, 30.0, 0.5) var WALL_JUMP_MULTIPLIER: float = 12

# Export variables for jump parameters
@export_subgroup("Jump")
@export_range(3.0, 10.0, 0.5) var JUMP_HEIGHT: float = 3
@export_range(0.45, 0.95, 0.05) var JUMP_TIME_TO_PEAK: float = 0.45  # In seconds
@export_range(0.4, 0.9, 0.1) var JUMP_TIME_TO_DESCENT: float = 0.4  # In seconds

# State variables
var wall_normal: Vector3
var wall_slide_query: Dictionary
var air_control_cache: float

func enter(msg := {}) -> void:
	PLAYER.is_wall_jump = true
	
	# Cache and set air control
	air_control_cache = PLAYER.player_air_control
	PLAYER.player_air_control = air_control
	
	# Set wall normal and rotate player to face away from wall
	wall_normal = msg.get("wall_normal", Vector3.ZERO)
	var target_rotation = atan2(wall_normal.x, wall_normal.z)
	PLAYER.MESH_ROOT.rotation.y = target_rotation
	PLAYER.COLLIDER.rotation.y = target_rotation
	
	# Perform wall jump
	wall_jump()

func exit() -> void:
	PLAYER.is_wall_jump = false
	PLAYER.player_air_control = air_control_cache

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and not PLAYER.is_dashed:
		transition.emit("DashPlayerState")
	elif event.is_action_pressed("jump"):
		transition.emit("AirbornePlayerState", {"double_jumped": true})

func update(_delta: float) -> void:
	PLAYER.update_input()

func physics_update(delta: float) -> void:
	# Update player physics
	PLAYER.update_gravity(delta)
	PLAYER.handle_airborne_movement(delta, PLAYER.player_air_control)
	PLAYER.update_velocity(delta)
	
	# Check for potential wall slides
	wall_slide_query = PLAYER.is_wall_slideable(delta)
	
	if can_wall_slide():
		transition.emit("WallSlidePlayerState", wall_slide_query)
	elif is_airborne():
		handle_airborne_state()
	else:
		handle_grounded_state()

func can_wall_slide() -> bool:
	return (
		wall_slide_query.get("cam_slide", false) and
		PLAYER.previous_wall != wall_slide_query.get("prev_surface") and
		PLAYER.is_on_wall_only() and
		(Vector2(PLAYER.velocity.x, PLAYER.velocity.z).length() > 0 or PLAYER.is_movement_ongoing() or abs(PLAYER.velocity.y) > 0) and
		PLAYER.WALL_RAYCAST.is_colliding() and
		PLAYER.get_mesh_wall_angle() <= 65.0
	)

func is_airborne() -> bool:
	return not PLAYER.is_on_floor() and not PLAYER._snapped_to_stairs_last_frame

func handle_airborne_state() -> void:
	if PLAYER.velocity.y < 0.0:
		transition.emit("AirbornePlayerState")

func handle_grounded_state() -> void:
	if PLAYER.velocity.length_squared() == 0.0 or not PLAYER.is_movement_ongoing():
		PLAYER.velocity.x = 0
		PLAYER.velocity.z = 0
	transition.emit("IdlePlayerState")

func wall_jump() -> void:
	ANIMATION_STATE_MACHINE.travel("jump", true)
	PLAYER.jump(JUMP_HEIGHT, JUMP_TIME_TO_PEAK, JUMP_TIME_TO_DESCENT)
	PLAYER.velocity.x = WALL_JUMP_MULTIPLIER * wall_normal.x
	PLAYER.velocity.z = WALL_JUMP_MULTIPLIER * wall_normal.z
