@tool  # Allows script to run in the editor for preview functionality
# TODO: Make more performant.
# TODO: Make mode to go from 0 to 1, maybe...
extends CharacterBody3D

# Enumeration for different types of wave functions that can be used for platform movement
enum PeriodicMode {
	SIN             = 0,  # Smooth sinusoidal motion
	COS             = 1,  # Cosine motion (starts at peak)
	TAN             = 2,  # Tangent motion (more extreme)
	TAN_CLAMP       = 3,  # Clamped tangent to prevent extreme values
	TRIANGLE        = 4   # Linear motion between points
}

# Enumeration defining which axis to monitor for pause behavior
enum PauseAxis {
	NONE            = 0,  # No pause monitoring
	X               = 1,  # Monitor X axis
	Y               = 2,  # Monitor Y axis
	Z               = 3   # Monitor Z axis
}

# Enumeration defining when the platform should pause during its motion
enum PauseAt {
	CREST           = 0,  # Pause at highest point
	TROUGH          = 1,  # Pause at lowest point
	BOTH            = 2   # Pause at both extremes
}

# Export variables for platform movement speed on each axis
@export_group("Platform Speed")
@export var x_speed: float = 2.0  # Speed multiplier for X axis movement
@export var y_speed: float = 2.0  # Speed multiplier for Y axis movement
@export var z_speed: float = 2.0  # Speed multiplier for Z axis movement

# Export variables for maximum travel distance on each axis
@export_group("Platform Travel Distance")
@export var x_distance: float = 5.0  # Maximum X axis travel distance
@export var y_distance: float = 5.0  # Maximum Y axis travel distance
@export var z_distance: float = 5.0  # Maximum Z axis travel distance

# Export variables for selecting movement pattern on each axis
@export_group("Periodic Functions")
@export var x_periodic_func: PeriodicMode = PeriodicMode.SIN  # Wave function for X movement
@export var y_periodic_func: PeriodicMode = PeriodicMode.SIN  # Wave function for Y movement
@export var z_periodic_func: PeriodicMode = PeriodicMode.SIN  # Wave function for Z movement

# Export variables for platform pause behavior
@export_group("Pause Settings")
@export var pause_on_axis: PauseAxis = PauseAxis.NONE  # Which axis to check for pausing
@export var pause_at: PauseAt = PauseAt.CREST         # When to pause during motion
@export var pause_duration: float = 1.0                # How long to pause in seconds
@export var TOLERANCE: float = 0.1                     # How close to peak/trough to trigger pause

# Export variable for enabling motion preview in editor
@export_group("Editor Settings")
@export var enable_motion: bool = false:  # Toggle for editor preview
	set(value):  # Setter function for enable_motion
		enable_motion = value
		if Engine.is_editor_hint() and is_inside_tree():  # Check if we're in editor and node is ready
			if value:  # If enabling preview
				editor_start_pos = movingplatform.position  # Store current position
			else:  # If disabling preview
				# Reset all movement variables
				motion_time = 0.0
				is_paused = false
				pause_timer = 0.0
				movingplatform.position = editor_start_pos  # Return to start position

# Dictionary to store the wave function calculations
var wave_functions: Dictionary = {}
var start_pos: Vector3          # Starting position in gameplay
var editor_start_pos: Vector3   # Starting position in editor
var motion_time: float = 0.0    # Tracks elapsed movement time
var pause_timer: float = 0.0    # Tracks current pause duration
var is_paused: bool = false     # Current pause state
var previous_axis_value: float = 0.0  # Previous frame's position for direction detection
var pause_triggered: bool = false      # Prevents multiple pauses at same position

# Reference to the platform node
@onready var movingplatform: Node3D = %movingplatform

# Initialize the wave functions with their mathematical formulas
func _init():
	wave_functions = {
		# All functions (except TAN) are scaled to output between 0 and 1
		PeriodicMode.SIN: func(x: float) -> float: return (sin(x) + 1) * 0.5,        # Sine wave
		PeriodicMode.COS: func(x: float) -> float: return (cos(x) + 1) * 0.5,        # Cosine wave
		PeriodicMode.TAN: func(x: float) -> float: return tan(x),                     # Tangent wave
		PeriodicMode.TAN_CLAMP: func(x: float) -> float: return clamp((tan(x) + 1) * 0.5, 0.0, 1.0),  # Clamped tangent
		PeriodicMode.TRIANGLE: func(x: float) -> float: return (1 - abs(2 * (x/(2*PI) - floor(x/(2*PI) + 0.5))))  # Triangle wave
	}

# Set up initial positions when the node enters the scene
func _ready():
	if Engine.is_editor_hint():  # If in editor
		editor_start_pos = movingplatform.position  # Store editor position
	else:  # If in game
		start_pos = global_position  # Store gameplay position

# Process platform movement each physics frame
func _physics_process(delta: float):
	# Skip processing if in editor with motion disabled
	if not (Engine.is_editor_hint() and not enable_motion):
		if is_paused:  # If platform is paused
			pause_timer += delta  # Increment pause timer
			if pause_timer >= pause_duration:  # Check if pause is complete
				# Reset pause state and continue motion
				is_paused = false
				pause_timer = 0.0
				motion_time += delta
		else:  # If platform is moving
			motion_time += delta  # Increment motion timer

		# Calculate new position based on current time
		var new_pos = calculate_motion(motion_time)
		
		if Engine.is_editor_hint():  # If in editor
			# Scale movement by platform's editor scale
			var scaled_pos = Vector3(
				new_pos.x * movingplatform.scale.x,
				new_pos.y * movingplatform.scale.y,
				new_pos.z * movingplatform.scale.z
			)
			
			# Apply rotation to the movement vector
			var basis = Basis.from_euler(movingplatform.rotation)
			var rotated_pos = basis * scaled_pos
			
			# Update editor position
			movingplatform.position = editor_start_pos + rotated_pos
		else:  # If in game
			# Scale movement by platform's game scale
			var scaled_pos = Vector3(
				new_pos.x * scale.x,
				new_pos.y * scale.y,
				new_pos.z * scale.z
			)
			
			# Apply rotation to the movement vector
			var basis = Basis.from_euler(global_rotation)
			var rotated_pos = basis * scaled_pos
			
			# Update game position
			global_position = start_pos + rotated_pos

# Get the length of a vector after applying rotation and scale
func get_transformed_length(vec: Vector3, rot: Vector3, scl: Vector3) -> float:
	# Scale the vector
	var scaled = Vector3(vec.x * scl.x, vec.y * scl.y, vec.z * scl.z)
	# Rotate the vector
	var basis = Basis.from_euler(rot)
	var transformed = basis * scaled
	# Return the length
	return transformed.length()

# Check if platform should pause based on its position
func should_pause(axis_value: float, max_value: float) -> bool:
	# Skip if pause monitoring is disabled
	if pause_on_axis == PauseAxis.NONE:
		return false
	
	# Determine movement direction
	var moving_up: bool = axis_value > previous_axis_value
	var moving_down: bool = axis_value < previous_axis_value
	
	# Check if near extreme positions
	var near_crest: bool = abs(axis_value - max_value) < TOLERANCE  # Near highest point
	var near_trough: bool = abs(axis_value) < TOLERANCE            # Near lowest point
	
	var should_trigger: bool = false
	
	# Handle different pause modes
	match pause_at:
		PauseAt.CREST:  # Pause at highest point
			if near_crest and moving_up and not pause_triggered:
				should_trigger = true
				pause_triggered = true
			elif not near_crest and moving_down:
				pause_triggered = false
				
		PauseAt.TROUGH:  # Pause at lowest point
			if near_trough and moving_down and not pause_triggered:
				should_trigger = true
				pause_triggered = true
			elif not near_trough and moving_up:
				pause_triggered = false
				
		PauseAt.BOTH:  # Pause at both extremes
			if near_crest and moving_up and not pause_triggered:
				should_trigger = true
				pause_triggered = true
			elif near_trough and moving_down and not pause_triggered:
				should_trigger = true
				pause_triggered = true
			elif not near_crest and not near_trough:
				pause_triggered = false
	
	previous_axis_value = axis_value  # Store current value for next frame
	return should_trigger

# Get the current position value for the monitored axis
func get_monitored_value(time: float) -> Vector2:
	# Variables to store axis-specific parameters
	var speed: float
	var func_type: PeriodicMode
	var distance: float
	var base_vector: Vector3
	
	# Set parameters based on monitored axis
	match pause_on_axis:
		PauseAxis.X:  # Monitor X axis
			speed = x_speed
			func_type = x_periodic_func
			distance = x_distance
			base_vector = Vector3(1, 0, 0)
			
		PauseAxis.Y:  # Monitor Y axis
			speed = y_speed
			func_type = y_periodic_func
			distance = y_distance
			base_vector = Vector3(0, 1, 0)
			
		PauseAxis.Z:  # Monitor Z axis
			speed = z_speed
			func_type = z_periodic_func
			distance = z_distance
			base_vector = Vector3(0, 0, 1)
		_:  # No axis monitored
			return Vector2.ZERO
	
	# Get the rotation and scale to use
	var current_rot = global_rotation if not Engine.is_editor_hint() else movingplatform.rotation
	var current_scale = scale if not Engine.is_editor_hint() else movingplatform.scale
	
	# Calculate the transformed length of our unit vector
	var transformed_unit = get_transformed_length(base_vector, current_rot, current_scale)
	
	# Calculate current value and apply scaling
	var current_value = wave_functions[func_type].call(time * speed) * distance * transformed_unit
	return Vector2(current_value, distance * transformed_unit)  # Return current and max values

# Calculate the platform's motion offset
func calculate_motion(time: float) -> Vector3:
	# Get current position for pause monitoring
	var monitored = get_monitored_value(time)
	
	# Check if we should start pausing
	if should_pause(monitored.x, monitored.y) and not is_paused:
		is_paused = true
		pause_timer = 0.0
	
	# Calculate and return new position offset
	return Vector3(
		wave_functions[x_periodic_func].call(time * x_speed) * x_distance,  # X movement
		wave_functions[y_periodic_func].call(time * y_speed) * y_distance,  # Y movement
		wave_functions[z_periodic_func].call(time * z_speed) * z_distance   # Z movement
	)
