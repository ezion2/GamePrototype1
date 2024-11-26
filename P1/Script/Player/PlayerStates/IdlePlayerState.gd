# Idle state:
# From Idle, we can transition to five states:
# 1. Move
# 2. Jump
# 3. Fall
# 4. Wall Slide (To be implemented later)
# 5. Death (To be implemented later)

class_name IdlePlayerState
extends PlayerMovementState

# Signal to see how long after being on the ground for like triple jumps
# Using a timer to see how long we have been on the ground for
# Horizontal velocity will determine movement
# TODO: make idle walk have their own speed modifier

@export_group("Player Movement Modifiers")
@export_subgroup("Walking")
@export var walk_speed : float = 7.0
@export var walk_turn_friction : float = 4.0

@export_subgroup("Sprinting")
@export var sprint_speed : float = 21.0
@export var sprint_turn_friction : float = 3.6
@export var sprint_braking : float = 30.0

@export_subgroup("Jumping")
@export var JUMP_RESET_TIME : float = .3

@export_group("Animation Modifiers")
@export var TOP_ANIM_SPEED : float = 1.5
@export var ANIMATION_BLEND_SPEED : float = 3.5
@export var brake_speed_threshold : float = 1.0
@export var brake_window_duration : float = 1.0  # Window to brake after releasing sprint

var time_since_last_jump : float = 0
var consec_jumps : int = 0
var reset_consec : bool = false

var was_sprinting : bool = false
var was_moving : bool = false
var sprint_release_timer : float = 0.0
var can_brake_after_sprint : bool = false

func handle_input(event):
	if event.is_action_pressed("jump"):
		if time_since_last_jump <= JUMP_RESET_TIME:
			if !PLAYER.movement_direction.is_zero_approx():
				consec_jumps = (consec_jumps + 1) % 3 if reset_consec == false else 0
			else:
				consec_jumps = 0
				
		transition.emit("AirbornePlayerState", {"jumped": true, "jumps": consec_jumps})
		
	elif event.is_action_pressed("sprint"):
		set_sprint_state(true)
		# Start the brake window timer when releasing sprint while moving
		if !PLAYER.movement_direction.is_zero_approx():
			sprint_release_timer = brake_window_duration
			can_brake_after_sprint = true
		
	elif event.is_action_released("sprint"):
		set_sprint_state(false)
		# Start the brake window timer when releasing sprint while moving
		if !PLAYER.movement_direction.is_zero_approx():
			sprint_release_timer = brake_window_duration
			can_brake_after_sprint = true
			
	elif event.is_action_pressed("dash"):
		transition.emit("DashPlayerState")

func update(delta: float):
	PLAYER.update_input()
	animation_blend(delta)
	
	var current_speed = Vector2(PLAYER.velocity.x, PLAYER.velocity.z).length()
	var is_moving_now = !PLAYER.movement_direction.is_zero_approx()
	
	# Update sprint release timer if active
	if sprint_release_timer > 0:
		sprint_release_timer -= delta
		if sprint_release_timer <= 0:
			can_brake_after_sprint = false
	
	# Check brake conditions:
	# 1. Currently holding sprint and stopping movement
	# 2. Recently released sprint (within window) and stopping movement
	if was_moving and !is_moving_now and current_speed > brake_speed_threshold:
		if Input.is_action_pressed("sprint") or can_brake_after_sprint:
			if ANIMATION_STATE_MACHINE.get_current_node() != "land":
				ANIMATION_STATE_MACHINE.travel("brake")
			can_brake_after_sprint = false  # Reset after using the brake window
			
	
	# Update movement tracking
	was_moving = is_moving_now
	

func physics_update(delta: float):
	PLAYER.update_gravity(delta)
	PLAYER.handle_velocity_physics(delta, PLAYER.turn_friction, false, PLAYER.deceleration, PLAYER.movement_direction)
	PLAYER.update_velocity(delta)
	
	# We somehow start falling
	if !PLAYER.is_on_floor() and !PLAYER._snapped_to_stairs_last_frame:
		transition.emit("AirbornePlayerState")
		
	time_since_last_jump  += delta
	if time_since_last_jump > JUMP_RESET_TIME:
		consec_jumps = 0


func enter(_msg := {}) -> void:
	PLAYER.is_dashed = false
	reset_consec = _msg.get("reset", false)
	if reset_consec:
		consec_jumps = 0
		
	# Initialize movement tracking states
	was_moving = !PLAYER.movement_direction.is_zero_approx()
	sprint_release_timer = 0.0
	
	# Check if sprint is being held when entering the state
	if Input.is_action_pressed("sprint"):
		set_sprint_state(true)
	else:
		set_sprint_state(false)
	
func exit() -> void:
	time_since_last_jump = 0
	sprint_release_timer = 0.0
	can_brake_after_sprint = false

func set_sprint_state(sprinting: bool) -> void:
	if sprinting:
		PLAYER.max_speed = sprint_speed
		PLAYER.turn_friction = sprint_turn_friction
	else:
		PLAYER.max_speed = walk_speed
		PLAYER.turn_friction = walk_turn_friction


# Make it so when we stop walking, we idle
func animation_blend(delta: float) -> void:
	# Calculate horizontal velocity magnitude
	var horizontal_velocity = Vector2(PLAYER.velocity.x, PLAYER.velocity.z).length()
	
	# Calculate target blend value
	var target_blend = 0.0
	if horizontal_velocity > 0:
		target_blend = clamp(horizontal_velocity / 5.0, 0.0, 1.0)
	
	# Smoothly interpolate the blend position using expDecay
	var current_blend = ANIMATIONTREE["parameters/StateMachine/idle_walk/blend_position"]
	var new_blend = PLAYER.expDecay(current_blend, target_blend, ANIMATION_BLEND_SPEED, delta)
	ANIMATIONTREE["parameters/StateMachine/idle_walk/blend_position"] = new_blend
	
	# Calculate target animation speed
	var target_anim_speed = 1.0
	if round(horizontal_velocity) > 7.0:
		var speed_factor = clamp((horizontal_velocity - 7.0) / (PLAYER.max_speed - 7.0), 0.0, 1.0)
		target_anim_speed = 1.0 + (TOP_ANIM_SPEED - 1.0) * speed_factor
	
	# Smoothly interpolate the animation speed using expDecay
	var current_speed = ANIMATIONTREE["parameters/animation_speed/scale"]
	var new_speed = PLAYER.expDecay(current_speed, target_anim_speed, ANIMATION_BLEND_SPEED, delta)
	ANIMATIONTREE["parameters/animation_speed/scale"] = new_speed
