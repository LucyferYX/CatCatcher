extends CanvasLayer
## Pause menu, used in both game modes. Esc opens/closes it.
## While it is open the game is paused (cats, timer, player all stop).

var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps reacting while the rest of the game is paused
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		if visible:
			_on_resume_pressed()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_mouse_before = Input.mouse_mode            # walk mode hides the mouse; remember that
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	show()


func _on_resume_pressed() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = _mouse_before


func _on_settings_pressed() -> void:
	$CenterContainer.hide()          # swap the pause panel for the settings panel
	%SettingsMenu.open()
	await %SettingsMenu.closed
	$CenterContainer.show()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
