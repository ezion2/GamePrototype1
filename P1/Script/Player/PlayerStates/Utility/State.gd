# Generic state class from which all other classes will inherit
# NOTE: Player state variables have persistence. EX: Setting a variables from 20 to 0. Next time you enter that state, it will still be 0
class_name State
extends Node

signal transition(new_state_name: StringName)

# Actions we must take while in this state
# Tied to visual framerate
# Anything not physics related
# Animation, updating UI elements, moving camera, etc
# Corresponds to the _process() callback
func update(_delta: float) -> void:
	pass

# Physics related actions we must take while we are in this state
# Checking where we are in the world, checking if we are on the ground etc
# Tied to physics framerate
# Use this when checking key presses
# Corresponds to the _physics_process() callback
func physics_update(_delta: float) -> void:
	pass

# Actions we must take when we enter this state
func enter(_msg := {}) -> void:
	pass

# Actions we must take before we exit this state	
func exit() -> void:
	pass

# Virtual function. Corresponds to _unhandled_input() callback
func handle_input(_event: InputEvent) -> void:
	pass
