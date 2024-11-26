class_name AirbornePlayerState
extends PlayerMovementState

@export_subgroup("Modifiers")
## Default 60% vertical velocity preserved
@export_range(0.0, 1.0, 0.01) var jump_height_reduction : float = 0.6

# Export variables for jump parameters
@export_subgroup("Jump")
@export var JUMP_HEIGHT : float = 3  # Maximum height of a regular jump
@export var JUMP_TIME_TO_PEAK : float = 0.45  # Time to reach the peak of a regular jump
@export var JUMP_TIME_TO_DESCENT : float = 0.4  # Time to descend from the peak of a regular jump

# Export variables for double jump parameters
@export_subgroup("Double Jump")
@export var DOUBLE_JUMP_HEIGHT : float = 3  # Maximum height of a double jump
@export var DOUBLE_JUMP_TIME_TO_PEAK : float = 0.45  # Time to reach the peak of a double jump
@export var DOUBLE_JUMP_TIME_TO_DESCENT : float = 0.4  # Time to descend from the peak of a double jump

# Export variables for animation parameters
@export_group("Animation Modifiers")
@export var SPEED : float = 6.0  # Movement speed
@export var TOP_ANIM_SPEED : float = 2.2  # Maximum animation speed
@export var ANIMATION_BLEND_SPEED : float = 3.5  # Speed of blending between animations

var wall_slide_query : Dictionary  # Stores information about potential wall slides
var entered_by_jumping : bool = false  # Indicates if the state was entered by jumping
var entered_by_double_jumping : bool = false  # Indicates if the state was entered by jumping
var is_jump_released : bool = false
var is_player_initiated_jump : bool = false
var consec_jumps : int = 0

var reset_consec : bool = false

# Signal that I check for, outside force, resets is_jump_released to false
func _ready():
	super()
	# Then perform this class's specific initialization
	SignalManager.outside_force.connect(_on_outside_force_reset)

# Prob like oh if we enetered by jumping start timer, and when we release, end the timer
func enter(msg := {}) -> void:
	entered_by_jumping = msg.get("jumped", false)  # Check if we entered the state by jumping
	entered_by_double_jumping = msg.get("double_jumped", false)  # Check if we entered the state by jumping
	if entered_by_jumping:
		consec_jumps = msg.get("jumps", 0)
		perform_regular_jump()  # Perform a jump if we entered by jumping
	elif entered_by_double_jumping and PLAYER.remaining_jumps > 0:
		perform_double_jump()

func handle_input(event):
	if event.is_action_released("jump") and PLAYER.velocity.y > 0.0:
		
		if PLAYER.outside_force == false:
			is_jump_released = true  # Set flag for double jump release
		PLAYER.jump_hold_active = false
		#PLAYER.velocity.y *= jump_height_reduction
		
	elif event.is_action_pressed("jump"):
		is_jump_released = false
		if PLAYER.remaining_jumps > 0:
			perform_double_jump()  # Perform a double jump if we have jumps remaining
		else:
			start_jump_buffer()
	
	# Check for dash input
	if event.is_action_pressed("dash") and not PLAYER.is_dashed:
		transition.emit("DashPlayerState")

func update(_delta: float):
	PLAYER.update_input()  # Update player input

func physics_update(delta: float):
	PLAYER.handle_airborne_movement(delta, PLAYER.player_air_control)  # Handle air movement
	PLAYER.update_gravity(delta)  # Apply gravity
	PLAYER.update_velocity(delta)  # Update player velocity
	
	wall_slide_query = PLAYER.is_wall_slideable(delta)  # Check for wall slide
	
	if PLAYER.is_on_floor() or PLAYER._snapped_to_stairs_last_frame:
		handle_landing()  # Handle landing
		
	elif can_wall_slide():
		transition.emit("WallSlidePlayerState", wall_slide_query)  # Transition to wall slide state
	
func exit():
	is_jump_released = false  # Reset double jump release flag when exiting the state
	reset_consec = false

func perform_regular_jump():
	PLAYER.outside_force = false
	ANIMATION_STATE_MACHINE.travel("jump", true)  # Play jump animation
	match consec_jumps:
		0:
			PLAYER.jump(JUMP_HEIGHT, JUMP_TIME_TO_PEAK, JUMP_TIME_TO_DESCENT)  # Perform jump
		1:#.50
			PLAYER.jump(JUMP_HEIGHT + 0.75, JUMP_TIME_TO_PEAK + (JUMP_TIME_TO_PEAK * .23), JUMP_TIME_TO_DESCENT)  # Perform jump
		2:#.60
			PLAYER.jump(JUMP_HEIGHT + 2.5, JUMP_TIME_TO_PEAK + (JUMP_TIME_TO_PEAK * .35), JUMP_TIME_TO_DESCENT)  # Perform jump

func perform_double_jump():
	PLAYER.outside_force = false
	reset_consec = true
	ANIMATION_STATE_MACHINE.travel("double_jump", true)  # Play double jump animation
	PLAYER.jump(DOUBLE_JUMP_HEIGHT, DOUBLE_JUMP_TIME_TO_PEAK, DOUBLE_JUMP_TIME_TO_DESCENT)  # Perform double jump
	PLAYER.double_jump_direction_change()
	PLAYER.remaining_jumps -= 1  # Decrease remaining jumps
	
func handle_landing():
	PLAYER.previous_wall = {}  # Reset previous wall
	PLAYER.remaining_jumps = PLAYER.max_double_jump_count  # Reset remaining jumps
	PLAYER.outside_force = false
	
	if PLAYER.jump_buffer_active:
		perform_regular_jump()  # Perform a jump if jump buffer is active
	else:
		transition_to_idle()

func transition_to_idle():
	if PLAYER.movement_direction.is_zero_approx():
		PLAYER.velocity.x = 0  # Reset horizontal velocity
		PLAYER.velocity.z = 0  # Reset vertical velocity
	transition.emit("IdlePlayerState", {"reset": reset_consec})  # Transition to idle state
	
func can_wall_slide():
	# Check various conditions for wall sliding
	return (
		wall_slide_query.get("cam_slide", false) and
		PLAYER.previous_wall != wall_slide_query.get("prev_surface") and
		PLAYER.is_on_wall_only() and
		(Vector2(PLAYER.velocity.x, PLAYER.velocity.z).length_squared() > 0 or PLAYER.is_movement_ongoing()) and
		PLAYER.velocity.y < 0 and
		PLAYER.WALL_RAYCAST.is_colliding() and
		PLAYER.get_mesh_wall_angle() <= 65.0
	)

func start_jump_buffer():
	if PLAYER.JUMP_BUFFER_TIMER.is_stopped():
		PLAYER.JUMP_BUFFER_TIMER.start()
	PLAYER.jump_buffer_active  = true

func _on_outside_force_reset(body) -> void:
	if body == PLAYER:  # Ensure it's affecting this player
		is_jump_released = false
		PLAYER.outside_force = true
		PLAYER.jump_hold_active = false
