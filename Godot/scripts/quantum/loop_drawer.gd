extends Node3D
## Draws the player's trail on the ground while the left mouse button is held.
## The trail has a maximum length (the oldest part disappears).
## When the trail crosses itself, the enclosed area is sent out as a polygon (x/z coordinates).

signal loop_closed(polygon: PackedVector2Array)

var max_length := 22.0
var min_step := 0.15
var width := 0.24
var enabled := false
var points: Array[Vector3] = []

var _drawing := false
var _trail_mesh := ImmediateMesh.new()
var _flash_mesh := ImmediateMesh.new()
var _flash_poly := PackedVector2Array()
var _flash_t := 0.0
const FLASH_TIME := 0.7


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mesh in [_trail_mesh, _flash_mesh]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_drawing = false
		points.clear()


## Where a screen position hits the ground (y = 0), or null.
func ground_point(screen: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	return Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(screen), cam.project_ray_normal(screen))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		points.clear()
		if _drawing:
			_try_add(event.position)
	elif event is InputEventMouseMotion and _drawing:
		_try_add(event.position)


func _try_add(screen: Vector2) -> void:
	var hit = ground_point(screen)
	if hit != null:
		add_point(hit)


func add_point(p: Vector3) -> void:
	p.y = 0.0
	if not points.is_empty() and points[-1].distance_to(p) < min_step:
		return
	if points.size() >= 3:
		var a := _flat(points[-1])
		var b := _flat(p)
		# check the new segment against all older segments (not the one it touches)
		for i in range(points.size() - 2):
			var hit = Geometry2D.segment_intersects_segment(a, b, _flat(points[i]), _flat(points[i + 1]))
			if hit != null:
				var poly := PackedVector2Array([hit])
				for j in range(i + 1, points.size()):
					poly.append(_flat(points[j]))
				points.clear()
				points.append(p)
				_flash_poly = poly
				_flash_t = FLASH_TIME
				loop_closed.emit(poly)
				return
	points.append(p)
	_trim()


func _trim() -> void:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	while total > max_length and points.size() > 2:
		total -= points[0].distance_to(points[1])
		points.remove_at(0)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _process(delta: float) -> void:
	_trail_mesh.clear_surfaces()
	_ribbon(_trail_mesh, points, false, Color(0.6, 1.0, 1.0, 1.0), true)

	_flash_mesh.clear_surfaces()
	if _flash_t > 0.0:
		_flash_t -= delta
		var pts: Array[Vector3] = []
		for v in _flash_poly:
			pts.append(Vector3(v.x, 0.0, v.y))
		_ribbon(_flash_mesh, pts, true, Color(1.0, 0.92, 0.45, clampf(_flash_t / FLASH_TIME, 0.0, 1.0)), false)


## A flat strip of triangles along the points, slightly above the ground.
func _ribbon(mesh: ImmediateMesh, pts: Array[Vector3], closed: bool, color: Color, fade: bool) -> void:
	var n := pts.size()
	if n < 2:
		return
	var count := n + 1 if closed else n
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in count:
		var i := k % n
		var prev: Vector3 = pts[(i - 1 + n) % n] if (closed or i > 0) else pts[i]
		var next: Vector3 = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
		var d := next - prev
		d.y = 0
		d = d.normalized() if d.length() > 1e-5 else Vector3.RIGHT
		var side := Vector3(-d.z, 0, d.x) * width * 0.5
		var c := color
		if fade:
			c.a = color.a * lerpf(0.3, 1.0, float(k) / float(count - 1))  # older part fades
		var lift := Vector3.UP * 0.04
		mesh.surface_set_color(c)
		mesh.surface_add_vertex(pts[i] + side + lift)
		mesh.surface_set_color(c)
		mesh.surface_add_vertex(pts[i] - side + lift)
	mesh.surface_end()
