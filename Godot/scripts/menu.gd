extends Control
## Start menu: play the quantum level or explore the meadow.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # walk mode hides the mouse; show it again
	get_tree().paused = false

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/quantum_level.tscn")

func _on_explore_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/walk_mode.tscn")

func _on_settings_pressed() -> void:
	$CenterContainer.hide()          # swap the menu panel for the settings panel
	%SettingsMenu.open()
	await %SettingsMenu.closed
	$CenterContainer.show()

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_button_pressed() -> void:
	pass # Replace with function body.
