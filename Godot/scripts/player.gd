extends CharacterBody3D
## First-person walker for exploring the scene.
## Controls: WASD = walk, Shift = run, Space = jump, mouse = look,
## Esc = pause menu (pause_menu.gd), click = capture the mouse again.

@export var walk_speed := 3.0
@export var run_speed := 5.5
@export var jump_velocity := 4.0
@export var mouse_sensitivity := 0.002

@onready var camera: Camera3D = $Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)          # turn left/right (whole body)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)   # look up/down (camera only)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input.y += 1
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input.x += 1
	input = input.normalized()

	# Turn the key input into a direction relative to where the player is facing.
	var direction := transform.basis * Vector3(input.x, 0, input.y)
	var speed := run_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
