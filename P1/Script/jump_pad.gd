extends Node3D
@export var jump_strength = 90
@onready var ray_cast_direction = %RayCastDirection
@onready var animation_tree: AnimationTree = $"Bounce pad/AnimationTree"
var anim_state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	anim_state_machine = animation_tree["parameters/StateMachine/playback"]

func _on_area_3d_body_entered(body):
	if body.name == "Player":
		var direction = ray_cast_direction.global_transform.basis.y.normalized()
		
		if anim_state_machine.get_current_node() == "Pad_Use":
			anim_state_machine.start("Pad_Use")
		else:
			anim_state_machine.travel("Pad_Use")
		
		body.movement_direction = Vector3(ray_cast_direction.global_transform.basis.y.normalized().x, 0, ray_cast_direction.global_transform.basis.y.normalized().z)
		body.velocity += direction * jump_strength
		
		SignalManager.outside_force.emit(body)
