extends Control


@onready var option_button: OptionButton = $Resolution/OptionButton

const RESOLUTION_DICTIONARY : Dictionary = {
	"1152 x 648": Vector2i(1152, 648),
	"1280 x 720": Vector2i(1280, 720),
	"1920 x 1080": Vector2i(1920, 1080),
	"2560 x 1440": Vector2i(2560, 1440)
	
}


func _ready() -> void:
	option_button.item_selected.connect(on_resolution_mode_selected)
	add_resolution_mode_items()

func add_resolution_mode_items() -> void:
	for resolution_size_text in RESOLUTION_DICTIONARY:
		option_button.add_item(resolution_size_text)

func on_resolution_mode_selected(index : int) -> void:
	DisplayServer.window_set_size(RESOLUTION_DICTIONARY.values()[index])
	centre_window()


func centre_window() -> void:
	var centre_screen = DisplayServer.screen_get_position() + DisplayServer.screen_get_size()/2
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(centre_screen - window_size/2)
