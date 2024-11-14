extends AnimationTree
@onready var STATE_MACHINE = %PlayerStateMachine
@onready var PLAYER : Player = owner
#@onready var PLAYER : Player = $"../.."

var state : StringName
var floor_status : bool

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	state = STATE_MACHINE.CURRENT_STATE.name
	floor_status = PLAYER.is_on_floor() or PLAYER._snapped_to_stairs_last_frame


func _on_animation_finished(anim_name: String):
	if anim_name == "Hilga_Landing":
		self["parameters/StateMachine/playback"].travel("idle_walk")
	elif anim_name == "Hilga_Runstop2":
		self["parameters/StateMachine/playback"].travel("idle_walk")
