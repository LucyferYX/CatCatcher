extends Node3D
## Wandering cat.
## Walks to random spots around its starting point, pauses, then picks a new spot.
## Expects a child Sprite3D named "Sprite3D" (the cat picture, facing right).

@export var speed := 1.5               # metres per second
@export var wander_radius := 8.0       # how far from its start point it may roam
@export var pause_min := 0.5           # seconds to sit still between walks
@export var pause_max := 2.0
@export var hop_height := 0.05         # little bounce while walking (fake running until the sprite is rigged)
@export var hop_speed := 14.0

@onready var sprite: Sprite3D = $Sprite3D

var home: Vector3
var target: Vector3
var wait := 0.0
var hop_time := 0.0
var sprite_base_y: float


func _ready() -> void:
	home = global_position
	sprite_base_y = sprite.position.y
	_pick_target()


func _pick_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(1.0, wander_radius)
	target = home + Vector3(cos(angle), 0, sin(angle)) * dist


func _process(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
		sprite.position.y = sprite_base_y
		return

	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() < 0.1:
		wait = randf_range(pause_min, pause_max)
		_pick_target()
		return

	var step := to_target.normalized() * speed * delta
	if step.length() > to_target.length():
		step = to_target
	global_position += step

	hop_time += delta * hop_speed
	sprite.position.y = sprite_base_y + absf(sin(hop_time)) * hop_height

	# The picture faces right; flip it when the cat moves toward the camera's left.
	var cam := get_viewport().get_camera_3d()
	if cam:
		sprite.flip_h = step.dot(cam.global_basis.x) < 0
