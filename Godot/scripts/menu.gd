extends Control
## Start menu: play the quantum level or explore the meadow.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # walk mode hides the mouse; show it again
	get_tree().paused = false

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/quantum_level.tscn")

func _on_explore_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/walk_mode.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
