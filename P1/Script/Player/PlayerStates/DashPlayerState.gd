class_name DashPlayerState
extends PlayerMovementState

# Export variables for player movement modifiers
@export_group("Player Movement Modifiers")
@export var air_control: float = 0.15
@export var dash_y_velocity: float = 10
@export var dash_xz_velocity: float = 15
@export var dash_jump_velocity: float = 12

# State variables
var dash_direction: Vector3
var air_control_cache: float

# Constants for velocity reduction factors
const NO_MOVEMENT_REDUCTION: float = 0.1  # 90% reduction
const MAX_SPEED_REDUCTION: float = 0.4   # 60% reduction
const BELOW_MAX_SPEED_REDUCTION: float = 0.65  # 35% reduction

func enter(_msg := {}) -> void:
	# Set dash state
	PLAYER.is_dashed = true
	PLAYER.air_dashing = true
	PLAYER.jump_hold_active = false
	
	# Cache and set air control
	air_control_cache = PLAYER.player_air_control
	PLAYER.player_air_control = air_control
	
	# Play dash animation
	ANIMATION_STATE_MACHINE.travel("dash", true)
	
	# Calculate dash direction and apply velocity
	calculate_dash_direction()
	apply_dash_velocity()

func exit() -> void:
	PLAYER.air_dashing = false
	PLAYER.player_air_control = air_control_cache

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and PLAYER.remaining_jumps > 0:
		perform_dash_jump()

func update(_delta: float) -> void:
	PLAYER.update_input()

func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.handle_airborne_movement(delta, PLAYER.player_air_control)
	PLAYER.update_velocity(delta)
	
	if PLAYER.is_on_floor() or PLAYER._snapped_to_stairs_last_frame:
		transition.emit("DashSlidePlayerState")

func calculate_dash_direction() -> void:
	var movement_ongoing: bool = not PLAYER.movement_direction.is_zero_approx()
	
	if movement_ongoing:
		dash_direction = PLAYER.movement_direction.normalized()
		# Instant turn model in direction of the player's movement direction
		PLAYER.MESH_ROOT.rotation.y = atan2(PLAYER.movement_direction.x, PLAYER.movement_direction.z)
	else:
		dash_direction = -(PLAYER.MESH_ROOT.global_transform.origin - PLAYER.DASH_TARGET.global_transform.origin)
		dash_direction.y = 0
		dash_direction = dash_direction.normalized()

func apply_dash_velocity() -> void:
	PLAYER.velocity = dash_direction * dash_xz_velocity
	PLAYER.velocity.y = dash_y_velocity

func perform_dash_jump() -> void:
	PLAYER.remaining_jumps -= 1
	ANIMATION_STATE_MACHINE.travel("double_jump", true)
	
	PLAYER.velocity.y = dash_jump_velocity
	
	var current_horizontal_velocity = Vector2(PLAYER.velocity.x, PLAYER.velocity.z)
	var current_speed = current_horizontal_velocity.length()
	
	var reduction_factor = get_velocity_reduction_factor(current_speed)
	
	PLAYER.velocity.x *= reduction_factor
	PLAYER.velocity.z *= reduction_factor
	PLAYER.outside_force = true
	
	transition.emit("AirbornePlayerState")

# TODO: reduces to max speed cap * some friction reduction value, but only if above max speed
func get_velocity_reduction_factor(current_speed: float) -> float:
	if current_speed == 0:
		return NO_MOVEMENT_REDUCTION
	elif current_speed >= PLAYER.max_speed:
		return MAX_SPEED_REDUCTION
	else:
		return BELOW_MAX_SPEED_REDUCTION
