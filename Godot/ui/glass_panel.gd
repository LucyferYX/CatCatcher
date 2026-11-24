@tool
class_name GlassPanel
extends PanelContainer
## A PanelContainer with a frosted-glass background: whatever is behind it gets blurred.
## Colour, border, corner shape and shadow still come from the theme's "panel" style,
## so it looks like every other panel, just blurry behind.

const SHADER := preload("res://ui/glass_panel.gdshader")

## How strongly the background is blurred (screen pixels). 0 = no blur.
@export_range(0.0, 24.0, 0.5) var blur := 12.0:
	set(value):
		blur = value
		_update()

## White haze added to the blurred background.
@export_range(0.0, 0.4, 0.01) var frost := 0.06:
	set(value):
		frost = value
		_update()


func _ready() -> void:
	# Every GlassPanel gets its own material, because each one has its own size.
	material = ShaderMaterial.new()
	material.shader = SHADER
	resized.connect(_update)
	theme_changed.connect(_update)
	_update()


func _update() -> void:
	var m := material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("rect_size", size)
	m.set_shader_parameter("blur_px", blur)
	m.set_shader_parameter("frost", frost)
	var radii := Vector4.ZERO
	var sb := get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		radii = Vector4(sb.corner_radius_top_left, sb.corner_radius_top_right,
				sb.corner_radius_bottom_right, sb.corner_radius_bottom_left)
	m.set_shader_parameter("corner_radii", radii)
