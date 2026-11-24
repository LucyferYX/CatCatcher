@tool
extends EditorScenePostImport
## Import script for the nature props (set in the Import dock -> "Import Script").
## For every mesh in the file:
##  1. Shadows off (small grass casting shadows is expensive and barely visible).
##  2. Visibility range: the prop is not drawn at all when the camera is further away
##     than VISIBILITY_END metres (0 = always drawn).

const CAST_SHADOWS := false
const VISIBILITY_END := 40.0


func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not CAST_SHADOWS:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = VISIBILITY_END
	return scene
