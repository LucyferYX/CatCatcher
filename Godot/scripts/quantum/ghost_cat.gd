extends Node3D
## One possible position of the cat (one basis state, e.g. |01> = ghost B).
## Brightness shows the probability. At ~100% it is the solid cat, at 0% it is invisible.
## Movement is ordinary game logic: wander, and run from the cursor.

signal arrived

const CAT_TEXTURE := preload("res://assets/textures/CatSprite1.png")
const PIXEL_SIZE := 0.0012          # image is 1551 px wide -> about 1.9 m (the cat itself ~1.5 m)
const SPRITE_Y := 0.53              # lifts the sprite so the paws touch the ground

var index := 0
var letter := "A"
var probability := 0.0
var negative := false               # amplitude sign (shown as a pink tint)
var frozen := false
var note := ""                      # text shown above a solid cat, e.g. "splits in 3"
var bounds := Rect2(-9, -3, 18, 10) # x/z area the ghost may move in
var flee_from = null                # Vector3 or null (cursor position on the ground)
var flee_radius := 3.0
var walk_speed := 1.3
var run_speed := 3.2

var _sprite: Sprite3D
var _label: Label3D
var _glow: MeshInstance3D           # soft disc under the cat: purple = ghost, gold = solid
var _glow_mat: StandardMaterial3D
var _alpha := 0.0
var _velocity := Vector3.ZERO
var _target := Vector3.ZERO
var _scripted_target = null         # Vector3 or null (used for the intro walk)
var _hop := 0.0


func _init() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.01
	disc.radial_segments = 24
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow = MeshInstance3D.new()
	_glow.mesh = disc
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position.y = 0.02
	_glow.scale = Vector3(1.0, 1.0, 0.6)
	add_child(_glow)

	_sprite = Sprite3D.new()
	_sprite.texture = CAT_TEXTURE
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.position.y = SPRITE_Y
	_sprite.modulate = Color(1, 1, 1, 0)
	add_child(_sprite)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 56
	_label.outline_size = 16
	_label.pixel_size = 0.006
	_label.position.y = 1.5
	add_child(_label)

	_hop = randf() * 10.0


func set_probability(p: float, amp_negative: bool) -> void:
	probability = p
	negative = amp_negative


func walk_to(p: Vector3) -> void:
	_scripted_target = p


func burst(direction: Vector3) -> void:
	_velocity = direction * run_speed
	_target = _clamped(position + direction * 3.0)


func _target_alpha() -> float:
	if probability < 0.001:
		return 0.0
	return clampf(0.2 + 0.8 * sqrt(probability), 0.0, 1.0)


func _clamped(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), 0.0,
			clampf(p.z, bounds.position.y, bounds.end.y))


func _pick_target() -> void:
	var angle := randf() * TAU
	_target = _clamped(position + Vector3(cos(angle), 0, sin(angle)) * randf_range(2.0, 5.0))


func _process(delta: float) -> void:
	# --- looks
	_alpha = move_toward(_alpha, _target_alpha(), delta * 2.0)
	var tint := Color(1.0, 0.72, 0.8) if negative else Color(1, 1, 1)
	tint.a = _alpha
	_sprite.modulate = tint
	_sprite.visible = _alpha > 0.01
	_label.visible = _alpha > 0.05
	var glow := Color(1.0, 0.82, 0.35) if probability > 0.999 else (Color(1.0, 0.55, 0.75) if negative else Color(0.72, 0.58, 1.0))
	glow.a = _alpha * 0.55
	_glow_mat.albedo_color = glow
	_glow.visible = _alpha > 0.01
	if probability > 0.999:
		_label.text = note
	else:
		_label.text = "%s  %d%%" % [letter, roundi(probability * 100.0)]
	_label.modulate = Color(1.0, 0.75, 0.82) if negative else Color(1, 1, 1)

	if frozen:
		_sprite.position.y = SPRITE_Y
		return

	# --- movement
	var desired := Vector3.ZERO
	var speed := walk_speed
	if _scripted_target != null:
		var to: Vector3 = _scripted_target - position
		to.y = 0
		if to.length() < 0.1:
			_scripted_target = null
			arrived.emit()
		else:
			desired = to.normalized()
	else:
		var away := Vector3.ZERO
		if flee_from != null:
			away = position - flee_from
			away.y = 0
		if flee_from != null and away.length() < flee_radius:
			desired = away.normalized()
			speed = run_speed
		else:
			var to := _target - position
			to.y = 0
			if to.length() < 0.3:
				_pick_target()
			elif to.length() > 0.01:
				desired = to.normalized()

	_velocity = _velocity.lerp(desired * speed, clampf(delta * 4.0, 0.0, 1.0))
	var before := position
	position = _clamped(position + _velocity * delta)
	if (position - before).length() < _velocity.length() * delta * 0.5:
		_pick_target()                       # bumped into the fence -> pick a new direction

	# little hop while moving (fake running until the sprite is rigged)
	if _velocity.length() > 0.2:
		_hop += delta * 14.0
		_sprite.position.y = SPRITE_Y + absf(sin(_hop)) * 0.06
	else:
		_sprite.position.y = SPRITE_Y

	var cam := get_viewport().get_camera_3d()
	if cam and _velocity.length() > 0.1:
		_sprite.flip_h = _velocity.dot(cam.global_basis.x) < 0
