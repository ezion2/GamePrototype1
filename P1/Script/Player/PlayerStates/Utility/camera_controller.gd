extends Node3D  # This script is attached to a Node3D in the scene hierarchy, allowing 3D positioning and rotation
# TODO: If colliding with wall, continue camera follow
# TODO: Edit follow position offsets so we can get the lookahead


# Rotation limits
# Horizontal rotation (around Y-axis), initialized to 0
const YAW_MIN: float = 0.0  # Minimum yaw angle (in degrees)
const YAW_MAX: float = 360.0  # Maximum yaw angle (in degrees)

@export_group("Camera Settings")
## Minimum pitch angle (in degrees)
# Vertical rotation (around X-axis), initialized to 0
@export var PITCH_MIN: float = -80.0
## Maximum pitch angle (in degrees)
@export var PITCH_MAX: float = 45.0
### Default distance of camera from target
@export var DEFAULT_ZOOM: float = 5.0
## Maximum zoom out distance
@export var ZOOM_OUT: float = 7.0

@export_group("Mouse Settings")
## Controls how much the camera rotates per pixel of mouse movement
@export var MOUSE_SENSITIVITY: float = 0.07
## Higher values make camera movement smoother but less responsive
@export var MOUSE_SMOOTHING: float = 15.0

@export_group("Lookahead Settings")
## Camera Spring Arm to manipulate
@export var camera_spring_arm: SpringArm3D
## Target to follow
@export var follow_target: Node3D
## Maximum Lookahead spring arm length
@export var LOOK_AHEAD_LENGTH: float = 1.5
## Threshold to determine significant sideways movement
@export var SIDEWAYS_THRESHOLD: float = 0.3
## Speed of camera movement for side-to-side motion or when idle (Spring returns at this speed after a certain delay)
@export var SPRING_LERP_SPEED: float = 3.5
## Speed of return to neutral when moving forward/backward
@export var NEUTRAL_RETURN_SPEED: float = 3.5
## Delay before returning to neutral when stopped (seconds)
@export var RETURN_TO_NEUTRAL_DELAY: float = 3.5

var zoom_status_bool : bool = false  # Tracks whether we're currently zoomed out
var back_away_offset : float = 0  # Additional offset when player moves towards camera
var _neutral_timer: float = 0.0 # Timer to track how long the player has been stationary

@onready var _player_pcam: PhantomCamera3D = %PlayerPhantomCamera3D
@onready var camera: Camera3D = %Camera3D  # Reference to the actual Camera3D node
@onready var pause_menu: Control = $PauseMenu

# @onready var camera_spring_arm: SpringArm3D = %CameraSpringArm3D

func _ready() -> void:
	if _player_pcam.get_follow_mode() == _player_pcam.FollowMode.THIRD_PERSON or _player_pcam.get_follow_mode() == _player_pcam.FollowMode.HYBRID:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Capture the mouse cursor
	
	# TODO: pcam is ready before camera controller
	_player_pcam.follow_target = follow_target
	
func _unhandled_input(event: InputEvent) -> void:
	if _player_pcam.get_follow_mode() == _player_pcam.FollowMode.THIRD_PERSON or _player_pcam.get_follow_mode() == _player_pcam.FollowMode.HYBRID:
		_set_pcam_rotation(_player_pcam, event)
		
	if event.is_action_pressed("zoom"):
		zoom_status_bool = !zoom_status_bool
	
func _process(delta: float) -> void:
	_player_pcam.spring_length = Global.player.expDecay(_player_pcam.spring_length, ZOOM_OUT, 9, delta) if zoom_status_bool else Global.player.expDecay(_player_pcam.spring_length, DEFAULT_ZOOM, 9, delta)
	
	move_camera_back(delta)
	adjust_spring_arm_length(delta)
	
func _set_pcam_rotation(pcam: PhantomCamera3D, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pcam_rotation_degrees: Vector3
	
		# Assigns the current 3D rotation of the SpringArm3D node - so it starts off where it is in the editor
		pcam_rotation_degrees = pcam.get_third_person_rotation_degrees()
	
		# Change the X rotation
		pcam_rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
	
		# Clamp the rotation in the X axis so it go over or under the target
		pcam_rotation_degrees.x = clampf(pcam_rotation_degrees.x, PITCH_MIN, PITCH_MAX)
	
		# Change the Y rotation value
		pcam_rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
	
		# Sets the rotation to fully loop around its target, but witout going below or exceeding 0 and 360 degrees respectively
		pcam_rotation_degrees.y = wrapf(pcam_rotation_degrees.y, YAW_MIN, YAW_MAX)
	
		# Change the SpringArm3D node's rotation and rotate around its target
		pcam.set_third_person_rotation_degrees(pcam_rotation_degrees)
		
		camera_spring_arm.rotation_degrees.y = pcam_rotation_degrees.y + 90
	
func move_camera_back(delta) -> void:
	# Update camera position
	# Get the size of the viewport
	var viewport_size = camera.get_viewport().size
	
	# Calculate the center of the screen
	var center_screen = viewport_size / 2
	
	var normal_vector : Vector3 = Vector3(camera.project_ray_normal(center_screen).x, 0, camera.project_ray_normal(center_screen).z).normalized()
	
	# Walking towards camera
	if round(Global.player.movement_direction.dot(normal_vector)) < 0 and !Global.player.movement_direction.is_zero_approx():
		back_away_offset = Global.player.expDecay(back_away_offset, 2, 9, delta)
		_player_pcam.spring_length = Global.player.expDecay(_player_pcam.spring_length, _player_pcam.spring_length + back_away_offset, 9, delta)
	else:
		back_away_offset = Global.player.expDecay(back_away_offset, 0, 9, delta)
		_player_pcam.spring_length = Global.player.expDecay(_player_pcam.spring_length, _player_pcam.spring_length + back_away_offset, 9, delta)
	
# TODO: Take into account velocity as well for sliding
func adjust_spring_arm_length(delta: float) -> void:
	# Get the player's current movement direction
	var movement_dir = Global.player.movement_direction
	
	# Get the camera's right and forward vectors
	var camera_right = _player_pcam.global_transform.basis.x.normalized()
	var camera_forward = -_player_pcam.global_transform.basis.z
	camera_forward.y = 0  # Ensure it's on the horizontal plane
	camera_forward = camera_forward.normalized()
	
	# Project the movement direction onto the camera's right and forward vectors
	var right_movement = camera_right.dot(movement_dir)
	var forward_movement = camera_forward.dot(movement_dir)
	
	# Variables to determine camera behavior
	var target_length: float
	var is_sideways_movement: bool = false
	var lerp_speed: float = SPRING_LERP_SPEED
	
	# No movement detected
	if movement_dir.length_squared() < 0.1:
		_neutral_timer += delta  # Increment the neutral timer
		
		# Start returning to neutral after delay
		if _neutral_timer >= RETURN_TO_NEUTRAL_DELAY:
			target_length = 0
		
		# Maintain current length
		else:
			target_length = camera_spring_arm.spring_length
	
	# Mostly forward/backward movement
	elif abs(right_movement) <= abs(forward_movement) * SIDEWAYS_THRESHOLD:
		# Reset the neutral timer when moving forward/backward
		_neutral_timer = 0.0
		
		# Set target to neutral
		target_length = 0
		
		# Use slower return speed
		lerp_speed = NEUTRAL_RETURN_SPEED
	
	# Significant sideways movement
	else:
		# Reset the neutral timer
		_neutral_timer = 0.0  
		is_sideways_movement = true
		
		# Walking speed is 7, need to moving at that speed or higher in order to do the lookahead
		## TODO: taking into account only x and z components later
		if round(Global.player.velocity.length_squared()) >= 49:
			if right_movement > 0:
				target_length = LOOK_AHEAD_LENGTH  # Set target to right
			else:
				target_length = -LOOK_AHEAD_LENGTH  # Set target to left
	
	# Apply the camera movement
	if is_sideways_movement or _neutral_timer > 0 or movement_dir.length() >= 0.1:
		# Lerp the spring arm length towards the target length
		camera_spring_arm.spring_length = Global.player.expDecay(camera_spring_arm.spring_length, target_length, lerp_speed, delta)
		
