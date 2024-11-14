# This is the state manager
# Handles our transitions and such
class_name StateMachine
extends Node
#Stores our curent state
@export var CURRENT_STATE : State
# Stores all of our states
var states : Dictionary = {}

func _ready():
	# Our children will be stuff like idle, walk, jump, fall, etc
	for child in get_children():
		# Since State extends Node, we can check directly here whether it is a state or not
		if child is State:
			# Adding state to dictionary, using state as the key
			states[child.name] = child
			child.transition.connect(on_child_transition)
		else:
			push_warning("State machine contains incompatible child node!")
	await owner.ready
	CURRENT_STATE.enter()

# Handles state changesS
# Keeping track of states and providing a way to transition between them
func on_child_transition(new_state_name : StringName, data : Dictionary = {}) -> void:	
	var new_state = states.get(new_state_name)
	if new_state != null:
		if new_state != CURRENT_STATE:
			CURRENT_STATE.exit()
			new_state.enter(data)
			CURRENT_STATE = new_state
	else:
		push_warning("State does not exist!")

# Call the current state's update function constantly
func _process(delta: float):
	CURRENT_STATE.update(delta)

# Call the current state's update function constantly but for physics!	
func _physics_process(delta):
	CURRENT_STATE.physics_update(delta)


# Corresponds to _unhandled_input() callback
func handle_input(event: InputEvent) -> void:
	CURRENT_STATE.handle_input(event)
