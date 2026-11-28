extends Control
## Settings panel, shared by the main menu and the pause menu.
## open() shows it; "Back" or Esc closes it (and saves). Values live in the Settings autoload.
## Needs these nodes marked "Access as Unique Name": MusicSlider, MusicValue, BackButton.

signal closed

@onready var _slider: HSlider = %MusicSlider
@onready var _value: Label = %MusicValue


func _ready() -> void:
	hide()
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 1
	_slider.value_changed.connect(_on_music_changed)
	%BackButton.pressed.connect(close)


func open() -> void:
	_slider.value = Settings.music_volume
	_value.text = str(int(_slider.value))
	show()


func close() -> void:
	Settings.save()
	hide()
	closed.emit()


func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	_value.text = str(int(value))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):   # Esc
		close()
		get_viewport().set_input_as_handled()
