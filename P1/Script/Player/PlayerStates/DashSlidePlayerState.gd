extends PlayerMovementState
class_name DashSlidePlayerState
# TODO: Make snapping distance higher as we speed up

# Constants
const WALKING_SPEED: float = 7.0
const JUMP_SPEED_REDUCTION: float = 0.8
const BELOW_WALKING_SPEED_REDUCTION: float = 0.7
const DASH_SPEED_BOOST: float = 3.5

# Export variables
@export_group("Player Movement Modifiers")
## Slide jump velocity
@export var slide_y_velocity: float = 10.0
@export var max_slope_acceleration : float = 32
@export var slide_turn_friction : float = .55
@export var deceleration : float = 8.0
@export var boost_speed : float = 5.0


@export_group("Audio")
@export var max_volume_db: float = 0.0  # Max volume in dB
@export var min_volume_db: float = -40.0  # Min volume in dB


# Member variables
var dash_direction: Vector3
var can_move: bool = true
var previous_max_speed: float

const MIN_JUMP_TIME : float = .15 # .5 seconds
var time_accumulator : float = 0

# Onready variables
@onready var dash_slide_sfx: AudioStreamPlayer3D = %dash_slide_sfx

func handle_input(event: InputEvent) -> void:
	if not (PLAYER.is_on_floor() or PLAYER._snapped_to_stairs_last_frame):
		return
	
	# If we are too slow, we get our speed decreased
	if event.is_action_pressed("jump"):
		_handle_jump()

func _handle_jump() -> void:
	PLAYER.velocity.y = slide_y_velocity
	_adjust_horizontal_velocity()
	ANIMATION_STATE_MACHINE.travel("jump", true)
	transition.emit("AirbornePlayerState")

func _adjust_horizontal_velocity() -> void:
	var horizontal_velocity = Vector2(PLAYER.velocity.x, PLAYER.velocity.z)
	var speed = horizontal_velocity.length()

	if time_accumulator <= MIN_JUMP_TIME:
		# Add speed boost when time_accumulator is less than or equal to MIN_JUMP_TIME
		var boosted_velocity = horizontal_velocity.normalized() * (speed + boost_speed)
		PLAYER.velocity.x = boosted_velocity.x
		PLAYER.velocity.z = boosted_velocity.y
		
	# elif time_accumulator > MIN_JUMP_TIME:
	else:
		var reduction_factor = JUMP_SPEED_REDUCTION if speed > WALKING_SPEED else BELOW_WALKING_SPEED_REDUCTION
		var new_speed = min(WALKING_SPEED * reduction_factor, speed * reduction_factor)
		var reduced_velocity = horizontal_velocity.normalized() * new_speed
		PLAYER.velocity.x = reduced_velocity.x
		PLAYER.velocity.z = reduced_velocity.y
	
	PLAYER.velocity.y = slide_y_velocity  # Preserve the y velocity
	PLAYER.outside_force = true

func update(_delta: float) -> void:
	if can_move:
		PLAYER.update_input()

func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.handle_sliding(delta, max_slope_acceleration, slide_turn_friction, deceleration)
	PLAYER.update_velocity(delta)
	
	if PLAYER.is_on_floor() or PLAYER._snapped_to_stairs_last_frame:
		_handle_floor_state()
	else:
		_handle_airborne_state()
	
	_update_dash_slide_volume(delta)
	
	time_accumulator += delta

func _handle_floor_state() -> void:
	var velocity_squared = PLAYER.velocity.length_squared()
	if velocity_squared == 0:
		_stop_movement()
	elif int(velocity_squared) != 0:
		_continue_movement()

func _stop_movement() -> void:
	can_move = false
	PLAYER.is_double_jumped = false
	PLAYER.movement_direction = Vector3.ZERO
	dash_slide_sfx.stream_paused = true

func _continue_movement() -> void:
	can_move = true
	if dash_slide_sfx.stream_paused:
		dash_slide_sfx.stream_paused = false

func _handle_airborne_state() -> void:
	dash_slide_sfx.stream_paused = true
	if PLAYER.velocity.y < 0.0:
		ANIMATION_STATE_MACHINE.travel("fall")
		transition.emit("AirbornePlayerState")

func enter(_msg := {}) -> void:
	PLAYER.remaining_jumps += 1
	previous_max_speed = PLAYER.max_speed
	PLAYER.velocity += PLAYER.velocity.normalized() * DASH_SPEED_BOOST
	PLAYER.is_sliding = true
	ANIMATION_STATE_MACHINE.travel("belly_land")
	_play_dash_slide_sound()

func exit() -> void:
	can_move = true
	PLAYER.is_sliding = false
	PLAYER.is_dashed = false
	dash_slide_sfx.stop()
	PLAYER.max_speed = previous_max_speed
	time_accumulator = 0

func _play_dash_slide_sound() -> void:
	if int(PLAYER.velocity.length_squared()) > 0:
		dash_slide_sfx.play()

func _update_dash_slide_volume(delta: float) -> void:
	var velocity_length = int(PLAYER.velocity.length())
	if velocity_length > 0:
		var volume = PLAYER.expDecay(min_volume_db, max_volume_db, 4 * velocity_length, delta)
		dash_slide_sfx.volume_db = volume
	else:
		dash_slide_sfx.volume_db = min_volume_db
