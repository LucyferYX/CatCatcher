@tool
extends RefCounted
## Scatters the nature props (assets/models/nature/*.glb) around the field.
## Used by scripts/tools/scatter_field_nature.gd (the one-click editor script).
##
## The idea (like the concept art): the open field in the middle, where the cat runs,
## stays almost empty; further out the grass and flowers get denser and denser.
## Props come in little clusters (a clump of grass + some flowers + maybe a grass patch
## underneath), and grass patches hug the hut walls. The same SEED always gives the
## same layout; change SEED for a different random layout.

# ---------------------------------------------------------------- PARAMETERS
const SEED := 3
const CENTER := Vector2(0.5, 0.8)       # (x, z) middle of the open field where the cat runs
const CLEAR_RADIUS := 2.6               # nothing grows closer than this to CENTER (metres)
const FULL_RADIUS := 7.5                # from this distance on, the grass is at its densest
const STRETCH_X := 1.3                  # the open field is this much wider along x than along z
const AREA := Rect2(-11, -15, 27, 24.5) # where props may go: x -11..16, z -15..9.5
const CLUSTER_SPACING := 1.35           # distance between clusters where it is densest (smaller = more)
const SPARSE_SPACING := 3.2             # ... and where it is sparsest (near the clear middle)
const NOISE_FREQ := 0.12                # size of the denser/thinner blotches (smaller = bigger blotches)
const NOISE_STRENGTH := 0.6             # 0 = smooth fade outwards, 1 = very blotchy
const SCALE := Vector2(1.0, 1.5)        # random size range of grass and flower clumps
const PATCH_SCALE := Vector2(1.0, 1.35) # random size range of the flat grass patches
# Hut (witch_hut.glb at (0, 0, -6)): walls x -2.1..2.1, z -7.3..-4.7; porch to x 2.7, z -3.56
const HUT_RECT := Rect2(-2.1, -7.3, 4.8, 3.74)
const PATH_RECT := Rect2(-0.9, -3.6, 1.8, 2.8)  # kept free in front of the porch steps
const HUG_HUT := true                   # grass patches along the hut walls
const HUG_STEP := 1.1                   # distance between patches along the walls

# What grows where. Numbers = how often (weights). The variant (_a/_b/_c) is random.
const SPARSE_KINDS := {"grass_small": 4, "grass_round": 3, "flowers_small": 2}
const DENSE_KINDS := {"grass_tall": 3, "grass_mixed": 3, "grass_round": 2, "grass_small": 2,
		"flowers_mixed": 2, "flowers_small": 2, "flowers_big": 1}
const HUG_KINDS := {"grass_tall": 3, "grass_mixed": 2, "flowers_mixed": 2, "flowers_big": 1}
const PATCH_KINDS := {"patch_blob": 2, "patch_strip": 1}
# ---------------------------------------------------------------------------

const DIR := "res://assets/models/nature/"

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var parent: Node3D
var owner: Node
var cache := {}
var spots: Array[Vector2] = []          # cluster centres placed so far
var count := 0


## Fills `into` with props. `scene_owner` = the scene root (so the nodes get saved).
## Returns how many props were placed.
static func populate(into: Node3D, scene_owner: Node) -> int:
	var s = new()
	s.parent = into
	s.owner = scene_owner
	s.rng.seed = SEED
	s.noise.seed = SEED
	s.noise.frequency = NOISE_FREQ
	if HUG_HUT:
		s._hug_hut()
	s._clusters()
	return s.count


func _density(p: Vector2) -> float:
	var d := Vector2((p.x - CENTER.x) / STRETCH_X, p.y - CENTER.y).length()
	var base := smoothstep(CLEAR_RADIUS, FULL_RADIUS, d)
	var blotch := clampf(1.0 + NOISE_STRENGTH * 1.6 * noise.get_noise_2d(p.x, p.y), 0.0, 1.3)
	var near_hut := 1.0 - smoothstep(0.0, 2.5, _dist_to_rect(p, HUT_RECT))
	return clampf(base * blotch + 0.4 * near_hut, 0.0, 1.0)


func _dist_to_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return Vector2(dx, dz).length()


func _blocked(p: Vector2, margin: float) -> bool:
	return HUT_RECT.grow(margin).has_point(p) or PATH_RECT.has_point(p)


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var x := rng.randf() * total
	for k in weights:
		x -= weights[k]
		if x <= 0.0:
			return k
	return weights.keys()[0]


func _place(kind: String, p: Vector2, yaw: float, size: float) -> void:
	var path: String = DIR + kind + "_" + ["a", "b", "c"][rng.randi() % 3] + ".glb"
	if not cache.has(path):
		cache[path] = load(path)
	var ps: PackedScene = cache[path]
	var n := ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	n.name = path.get_file().get_basename()
	parent.add_child(n, true)                       # true = readable unique names (grass_tall_a2, ...)
	if owner:
		n.owner = owner
	n.position = Vector3(p.x, 0.0, p.y)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * size
	count += 1


func _hug_hut() -> void:
	# walk around the hut + porch, one long grass patch every HUG_STEP, lying along the wall
	var r := HUT_RECT.grow(0.3)
	var sides := [   # start, end, outward direction
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0, 1)],          # front
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0, -1)], # back
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(-1, 0)], # left
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(1, 0)],            # right
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var out: Vector2 = side[2]
		var along := (b - a).normalized()
		var steps := int((b - a).length() / HUG_STEP)
		for i in range(steps + 1):
			var p := a + along * (i * HUG_STEP + rng.randf_range(-0.2, 0.2))
			p += out * rng.randf_range(0.0, 0.25)
			if PATH_RECT.grow(0.3).has_point(p):
				continue
			var yaw := -atan2(along.y, along.x) + rng.randf_range(-0.25, 0.25)
			_place("patch_strip", p, yaw, rng.randf_range(PATCH_SCALE.x, PATCH_SCALE.y))
			spots.append(p)
			if rng.randf() < 0.6:   # a clump a bit further out
				var q := p + out * rng.randf_range(0.35, 0.8) + along * rng.randf_range(-0.4, 0.4)
				if not _blocked(q, 0.2):
					_place(_pick(HUG_KINDS), q, rng.randf() * TAU, rng.randf_range(SCALE.x, SCALE.y))


func _clusters() -> void:
	# dart throwing: random spot, keep it if it isn't too close to an earlier cluster.
	# "Too close" depends on the density, so the clusters thin out towards the middle.
	for _i in range(4000):
		var p := Vector2(rng.randf_range(AREA.position.x, AREA.end.x),
				rng.randf_range(AREA.position.y, AREA.end.y))
		if _blocked(p, 0.35):
			continue
		var d := _density(p)
		if d < 0.04:
			continue
		var gap := lerpf(SPARSE_SPACING, CLUSTER_SPACING, sqrt(d))
		var is_free := true
		for s in spots:
			if s.distance_to(p) < gap:
				is_free = false
				break
		if is_free:
			spots.append(p)
			_cluster(p, d)


func _cluster(p: Vector2, d: float) -> void:
	var placed: Array[Vector2] = []
	if d > 0.45 and rng.randf() < d * 0.55:   # grass patch underneath, mostly in the dense outskirts
		_place(_pick(PATCH_KINDS), p, rng.randf() * TAU, rng.randf_range(PATCH_SCALE.x, PATCH_SCALE.y))
	var n := 1 + int(round(d * rng.randf_range(1.5, 4.5)))
	var spread := 0.3 + 0.55 * d
	for _k in range(n):
		for _try in range(6):
			var q := p + Vector2.from_angle(rng.randf() * TAU) * spread * sqrt(rng.randf())
			var ok := not _blocked(q, 0.2)
			for o in placed:
				if o.distance_to(q) < 0.4:
					ok = false
			if ok:
				var kinds := SPARSE_KINDS if d < 0.35 else DENSE_KINDS
				var size := rng.randf_range(SCALE.x, SCALE.y)
				if d < 0.35:
					size = rng.randf_range(SCALE.x, lerpf(SCALE.x, SCALE.y, 0.5))
				_place(_pick(kinds), q, rng.randf() * TAU, size)
				placed.append(q)
				break
