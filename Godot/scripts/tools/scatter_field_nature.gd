@tool
extends EditorScript
## One-click: scatters grass, flowers and grass patches around the field.
##
## HOW TO RUN
##   1. Open scenes/field.tscn (it must be the open scene tab).
##   2. Open this file in the Script editor, then File -> Run (Ctrl+Shift+X).
##   3. Look at the result, then save the scene (Ctrl+S).
##
## Everything goes into the node Ground/Grass/Scattered. Running it again DELETES that
## node and builds it anew, so hand-edits inside "Scattered" are lost on a re-run.
## Props you place yourself directly under Ground/Grass (like patch_blob_a) are kept.
## Tweak the layout in scripts/tools/nature_scatter.gd (PARAMETERS at the top).
## Not happy? Close the scene without saving and nothing has changed.

const Scatter := preload("res://scripts/tools/nature_scatter.gd")


func _run() -> void:
	var root := get_scene()
	var grass: Node3D = root.get_node_or_null("Ground/Grass") as Node3D if root else null
	if grass == null:
		push_error("Open scenes/field.tscn first (no Ground/Grass node in the open scene).")
		return
	var old := grass.get_node_or_null("Scattered")
	if old:
		grass.remove_child(old)
		old.free()
	var holder := Node3D.new()
	holder.name = "Scattered"
	grass.add_child(holder)
	holder.owner = root
	var n := Scatter.populate(holder, root)
	EditorInterface.mark_scene_as_unsaved()
	print("[scatter] placed %d nature props under Ground/Grass/Scattered. Save with Ctrl+S." % n)
