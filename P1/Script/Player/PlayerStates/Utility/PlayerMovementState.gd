class_name PlayerMovementState
extends State

var PLAYER : Player
var ANIMATIONTREE : AnimationTree
var ANIMATION_STATE_MACHINE : AnimationNodeStateMachinePlayback

func _ready():
	await owner.ready
	PLAYER = owner as Player
	ANIMATIONTREE = PLAYER.ANIMATIONTREE
	ANIMATION_STATE_MACHINE = ANIMATIONTREE["parameters/StateMachine/playback"]
