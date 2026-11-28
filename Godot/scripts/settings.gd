extends Node
## Global settings + background music. Registered as the autoload "Settings":
## it exists from the start of the game and survives scene changes, so the music
## keeps playing between the menu and the levels. Settings are saved to user://.

const SAVE_PATH := "user://settings.cfg"
const MUSIC := preload("res://assets/audio/music.mp3")
const MUSIC_BUS := &"Music"
const MUSIC_BASE_DB := -6.0          # loudness of the track at 100 %

## Music volume, 0..100 (0 = muted).
var music_volume := 80.0:
	set(value):
		music_volume = clampf(value, 0.0, 100.0)
		_apply()

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep playing while the game is paused
	_load()
	_player = AudioStreamPlayer.new()
	_player.stream = MUSIC
	_player.bus = MUSIC_BUS
	_player.volume_db = MUSIC_BASE_DB
	add_child(_player)
	_player.play()
	_apply()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		music_volume = cfg.get_value("audio", "music_volume", music_volume)


func _apply() -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus == -1:
		return
	# The slider is linear (0..100), the bus works in decibels.
	AudioServer.set_bus_volume_db(bus, linear_to_db(music_volume / 100.0))
	AudioServer.set_bus_mute(bus, music_volume <= 0.0)
