extends Node3D
## Witch's hut extras, attached to the imported hut.
## 1. Door: the "HutDoor" node (origin = hinge) swings inward when the player comes close.
## 2. Porch ramp: an invisible wedge over the steps, so the player can walk up them.

@export var open_angle_deg := 100.0
@export var open_time := 0.7                          # seconds to open / close
@export var trigger_size := Vector3(2.4, 2.4, 4.0)    # zone around the doorway (metres, hut space)

@export_group("Porch ramp")
@export var add_porch_ramp := true
## Hut space: porch deck top y = 0.35, deck front edge z = 2.44, steps end at z = 3.04.
@export var ramp_top := Vector3(0.0, 0.355, 2.40)     # where the ramp meets the deck (centre)
@export var ramp_foot_z := 3.25                       # where the ramp meets the ground
@export var ramp_width := 1.2

var _door: Node3D
var _closed_y := 0.0
var _tween: Tween
var _bodies_near := 0


func _ready() -> void:
	if add_porch_ramp:
		_add_ramp()
	_door = find_child("HutDoor", true, false) as Node3D
	if _door == null:
		push_warning("hut_door.gd: no 'HutDoor' node in the hut.")
		return
	_closed_y = _door.rotation.y

	# Invisible trigger zone, centred on the doorway, reaching outside and inside.
	var area := Area3D.new()
	area.name = "DoorTrigger"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = trigger_size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	var middle := _door.position.x
	if _door is MeshInstance3D:                         # door middle = centre of its mesh
		middle = (_door.transform * (_door as MeshInstance3D).get_aabb().get_center()).x
	area.position = Vector3(middle, _door.position.y + trigger_size.y / 2.0, _door.position.z)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _add_ramp() -> void:
	# A wedge (triangle seen from the side) between the ground and the deck edge.
	var hw := ramp_width / 2.0
	var top_y := ramp_top.y
	var zt := ramp_top.z
	var zf := ramp_foot_z
	var pts := PackedVector3Array()
	for x in [-hw, hw]:
		pts.append(Vector3(ramp_top.x + x, 0.0, zf))     # foot, on the ground
		pts.append(Vector3(ramp_top.x + x, top_y, zt))   # top, at the deck edge
		pts.append(Vector3(ramp_top.x + x, 0.0, zt))     # bottom corner under the deck edge
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "PorchRamp"
	body.add_child(col)
	add_child(body)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:                         # the player (not the hut's own walls)
		_bodies_near += 1
		_swing(true)


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_bodies_near = maxi(_bodies_near - 1, 0)
		if _bodies_near == 0:
			_swing(false)


func _swing(open: bool) -> void:
	if _tween:
		_tween.kill()                                   # change direction mid-swing smoothly
	var target := _closed_y + (deg_to_rad(open_angle_deg) if open else 0.0)
	_tween = create_tween()
	_tween.tween_property(_door, "rotation:y", target, open_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN_OUT)
