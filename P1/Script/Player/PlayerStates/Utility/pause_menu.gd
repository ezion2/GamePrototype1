extends Control

var player_start_position: Vector3

func _ready():
	visible = false
	
# Pausing
func _shortcut_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		visible = !visible
		# Pause the game
		if visible == true:
			pause()
		# Resume the game
		else:
			resume()

func resume():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = false

func pause():
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	visible = true
	

func quit():
	get_tree().quit()

func _on_resume_button_pressed() -> void:
	resume()

func _on_quit_button_pressed() -> void:
	quit()


func _on_restart_button_pressed() -> void:
	resume()
	get_tree().reload_current_scene()
