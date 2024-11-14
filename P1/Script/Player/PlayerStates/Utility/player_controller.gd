class_name Player
extends CharacterBody3D

# TODO:
# When looking diagnoally, character sometimes turns directly right or left when I stop.
# Seems to have been fixed somewhat by moving process input into _process

# TODO: fix not wall sliding with mesh direction is like perfectly alligned to a cardinal position

# TODO: Replace lerp with expdecay

# TODO: Groundstates that extends states

# TODO: AirStates that Extends states

# TODO: Move some functions over to States, some to groundstates, some to air states

# TODO: Variable to just hold onto the horizonal components of the velocity for calculations

# TODO: Better Camera

# TODO: Seperate node that controls animation blending.

# TODO: Now make it so spring arm does not clip with platforms



# TODO: Get closer with wall attach point

# TODO: Create a planar velocity function

# ########################### #

# Related to movement
@export_group("Player Movement")
@export_subgroup("Gravity")
# Gravity stuff
@export var jump_height : float = 3.0 # In pixels
@export var jump_time_to_peak : float = 0.45 # In seconds
@export var jump_time_to_descent : float = 0.4 # In Seconds

# ########################### #

@export_group("Util Nodes")
# For mesh rotation
@export var MESH_ROOT : Node3D

# Dash target for dashplayer state
@export var DASH_TARGET : Node3D

# Access to our state machine
@export var STATE_MACHINE : StateMachine

# For playing animations based on state!
@export var ANIMATIONTREE : AnimationTree

# For playing animations based on state!
@export var ANIMATIONPLAYER : AnimationPlayer

# Jumper buffer stuff
@export var JUMP_BUFFER_TIMER : Timer

# Raycasts for going up stairs and slopes
@export var STAIRS_AHEAD : RayCast3D

# Raycasts for going down stairs and slopes
@export var STAIRS_BELOW : RayCast3D

# Raycasts for the floor
@export var FLOOR_RAYCAST : RayCast3D

# Raycasts for the Wall
@export var WALL_RAYCAST : RayCast3D
# Check to see if we can stick to the wall without collision
@export var WALL_SLIDE_CHECKER : RayCast3D
# To host the raycast
@export var COLLIDER : CollisionShape3D

# ########################### #
var target_rotation : float = 0.0
var movement_direction : Vector3
# ########################### #

# State variables
var is_jump_released : bool = false
var is_double_jumped : bool = false
var is_double_jump_released : bool = false

var jump_hold_active : bool = false
var jump_buffer_active  : bool = false
var jump_hold_duration : float = 0.0

var hold_factor : float = 0.0
var max_jump_hold_time : float = 0.0

var is_sliding : bool = false
var is_dashed : bool = false
var air_dashing : bool = false
var slope_acceleration : float = 1.0

var is_wall_slide : bool = false
var is_wall_jump : bool = false
var previous_wall : Dictionary

var _snapped_to_stairs_last_frame : bool = false
var _last_frame_was_on_floor = -INF

# ########################### #

# FOR HORRIZONAL ROTATION
#@onready var yaw_node = %cam_yaw

# Gravity stuff
# How fast we move upwards
@onready var jump_velocity : float = (2.0 * jump_height) / jump_time_to_peak
# Gravity going up
@onready var jump_gravity : float = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
# Gravity going down
@onready var fall_gravity : float = (-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)

# #################################### ## #################################### ## #################################### ## #################################### ## #################################### #	
	
# Passing our unhandled input to the state
func _unhandled_input(event):
	STATE_MACHINE.handle_input(event)#
	
	# Quits the game
	if event.is_action_pressed("quit"):
		get_tree().quit()
		
func _process(delta):
	# Aligning model for floor normal when sliding
	update_normal_rotation(false if _snapped_to_stairs_last_frame else true)
	
	# For rotating the mesh
	if is_movement_ongoing():
		rotate_mesh(delta)
	
	# For interpolation, for model
	_slide_model_smooth_back_to_origin(delta)
	
@onready var velocity_cast = %VelocityCast
var speed_2D : Vector2
func _physics_process(delta):
	if is_on_floor(): 
		_last_frame_was_on_floor = Engine.get_physics_frames()
	speed_2D = Vector2(velocity.x, velocity.z)
	velocity_cast.target_position = Vector3(speed_2D.x, 0, speed_2D.y)
	
# ########################################################################################################## ## ########################################################################################################## #

# The velocity threshold below which the character will come to a complete stop.
# If the velocity drops below this value, the deceleration function will set the velocity to zero.
# removed 4
const EPSILON : float = 0.0000001
const OVER_VELOCITY_TOLERANCE : float = 1.01

@export_group("Character Movement Settings: General")
## Acceleration (rate of change of velocity) value for the character.
@export var acceleration : float = 20.0

## The maximum ground speed when walking, lateral speed when falling.
@export var max_speed : float = 60.0  

## Scale used to multiply actual value of friction used when deceleration.
@export var friction_scale : float = 1.0

## true, friction will be used to slow the character to a stop (when there is no Acceleration).
## false, deceleration uses turn_friction (when walking), multiplied by friction_scale.
@export var use_seperate_friction : bool = true

@export_group("Character Movement Settings: Grounded")

## Movement control. Higher values allow faster changes in direction, lower values allow slower changes in direction.
## If seperate friction is false, also affects how quickly we decelerate
@export var turn_friction : float = 8.0

## Friction (drag) coefficient applied when decelerating (when there is no movement input, or if character is exceeding max speed) while on the ground.
@export var drag_friction : float = 0.0

## Deceleration when walking and not applying acceleration (over speed cap or not moving). This is a constant opposing force that directly lowers velocity by a constant value.
@export var deceleration : float = 11.48

## Deceleration when not applying acceleration not moving. This is a constant opposing force that directly lowers velocity by a constant value.
@export var deceleration_no_movement : float = 27.48

@export_group("Character Movement Settings: Airborne")

## Amount of movement control we have while in air.
## Lower values gives less control, higher values more control.
@export var player_air_control : float = 1.0

## Deceleration when falling and not applying acceleration (over speed cap or not moving). This is a constant opposing force that directly lowers velocity by a constant value.
@export var air_deceleration : float = 0

## Friction (drag) coefficient applied when decelerating (when there is no movement input, or if character is exceeding max speed) while in the air.
@export var air_drag_friction : float = 0.0

## Boosting air control if velocity's magnitude is below a certain value
## Value of 0 cancels the boost effect entirely.
@export var player_air_control_boost : float = 2

## Boost threshold, if below it, multiply air control by player_air_control_boost
## Value of 0 cancels the boost effect entirely.
@export var player_air_control_boost_threshold : float = 0

@export_subgroup("Airborne Constraints")
## Aerial soft speed cap. If we are over this, we reduce our speed down to it.
@export var aerial_soft_speed_cap : float = 30.0

## Aerial soft speed cap tolerance.
@export var aerial_soft_speed_cap_tolerance : float = 1.02

## Controls how fast we can ascend
@export var max_ascension_speed : float = 5000

## Controls how fast we fall
@export var max_fall_speed : float = -50.0

## Max number of double jumps we can do
@export var max_double_jump_count : int = 1  # Number of jumps allowed (including the initial jump)

var remaining_jumps : int = max_double_jump_count  # Tracks the number of jumps left

var double_jump_boost_applied : bool = false

# ########################################################################################################## #
# Check if we are over max speed
func exceeds_max_speed(max_speed: float) -> bool:
	# Ensure it is non-negative
	max_speed = max(0.0, max_speed)
	
	# Get max speed and square it for comparison purposes.
	# OVER_VELOCITY_TOLERANCE: 1 Percent error tolerance
	# Returns true or false depending on if we are over max
	return velocity.length_squared() > max_speed * max_speed * OVER_VELOCITY_TOLERANCE
	
# Basically multiplying acceleration by a constant
func apply_air_control(air_control : float) -> float:
	if air_control != 0.0:
		# Could have linear interpolation here, prob best to leave it alone though
		if player_air_control_boost > 0.0 and Vector2(velocity.x, velocity.z).length_squared() < (player_air_control_boost_threshold * player_air_control_boost_threshold):
			air_control = min(1.0, player_air_control_boost * air_control)
			
	if movement_direction.length_squared() > 0.0:
		return min(air_control * acceleration, acceleration)
	return 0.0
	
# Applying friction on double jump
func double_jump_friction(old_velocity: Vector3, new_direction: Vector3) -> Vector3:
	if Vector2(old_velocity.x, old_velocity.z).is_zero_approx():
		return Vector3.ZERO  # Return zero vector if input velocity is zero
		
	# Calculate the magnitude (speed) of the old velocity
	var old_speed_squared = old_velocity.length_squared()
	var old_speed = sqrt(old_speed_squared)
	
	# Check for overspeed condition
	var overspeed_threshold_squared = aerial_soft_speed_cap * aerial_soft_speed_cap * aerial_soft_speed_cap_tolerance
	var is_overspeeding = old_speed_squared > overspeed_threshold_squared
	
	# If there's no input direction, reduce speed by 65% in the new direction
	if movement_direction.is_zero_approx():
		return new_direction * (old_speed * 0.35)
	
	# Calculate the angle between old and new directions
	var direction_change = old_velocity.normalized().dot(new_direction)
	var angle_change = acos(clamp(direction_change, -1.0, 1.0))
	
	# Define the angle threshold (in radians) where we start applying more friction
	var threshold_angle = deg_to_rad(45.0)  # 45 degrees
	
	# Calculate the desired speed based on the angle change
	var desired_speed: float
	if angle_change <= threshold_angle:
		if is_overspeeding:
			return new_direction * aerial_soft_speed_cap
		desired_speed = old_speed
	else:
		if is_overspeeding:
			return new_direction * (old_speed * 0.35)
		
		# Calculate speed reduction for larger angles
		var angle_factor = (angle_change - threshold_angle) / (PI - threshold_angle)
		desired_speed = old_speed * (1.0 - angle_factor * 0.6)
	
	return new_direction * desired_speed
	
# Code for our double jump	
func double_jump_direction_change():
	
	# If we use up all our jumps, double jump boosts have all been applied
	if remaining_jumps == 0:
		double_jump_boost_applied = true
	
	# If we have double jumps.
	if remaining_jumps > 0 and not double_jump_boost_applied:
		# Cache y component
		var y_velocity_cache : float = velocity.y
		
		# Zero out the y component of the velocity so it doesn't interfere with calculations.
		velocity.y = 0
		
		var new_direction : Vector3 = movement_direction if !movement_direction.is_zero_approx() else get_player_direction()
		
		velocity = double_jump_friction(velocity, new_direction)
		
		velocity.y = y_velocity_cache
		
		if !Vector2(velocity.x, velocity.z).is_zero_approx():
			MESH_ROOT.rotation.y = atan2(velocity.x, velocity.z)
# ########################################################################################################## #

@onready var slope_cast: RayCast3D = %SlopeCast
# TODO: Improve later
func handle_sliding(delta : float, max_slope_acceleration : float = 32, slide_turn_friction : float = .55, deceleration : float = 8.0):
	# So we don't affect our y velocity
	var temp_y : float = velocity.y
	velocity.y = 0
	
	# Get floor normal
	var floor_normal : Vector3 = get_floor_normal()
	# Get the direction of the slope, this will tell us how far away it is
	var slide_direction : Vector3 = get_normal_direction(floor_normal)
	# Returns the steepness of the ground. 0 is flat. 1 is completely vertical
	var slope_steepness : float = calculate_slope_steepness(floor_normal)
	# Scaling acceleration by slope steepness
	var slope_accel : float = slope_steepness * max_slope_acceleration
	
	# Direction of acceleration
	# velocity + (slide_direction * slope_accel) * delta
	var accel_dir : Vector3 = slide_direction * slope_accel
	
	# Apply acceleration
	velocity = velocity +  accel_dir * delta
	
	# Apply deceleration
	velocity = velocity.move_toward(Vector3.ZERO, deceleration * delta)
	
	if velocity.length_squared() <= EPSILON * EPSILON:
		velocity = Vector3.ZERO
	
	slope_cast.target_position = slide_direction
	
	# Setting temp acceleration so I can change and whatnot
	var temp_acceleration : float = acceleration
	acceleration = 0
	
	# I don't intend for there to be a speed cap on sliding, will prob change later but for now this is good.
	max_speed = INF
	
	handle_velocity_physics(delta, slide_turn_friction, false, 0, movement_direction)

	acceleration = temp_acceleration
	
	# So we don't affect our y velocity
	velocity.y = temp_y

func handle_airborne_movement(delta : float, air_control : float = player_air_control):
	var temp_acceleration : float = acceleration
	acceleration = apply_air_control(air_control)
	handle_velocity_physics(delta, air_drag_friction, false, air_deceleration, movement_direction)
	acceleration = temp_acceleration

# This function calculates and updates the character's velocity based on several factors including friction,
# fluid resistance, deceleration, and acceleration.
# Make it so it only affects horizonal components
# Add a boolean or something so we can set acceleration for either land or air
func handle_velocity_physics(delta: float, friction: float, is_fluid: bool, velocity_deceleration: float, movement_direction : Vector3) -> void:
	
	movement_direction = movement_direction.normalized()
	double_jump_boost_applied = false
	
	# Cache y component
	var y_velocity_cache : float = velocity.y
	
	# Zero out the y component of the velocity so it doesn't interfere with calculations.
	velocity.y = 0
	
	# Ensure that friction is non-negative.
	friction = max(0.0, friction)
	
	# Determine if there's no acceleration and if the velocity exceeds the maximum speed.
	var is_zero_acceleration : bool = movement_direction.is_zero_approx()
	var is_velocity_over_max : bool = exceeds_max_speed(max_speed)
	
	# Apply friction or deceleration if there's no acceleration or the character is moving too fast.
	# This is part of the code responsible for "inertia drifting"
	if is_zero_acceleration or is_velocity_over_max:
		
		# I want to have different deceleration speeds for when I am walking or not moving
		velocity_deceleration = velocity_deceleration if !is_zero_acceleration or is_dashed or is_sliding else deceleration_no_movement
		
		# Store the current velocity for later comparison.
		var previous_velocity : Vector3 = velocity
		
		# Select the appropriate friction value for deceleration.
		# If separate friction is enabled, use it friction; otherwise, use turn friction.
		var friction_selection : float = drag_friction if use_seperate_friction else friction
		var actual_friction : float = friction_selection * friction_scale
		
		# Applying forces to the character's velocity based on friction and deceleration values.
		if !velocity.is_zero_approx():
			
			# Make sure these values are non-negative
			actual_friction = max(0.0, actual_friction)
			velocity_deceleration = max(0.0, velocity_deceleration)
			
			if !is_zero_approx(actual_friction) or !is_zero_approx(velocity_deceleration):
				
				# Store another copy of the current velocity for later comparison.
				var cached_velocity : Vector3 = velocity
				
				# Friction scales with velocity
				# Deceleration is a constant force
				velocity = velocity + ((-actual_friction) * velocity + (-velocity_deceleration * velocity.normalized())) * delta
					
				# Prevent the character from reversing direction by setting velocity to zero if the new velocity points opposite the old velocity.
				# Clamp the velocity to zero if it's very small
				if velocity.dot(cached_velocity) <= 0.0 or velocity.length_squared() <= EPSILON:
					velocity = Vector3.ZERO
					
		# Logic to ensure we stay at the max speed after exceeding it, allows for smooth transition
		# If we exceed movement speed, then go below it (due to deceleration function above), whilst going in the same general direction
		# Clamp the velocity to max speed to prevent it from dropping below it.
		if is_velocity_over_max and velocity.length_squared() < (max_speed * max_speed) and movement_direction.dot(previous_velocity) > 0.0:
			velocity = previous_velocity.normalized() * max_speed
			
	# This is where ground friction affects our ability to change directions
	# If there's acceleration, adjust velocity based on the direction and friction.
	elif not is_zero_acceleration:
		# Using friction to control our ability to change direction
		
		# Theory: 
		# movement_direction * velocity.length: vector that points in the direction the character is trying to move scaled to the current speed of the character
		
		# velocity - movement_direction * velocity.length(): subtract the ideal velocity from the current velocity. 
		# This gives a vector representing the difference between where the character is currently moving and where it should be moving.
		# If the current velocity is aligned with movement_direction, this difference will be small. If they're in opposite directions, this difference will be large
		# So we affect both mangitude and direction
		
		# (velocity - movement_direction * velocity.length()) * min(delta * friction, 1.0):
		# The difference vector is then scaled by min(delta * friction, 1.0)
		# delta * friction determines how much influence friction has over time (delta). 
		# The min() function ensures that this scaling factor does not exceed 1.0, preventing overcorrection.
		# This scaling controls how much the character's velocity should be adjusted to move closer to the desired direction
		# min(delta * friction, 1.0) affects only the magnitude of the scaled difference vector, with a value of 1 taking the entirety of the scaled difference
		# Values smaller than one only taking their respective parts
		
		# velocity - (scaled_difference_vector):
		# Finally, the scaled difference vector is subtracted from the current velocity.
		# This subtraction moves the current velocity closer to the desired movement direction, 
		# effectively simulating the effect of friction in helping the character gradually turn or adjust its path.
		velocity = velocity - (velocity - movement_direction * velocity.length()) * min(delta * friction, 1.0)
		
	# Apply fluid friction if the character is moving through a fluid medium (like water).
	# Using min to prevent extrapolation
	if is_fluid:
		velocity = velocity * (1.0 - min(friction * delta, 1.0))
		
	# If there's acceleration, update the velocity accordingly.
	if not is_zero_acceleration:
		
		# Determine the new maximum speed to apply, considering the current velocity and max speed.
		var speed_cap : float = velocity.length() if exceeds_max_speed(max_speed) else max_speed
		
		# Calculate acceleration based on the current direction.
		# acceleration = movement_direction * acceleration
		# Update the velocity by applying acceleration over time (delta).
		# Acceleration also affects our ability to change directions
		velocity = velocity + (movement_direction * acceleration) * delta
		
		# Ensure the velocity doesn't exceed the calculated maximum speed.
		velocity = velocity.limit_length(speed_cap)
		
	velocity.y = y_velocity_cache

# ########################################################################################################## ## ########################################################################################################## #
@onready var player_camera: Node3D = %PlayerCamera

# Wall JUMP
func update_input():
	if is_wall_slide == false:
		
		# Finding player's desired direction
		# Holding right and left = no movement
		# Left +1, Right -1
		movement_direction.x = -Input.get_action_strength("left") + Input.get_action_strength("right")
		
		# Holding up and down = no movement
		# Up +1, Down -1
		movement_direction.z = -Input.get_action_strength("up") + Input.get_action_strength("down")
		
		movement_direction = movement_direction.normalized()
		
		# Updating our movement direction for camera control, done in _process() for more responsiveness
		#movement_direction = movement_direction.rotated(Vector3.UP, yaw_node.rotation.y)
		movement_direction = movement_direction.rotated(Vector3.UP, deg_to_rad(player_camera._player_pcam.get_third_person_rotation_degrees().y))
	
# #################################### ## #################################### ## #################################### ## #################################### #

func update_velocity(delta) -> void:
	if not _snap_up_stairs_check(delta):
		move_and_slide()
		_snap_down_to_stairs_check()
		
# #################################### #
# Stair stuff
# Saves the model position for smoothing
var max_offset : float = 0.30
var _saved_model_global_pos = null


const MAX_STEP_HEIGHT : float = 0.5

func _save_model_pos_for_smoothing():
	# If null, we set it to position of mesh root
	if _saved_model_global_pos == null:
		_saved_model_global_pos = MESH_ROOT.global_position

func _slide_model_smooth_back_to_origin(delta):
	if _saved_model_global_pos == null:
		return

	# Store current global position with high precision
	var current_global_pos = MESH_ROOT.global_transform.origin

	# Calculate the desired Y offset in global space
	var desired_global_y = _saved_model_global_pos.y
	var global_y_offset = desired_global_y - current_global_pos.y

	# Convert the global Y offset to local space
	var local_y_offset = MESH_ROOT.global_transform.basis.inverse() * Vector3(0, global_y_offset, 0)

	# Apply the local Y offset
	MESH_ROOT.position.y += local_y_offset.y

	# Clamp the local Y position
	MESH_ROOT.position.y = clampf(MESH_ROOT.position.y, -max_offset, max_offset)

	# Calculate smooth speed based on max move speed
	var base_smooth_speed = 30.0
	var max_move_speed = 7.0  # Your current max speed
	var smooth_speed = base_smooth_speed * (velocity.length() / max_move_speed)
	smooth_speed = clampf(smooth_speed, base_smooth_speed * 0.5, base_smooth_speed * 1.5)

	# Use exponential decay for smooth interpolation
	MESH_ROOT.position.y = expDecay(MESH_ROOT.position.y, 0.0, smooth_speed, delta)

	# Update saved global position
	_saved_model_global_pos = MESH_ROOT.global_transform.origin

	# Reset if we've reached very close to the origin
	if abs(MESH_ROOT.position.y) < 0.01:  # Increased precision
		MESH_ROOT.position.y = 0
		_saved_model_global_pos = null  # Stop smoothing

	# Ensure X and Z components of global position haven't changed
	MESH_ROOT.transform.origin.x = 0
	MESH_ROOT.transform.origin.z = 0
	
# Function to check and snap the character down to stairs if needed
func _snap_down_to_stairs_check() -> void:
	# Initialize a variable to track if snapping occurred
	var did_snap : bool = false
	# Modified slightly from tutorial. I don't notice any visual difference but I think this is correct.
	# Since it is called after move_and_slide, _last_frame_was_on_floor should still be current frame number.
	# After move_and_slide off top of stairs, on floor should then be false. Update raycast incase it's not already.
	
	# Update the raycast to ensure it has the latest collision information
	STAIRS_BELOW.force_raycast_update()
	
	# Check if there is a floor below and it's not too steep
	var floor_below : bool = STAIRS_BELOW.is_colliding() and not is_surface_too_steep(STAIRS_BELOW.get_collision_normal())
	
	# Check if the character was on the floor in the last frame
	var was_on_floor_last_frame : bool = Engine.get_physics_frames() == _last_frame_was_on_floor
	
	# Conditions to snap down to the stairs:
	# 1. The character is not currently on the floor.
	# 2. The character is falling (velocity.y <= 0.0).
	# 3. The character was on the floor in the last frame or snapped to stairs in the last frame.
	# 4. There is a floor below.
	if not is_on_floor() and velocity.y <= 0.0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		# Create a new collision result object
		var body_test_result = KinematicCollision3D.new()
		# Test moving the character down by MAX_STEP_HEIGHT and check for collision
		if test_move(global_transform, Vector3(0,-MAX_STEP_HEIGHT,0), body_test_result):
			
			_save_model_pos_for_smoothing()
			
			# Get the travel distance of the collision and update the character's y-position
			var translate_y = body_test_result.get_travel().y
			position.y += translate_y
			
			# Apply floor snapping to ensure the character is properly aligned with the floor
			apply_floor_snap()
			
			# Set did_snap to true indicating that snapping occurred
			did_snap = true
			
	# Set did_snap to true indicating that snapping occurred
	_snapped_to_stairs_last_frame = did_snap

# Function to check and snap the character up to stairs if needed
func _snap_up_stairs_check(delta) -> bool:
	if is_sliding:
		var expected_move_motion = velocity * Vector3(1,0,1) * delta
		var step_pos_with_clearance = global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
		var down_check_result = KinematicCollision3D.new()
		if test_move(step_pos_with_clearance,Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result) and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D")):
			#var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - global_position).y
			# Update the raycast position ahead to check for further collisions
			STAIRS_AHEAD.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
					
			# Update the raycast position ahead to check for further collisions
			STAIRS_AHEAD.force_raycast_update()
		return false
	
	# If the character is not on the floor and didn't snap to stairs in the last frame, return false
	if not is_on_floor() and not _snapped_to_stairs_last_frame:
		return false
	
	# Don't snap up stairs if the character is jumping or not moving horizontally
	if velocity.y > 0 or (velocity * Vector3(1,0,1)).length() == 0: 
		return false
		
	# Calculate the expected motion based on current velocity and delta time
	var expected_move_motion = velocity * Vector3(1,0,1) * delta
	
	# Determine the position slightly above the expected move position to check for stairs
	var step_pos_with_clearance = global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	# We give some clearance above to ensure there's ample room for the player.
	# If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	# along with their intended motion forward.
	
	# Create a new collision result object
	var down_check_result = KinematicCollision3D.new()
	
	# Test moving the character down by MAX_STEP_HEIGHT * 2 from the clearance position and check for collision
	if test_move(step_pos_with_clearance,Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result) and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D")):
		# Calculate the height of the step
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - global_position).y
		
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		
		# Conditions to ensure the step is valid:
		# 1. The step height should be less than or equal to MAX_STEP_HEIGHT.
		# 2. The step height should be greater than 0.01 to avoid small glitches.
		# 3. The collision point's y-distance should be within MAX_STEP_HEIGHT.
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - global_position).y > MAX_STEP_HEIGHT:
			return false
			
		# Update the raycast position ahead to check for further collisions
		STAIRS_AHEAD.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		
		# Update the raycast position ahead to check for further collisions
		STAIRS_AHEAD.force_raycast_update()
		
		# Check if the raycast ahead is colliding and the surface is not too steep
		if (STAIRS_AHEAD.is_colliding() and not is_surface_too_steep(STAIRS_AHEAD.get_collision_normal())):
			_save_model_pos_for_smoothing()
			
			# Update the character's global position based on the collision travel
			global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			
			# Apply floor snapping to ensure the character is properly aligned with the floor
			apply_floor_snap()
			
			# Update the state variable to track snapping to stairs and return true
			_snapped_to_stairs_last_frame = true
			
			return true
	
	# Return false if snapping to stairs didn't occur
	return false

# #################################### ## #################################### ## #################################### ## #################################### ## #################################### #
# Wall slide stuff
const max_attempts : int = 30
const horizontal_shift_amount: float = 0.001

func is_wall_slideable(delta) -> Dictionary:
	# Update raycast
	WALL_RAYCAST.force_raycast_update()
	# Get wall normal
	var wall_normal : Vector3 = WALL_RAYCAST.get_collision_normal() if WALL_RAYCAST.is_colliding() else Vector3.ZERO
	# If it is zero, exit early
	if wall_normal == Vector3.ZERO:
		return {"cam_slide": false}
	# Move in the direction of velocity
	var expected_move_motion : Vector3 = velocity * Vector3(1,0,1) * delta
	# Our initial position but shifted backwards a bit
	var expected_move_motion_with_clearance : Transform3D = global_transform.translated(expected_move_motion + Vector3(wall_normal.normalized().x * 0.06, 0, wall_normal.normalized().z * 0.06))
	# Position we want to travel to
	var target_position : Vector3 = WALL_RAYCAST.get_collision_point()
	# Starting from
	var initial_transform : Transform3D = expected_move_motion_with_clearance
	# For loop
	for attempt in range(max_attempts):
		# Vector along which we will shift our starting position
		var shift_direction : Vector3 = wall_normal.cross(Vector3.UP).normalized()
		# Determine if we should shift left or right using the dot product
		var motion_vector : Vector3 = target_position - initial_transform.origin
		var dot_product : float = motion_vector.dot(shift_direction)
		if dot_product < 0:
			shift_direction = -shift_direction  # Reverse direction if dot product is negative
		# The vector that will be used to shift our starting position
		var horizontal_shift_vector : Vector3 = shift_direction * horizontal_shift_amount * attempt
		# Adjust initial position horizontally based on wall normal and attempt number
		initial_transform.origin += horizontal_shift_vector
		# Calculate motion vector based on the updated starting position
		#var motion : Vector3 = target_position - initial_transform.origin
		# Where the raycast will start. Where it will originate. (From)
		WALL_SLIDE_CHECKER.global_position = initial_transform.origin
		# The ending point of the ray. Where it will point. (To)
		# Negating wall normal so the ray points at the wall.
		# Also setting length of raycast
		WALL_SLIDE_CHECKER.target_position = -wall_normal * WALL_RAYCAST.target_position.length()
		WALL_SLIDE_CHECKER.global_position.y = WALL_RAYCAST.global_position.y
		WALL_SLIDE_CHECKER.force_raycast_update()
		var wall_slide_check_normal = WALL_SLIDE_CHECKER.get_collision_normal() if WALL_SLIDE_CHECKER.is_colliding() else Vector3.ZERO
		# If collision detected by the raycast, the wall is slideable
		if wall_slide_check_normal != Vector3.ZERO:
			# Check if it's safe to teleport
			if find_safe_position(target_position, wall_normal):
				return {
					"cam_slide": true, 
					"wall_normal": wall_normal, 
					"target_position": initial_transform.origin, 
					"prev_surface": {
						"prev_rid": WALL_SLIDE_CHECKER.get_collider_rid(), 
						"prev_normal": wall_slide_check_normal
					}
				}
	return {"cam_slide": false}
	
@onready var walking_collision_shape: CollisionShape3D = $WalkingCollisionShape3D
@onready var wall_safe_check: RayCast3D = $WallSafeCheck

func find_safe_position(target_position: Vector3, wall_normal: Vector3) -> bool:
	# Get the current physics space state
	var space_state : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	# Calculate the adjusted position
	var adjusted_position : Vector3 = target_position + wall_normal * (walking_collision_shape.shape.radius + 0.01)
	
	# Check for intersections at the adjusted position
	var params : PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.set_shape(walking_collision_shape.shape)
	params.set_transform(Transform3D(Basis(), adjusted_position) * walking_collision_shape.transform)
	params.set_collision_mask(collision_mask)
	params.set_exclude([self])
	
	# No intersections at this spot, safe to teleport
	if space_state.intersect_shape(params).is_empty():
		return true
	
	# Just check from our current position
	wall_safe_check.target_position = -wall_normal * WALL_RAYCAST.target_position.length()
	wall_safe_check.global_position.y = WALL_RAYCAST.global_position.y
	wall_safe_check.force_raycast_update()
	var wall_safe_check_normal = wall_safe_check.get_collision_normal() if wall_safe_check.is_colliding() else Vector3.ZERO
	
	# Ray does not hit wall from our current position
	if wall_safe_check_normal == Vector3.ZERO:
		return false
	
	# Ray hits wall from our current position
	return true
	
# #################################### ## #################################### ## #################################### ## #################################### ## #################################### #
# Jump function
# Gravity needs to reset on next jump
# gravity being applied on jump?
var just_jumped : bool = false

# We can always have a default fall gravity
func jump(new_jump_height: float = jump_height, new_jump_time_to_peak: float = jump_time_to_peak, new_jump_time_to_descent: float = jump_time_to_descent) -> void:
	# Update jump parameters
	jump_height = new_jump_height
	jump_time_to_peak = new_jump_time_to_peak
	jump_time_to_descent = new_jump_time_to_descent
	
	# Calculate jump physics
	jump_velocity = (2.0 * jump_height) / jump_time_to_peak
	jump_gravity = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = (-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)
	
	# Max hold time should be jump time to peak
	max_jump_hold_time = jump_time_to_peak
	
	# Apply jump velocity
	velocity.y = jump_velocity
	
	# Reset jump-related variables
	jump_buffer_active = false
	JUMP_BUFFER_TIMER.stop()
	
	jump_hold_active = true
	jump_hold_duration = 0.0
	is_jump_released = false
	
	just_jumped = true
	
# Gravity update function
# It is not jump hold active, it is not jump hold duration, not just_jumped
func update_gravity(delta: float) -> void:
	if not is_on_floor():
		# Apply gravity
		velocity.y += get_variable_gravity() * delta
		# Clamp fall speed
		velocity.y = clamp(velocity.y, max_fall_speed, max_ascension_speed)

# Variable gravity calculation
var outside_force : bool = false
const DEFAULT_FALL_GRAVITY : float = -47.5
const DEFAULT_DASH_GRAVITY : float = -37.5
func get_variable_gravity() -> float:
	# So our gravity resets to 0 when we double jump
	if just_jumped:
		just_jumped = false
		return 0
	
	if velocity.y > 0.0 and not air_dashing and not is_dashed:
		if jump_hold_active:
			return jump_gravity
		else:
			# Ensure we use regular fall grav if something else pushes us into the air
			if outside_force:
				return DEFAULT_FALL_GRAVITY
				
			# Fast fall when we let go of jump
			return jump_gravity * 2 if (velocity.y - jump_gravity * 2) > 0.0 else jump_gravity - abs(velocity.y - jump_gravity * 2)
	else:
		# Falling phase or jump button released
		if air_dashing:
			return DEFAULT_DASH_GRAVITY
			
		return DEFAULT_FALL_GRAVITY
		
func _on_jump_buffer_timeout():
	# Reset jump buffer state when the timer runs out
	jump_buffer_active  = false
	
# #################################### ## #################################### ## #################################### ## #################################### ## #################################### #
	
# Mesh rotation code in here. This should make rotating the model as smooth as possible
# Rotating mesh to face the direction of movement
# Place after move and slide otherwise your character will turn around cause move and slide keeps updating velocity
# atan2(y, x)

# The atan2 function is a mathematical function that computes the angle (in radians) 
# between the positive x-axis and the point given by the coordinates (x, y)
# Takes two arguments (y, x) and considers their signs to determine the correct quadrant of the angle.
# tangent is the slope formed by the x(cos) and y(sin) components hence why tan(theta) = sin/cos aka y/x aka rise over run
# Rotate the model as long as we are holding down movement
# Wall JUMP
@export_group("Mesh Settings")
@export_range(1, 20, 0.001) var MESH_ROTATION_SPEED : float = 8.0
func rotate_mesh(delta: float) -> void:
	# Checking to see if we are not in sliding or air dash state
	if is_wall_jump == false:
		if is_sliding == false and air_dashing == false:
			target_rotation = atan2(movement_direction.x, movement_direction.z)
			if !is_wall_slide and !is_wall_jump:
				MESH_ROOT.rotation.y = lerp_angle(MESH_ROOT.rotation.y, target_rotation, MESH_ROTATION_SPEED * delta)
		# If we are in either of those states, we rotates towards the direction of the velocity, giving the steering visual effect
		else:
			target_rotation = atan2(velocity.x, velocity.z)
			MESH_ROOT.rotation.y = lerp_angle(MESH_ROOT.rotation.y, target_rotation, MESH_ROTATION_SPEED *  delta)
			
	COLLIDER.rotation.y = MESH_ROOT.rotation.y
	
@export_group("Interpolation Values")
@export_range(0.01, 0.1, 0.001) var TRANSFORM_INTERP : float = 0.09

func update_normal_rotation(from_ray : bool = true) -> void:
	# Check if we're moving at all
	if velocity.length_squared() < (0.1 * 0.1):
		return

	# Calculate floor normal rotation
	var target_transform : Transform3D
	if (is_on_floor() or STAIRS_AHEAD.is_colliding()) and is_sliding:
		FLOOR_RAYCAST.force_raycast_update()
		
		# Get floor normal
		var normal = FLOOR_RAYCAST.get_collision_normal() if from_ray && FLOOR_RAYCAST else get_floor_normal()
		
		# Aligning with noraml
		target_transform = align_to_normal(MESH_ROOT.global_transform, normal)
	else:
		# Align upwards if we are in the air
		target_transform = align_to_normal(MESH_ROOT.global_transform, Vector3.UP)
	
	# Interpolate to normal
	MESH_ROOT.global_transform = MESH_ROOT.global_transform.interpolate_with(target_transform, TRANSFORM_INTERP)

func align_to_normal(xform : Transform3D, normal : Vector3) -> Transform3D:
	# Step 1: Set the basis.y (the up vector) of the transform to the normal
	xform.basis.y = normal
	# Step 2: Calculate the new x-axis by taking the cross product of the normal and the current z-axis
	xform.basis.x = normal.cross(xform.basis.z)
	# Step 3: Calculate the new z-axis by taking the cross product of the new x-axis and the normal
	xform.basis.z = xform.basis.x.cross(normal)
	# Step 4: Orthonormalize the basis to ensure all axes are orthogonal and unit length
	xform.basis = xform.basis.orthonormalized()
	# Step 5: Return the modified transform
	return xform


func is_movement_ongoing() -> bool:
	var movement : bool = abs(movement_direction.x) > 0 or abs(movement_direction.z) > 0
	return movement

func get_movement_direction() -> Vector3:
	return movement_direction

func get_mesh_wall_angle() -> float:
	return rad_to_deg(acos(MESH_ROOT.basis.z.dot(-WALL_RAYCAST.get_collision_normal())))
	
# Basically lerp but better without the infinite steps in finite time deal
## (Start, Destination, Rate, Timestep)
func expDecay(a: Variant, b: Variant, decay: float, delta: float) -> Variant:
	return b + (a - b) * exp(-decay * delta)
	
# Function to check if a surface is too steep based on its normal		
func is_surface_too_steep(normal: Vector3) -> bool:
	# Compare the angle between the normal and the UP vector to the maximum allowable floor angle
	return normal.angle_to(Vector3.UP) > floor_max_angle

func get_player_direction() -> Vector3:
	var player_dir : Vector3 = -(MESH_ROOT.global_transform.origin - DASH_TARGET.global_transform.origin)
	player_dir.y = 0
	return player_dir.normalized()
	
## Gets the direction of a normal
func get_normal_direction(normal : Vector3) -> Vector3:
	var r = normal.cross(Vector3.DOWN)
	r = r.cross(normal)
	return Vector3(r.x, 0, r.z)
	
func calculate_2d_dot_product(normal1, normal2):
	return Vector2(normal1.x, normal1.z).normalized().dot(Vector2(normal2.x, normal2.z).normalized())

func calculate_slope_steepness(floor_normal: Vector3) -> float:
	# This gives us the angle in radians
	var angle = acos(floor_normal.dot(Vector3.UP))
	
	# Clamp the angle to our maximum floor angle
	angle = min(angle, floor_max_angle)
	
	# Scale the result from 0 (flat) to 1 (max angle)
	return angle / floor_max_angle
# #################################### ## #################################### ## #################################### ## #################################### ## #################################### #
# Audio/Animation Stuff

@onready var dust_manager: Node3D = %DustManager
@onready var bootsteps_sfx = %bootsteps_sfx
func _play_bootstep_sound() -> void:
	if is_movement_ongoing() and int(velocity.length_squared()) > 0:
		bootsteps_sfx.play()
		dust_manager.kickup_effect()
	
@onready var jump_sfx = %jump_sfx
func _play_jump() -> void:
	#if is_on_floor():
	jump_sfx.play()
	
@onready var land_dust_manager: Node3D = %LandDustManager
@onready var land_sfx = %land_sfx
func _play_land() -> void:
	land_sfx.play()
	land_dust_manager.kickup_effect()

@onready var dash_sfx = %dash_sfx
func _play_dash() -> void:
	dash_sfx.play()
	
func insert_call_method_tracks(animation_method_map: Dictionary):
	if not ANIMATIONPLAYER:
		return
		
	for animation_name in animation_method_map:
		
		var animation: Animation
		if ANIMATIONPLAYER.has_animation(animation_name):
			animation = ANIMATIONPLAYER.get_animation(animation_name)
		else:
			return

		# Create a single call method track for this animation
		var track_index = animation.add_track(Animation.TYPE_METHOD)

		# Set the track path to the owner node (assumed to be where methods are defined)
		animation.track_set_path(track_index, self.get_path())

		for method_data in animation_method_map[animation_name]:
			var method_name = method_data["method"]
			var call_time = method_data["time"]
			var args = method_data.get("args", [])



			var method_dictionary = {
				"method": method_name,
				"args": args
			}

			# Insert the method call at the specified time
			var key_index = animation.track_insert_key(track_index, call_time, method_dictionary)





func _ready():
	# Making player global
	Global.player = self
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Exception
	WALL_RAYCAST.add_exception(self)
	
	# Maximum number of times the body can change direction before it stops when calling move_and_slide()
	set_max_slides(20)

	var animation_method_map = {
		"HilgaRun": [
			{"method": "_play_bootstep_sound", "time": 0.014},
			{"method": "_play_bootstep_sound", "time": 0.531}
		],
		"Hilga_Landing": [
			{"method": "_play_land", "time": 0}
		],
		"Hilga_Jumping3": [
			{"method": "_play_jump", "time": 0.03}
		],
		"Hilga_Jumping3_2": [
			{"method": "_play_jump", "time": 0.03}
		],
		"Hilga_Dash2": [
			{"method": "_play_dash", "time": 0}
		]
	}
	insert_call_method_tracks(animation_method_map)
