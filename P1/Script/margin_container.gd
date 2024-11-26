@tool  # Allows the script to run in the editor
extends MarginContainer  # This script is attached to a MarginContainer node

# Export variables for each margin, allowing values from 0 to 100 (percentages)
@export_range(0, 100) var left_margin_percent: float = 10:
	set(value):  # Custom setter for the variable
		left_margin_percent = value  # Set the new value
		_update_margins()  # Update margins when the value changes

@export_range(0, 100) var top_margin_percent: float = 10:
	set(value):
		top_margin_percent = value
		_update_margins()

@export_range(0, 100) var right_margin_percent: float = 10:
	set(value):
		right_margin_percent = value
		_update_margins()

@export_range(0, 100) var bottom_margin_percent: float = 10:
	set(value):
		bottom_margin_percent = value
		_update_margins()

func _ready():
	_update_margins()  # Initial update of margins
	get_viewport().size_changed.connect(_update_margins)  # Connect to the size_changed signal

func _update_margins():
	# if not is_inside_tree() or not Engine.is_editor_hint():  # Check if the node is in the scene tree
	if not is_inside_tree():  # Check if the node is in the scene tree
		return  # If not, exit the function
	
	var parent_size : Vector2 = get_parent().get_rect().size  # Get the rectangle of the parent node then the size
	
	# Set each margin based on the percentage of the parent's size
	add_theme_constant_override("margin_left", parent_size.x * left_margin_percent / 100)
	add_theme_constant_override("margin_right", parent_size.x * right_margin_percent / 100)
	add_theme_constant_override("margin_top", parent_size.y * top_margin_percent / 100)
	add_theme_constant_override("margin_bottom", parent_size.y * bottom_margin_percent / 100)
