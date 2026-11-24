extends Node3D
## Quantum Cat Catcher: prototype level.
##
## Flow: a solid cat walks through the Hadamard arch -> it splits into 2^n ghost cats
## (a superposition) -> the player draws loops. Closing a loop is a PARTIAL measurement
## ("is the cat inside?"): caught, or the enclosed ghosts vanish and the rest share 100%.
## Power-ups: Q Peek (full measurement), W Flip (X gate on qubit 0), E Merge (H on all qubits).
## Puddle: a ghost stepping in flips the sign of its amplitude (only visible after a Merge).
## R restarts. Everything is built in code, so the scene file only needs this script.
##
## Screenshot mode:
##   Godot_console.exe --path <project> res://scenes/quantum_game.tscn -- --shots=<folder>

const QuantumState := preload("res://scripts/quantum/quantum_state.gd")
const GhostCat := preload("res://scripts/quantum/ghost_cat.gd")
const LoopDrawer := preload("res://scripts/quantum/loop_drawer.gd")
const GameHUD := preload("res://scripts/quantum/game_hud.gd")

@export var n_qubits := 2
@export var level_time := 90.0
@export var split_delay := 4.0          # seconds a solid cat waits before splitting again
@export var power_cooldown := 8.0

const LETTERS := "ABCDEFGH"
const BOUNDS := Rect2(-8.0, -1.5, 16.0, 6.8)    # play area: x -8..8, z -1.5..5.3
const ARCH_POS := Vector3(-4.6, 0.0, 1.3)       # the cat walks through it toward the camera (+z)
const PUDDLE_POS := Vector3(4.2, 0.0, 3.2)
const PUDDLE_RADIUS := 1.1

enum Phase { INTRO, PLAY, SOLID, OVER }

var state: QuantumState
var rng := RandomNumberGenerator.new()
var ghosts: Array = []
var drawer: LoopDrawer
var hud: GameHUD
var phase := Phase.INTRO
var time_left := 0.0
var split_timer := 0.0
var solid_index := -1
var cooldowns := {"peek": 0.0, "flip": 0.0, "merge": 0.0}
var _in_puddle := {}
var _shots_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	if _shots_dir != "":
		seed(11)
		rng.seed = 11
	else:
		rng.randomize()

	state = QuantumState.new(n_qubits)
	_build_world()

	drawer = LoopDrawer.new()
	add_child(drawer)
	drawer.loop_closed.connect(_on_loop_closed)

	for i in state.size():
		var g := GhostCat.new()
		g.index = i
		g.letter = LETTERS[i]
		g.bounds = BOUNDS
		add_child(g)
		g.position = ARCH_POS + Vector3(0, 0, -1.8)
		ghosts.append(g)
		_in_puddle[i] = false

	hud = GameHUD.new()
	add_child(hud)
	hud.build(state, LETTERS, "Level 3  ·  %d qubits  →  %d possible cats" % [n_qubits, state.size()])
	hud.power_pressed.connect(_use_power)

	time_left = level_time
	_refresh()
	_start_intro()
	if _shots_dir != "":
		_take_screenshots()


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)      # from the camera side, so fronts are lit
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var grass := StandardMaterial3D.new()
	grass.albedo_texture = load("res://assets/textures/GrassTile.png")
	grass.albedo_color = Color(0.5, 0.68, 0.45)
	grass.uv1_scale = Vector3(20, 20, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.material = grass
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	add_child(ground)

	var hut: Node3D = load("res://assets/models/witch_hut.glb").instantiate()
	hut.position = Vector3(0, 0, -5.4)
	add_child(hut)

	_build_fence(BOUNDS.grow(0.8))
	_build_arch(ARCH_POS)
	_build_puddle(PUDDLE_POS, PUDDLE_RADIUS)

	var cam := Camera3D.new()
	cam.fov = 42.0
	add_child(cam)
	cam.position = Vector3(0, 12.0, 11.5)
	cam.look_at(Vector3(0, 0, 1.4))
	cam.current = true


func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _label3d(text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.outline_size = 14
	l.pixel_size = 0.006
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	return l


func _build_fence(r: Rect2) -> void:
	var wood := _material(Color(0.42, 0.28, 0.17))
	var step := 1.5
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y),
			Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for s in 4:
		var a: Vector2 = corners[s]
		var b: Vector2 = corners[(s + 1) % 4]
		var length := a.distance_to(b)
		var n := int(ceil(length / step))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			_box(Vector3(0.14, 0.7, 0.14), Vector3(p.x, 0.35, p.y), wood)
		var mid := (a + b) / 2.0
		var horizontal := absf(a.y - b.y) < 0.01
		for h in [0.25, 0.52]:
			var size := Vector3(length, 0.07, 0.06) if horizontal else Vector3(0.06, 0.07, length)
			_box(size, Vector3(mid.x, h, mid.y), wood)


func _build_arch(pos: Vector3) -> void:
	var mat := _material(Color(0.55, 0.38, 0.9), 0.35)
	_box(Vector3(0.3, 1.9, 0.3), pos + Vector3(0.9, 0.95, 0), mat)
	_box(Vector3(0.3, 1.9, 0.3), pos + Vector3(-0.9, 0.95, 0), mat)
	_box(Vector3(2.2, 0.32, 0.42), pos + Vector3(0, 2.05, 0), mat)
	_label3d("H", pos + Vector3(0, 2.9, 0), 120, Color(1.0, 0.92, 0.55))
	_label3d("Hadamard gate", pos + Vector3(0, 0.35, 0.9), 34, Color(0.95, 0.9, 1.0))


func _build_puddle(pos: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.42, 0.75, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.metallic = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.012, 0)
	mi.scale = Vector3(1.0, 1.0, 0.7)
	add_child(mi)
	_label3d("Z", pos + Vector3(0, 0.9, 0), 90, Color(0.7, 0.85, 1.0))
	_label3d("puddle: flips the sign", pos + Vector3(0, 0.35, radius * 0.7 + 0.35), 30, Color(0.85, 0.92, 1.0))


# ----------------------------------------------------------------- flow

func _refresh() -> void:
	for g in ghosts:
		g.set_probability(state.probability(g.index), state.amps[g.index] < -1e-6)
		var hidden: bool = g.probability < 0.001
		g.frozen = phase == Phase.OVER or (phase == Phase.INTRO and hidden)
	hud.set_state(state)


func _start_intro() -> void:
	phase = Phase.INTRO
	state.reset(0)
	_refresh()
	hud.show_message("The cat is solid: one definite place, like qubits in state |00⟩.\nWatch it walk through the Hadamard gate…", 4.0)
	await get_tree().create_timer(1.0).timeout
	ghosts[0].walk_to(ARCH_POS + Vector3(0, 0, 1.8))
	ghosts[0].arrived.connect(_split_from.bind(0, true), CONNECT_ONE_SHOT)


## Apply H to every qubit. From a solid cat this makes 2^n equally likely ghosts.
func _split_from(k: int, first_time: bool) -> void:
	var origin: Vector3 = ghosts[k].position
	state.h_all()
	phase = Phase.PLAY
	solid_index = -1
	var n := ghosts.size()
	for g in ghosts:
		g.position = origin
		g.note = ""
		var angle := TAU * float(g.index) / n + 0.5
		g.burst(Vector3(cos(angle), 0, sin(angle)))
	_refresh()
	drawer.set_enabled(true)
	if first_time:
		hud.show_message("Hadamard gate → superposition! The cat is now in %d places at once (%d%% each).\nDraw a loop: closing it measures whether the cat is inside." % [n, 100 / n])
	else:
		hud.show_message("The solid cat applied a Hadamard again and split into %d ghosts." % n)


func _become_solid(k: int, message: String) -> void:
	phase = Phase.SOLID
	solid_index = k
	split_timer = split_delay
	_refresh()
	hud.show_message(message)


func _finish(won: bool, message: String) -> void:
	phase = Phase.OVER
	drawer.set_enabled(false)
	_refresh()
	if won:
		hud.show_banner("CAUGHT!", message + "\nPress R to play again")
	else:
		hud.show_banner("TIME'S UP", message + "\nPress R to play again")


func _on_loop_closed(poly: PackedVector2Array) -> void:
	if phase != Phase.PLAY and phase != Phase.SOLID:
		return
	var inside: Array = []
	for g in ghosts:
		if g.probability > 0.001 and Geometry2D.is_point_in_polygon(Vector2(g.position.x, g.position.z), poly):
			inside.append(g.index)
	if inside.is_empty():
		hud.show_message("Empty loop: 0% of the cat was inside, so this measurement changes nothing.")
		return
	var p_in := state.subset_probability(inside)
	if state.measure_subset(inside, rng):
		var k := state.measure_all(rng)
		_refresh()
		ghosts[k].note = "caught!"
		_finish(true, "Your loop held %d%% of the cat, and the measurement said: inside." % roundi(p_in * 100.0))
	else:
		_refresh()
		var b := state.basis_index()
		if b >= 0:
			_become_solid(b, "Measured: NOT inside (you had a %d%% chance). Only one possibility is left,\nso the cat is solid at %s! Catch it before it splits again." % [roundi(p_in * 100.0), LETTERS[b]])
		else:
			hud.show_message("Measured: NOT inside (you had a %d%% chance). Those possibilities vanished,\nand the remaining ghosts share the probability in their old ratio." % roundi(p_in * 100.0))


func _use_power(id: String) -> void:
	if phase != Phase.PLAY and phase != Phase.SOLID:
		return
	if cooldowns.get(id, 1.0) > 0.0:
		return
	match id:
		"peek":
			if phase == Phase.SOLID:
				hud.show_message("The cat is already solid. Nothing to peek at!")
				return
			var k := state.measure_all(rng)
			_become_solid(k, "Peek = full measurement. The superposition collapsed: the cat is definitely at %s." % LETTERS[k])
		"flip":
			if phase == Phase.SOLID:
				hud.show_message("Flip works on ghosts. Wait for the cat to split.")
				return
			state.x(0)
			_refresh()
			hud.show_message("Flip = X gate on qubit 0: A↔B and C↔D swapped their probabilities.")
		"merge":
			if phase == Phase.SOLID:
				hud.show_message("The cat is already solid. Merge works on ghosts.")
				return
			var centre := _visible_centre()
			var was_hidden := {}
			for g in ghosts:
				was_hidden[g.index] = g.probability < 0.001
			state.h_all()
			for g in ghosts:
				if was_hidden[g.index] and state.probability(g.index) > 0.001:
					g.position = centre
			var b := state.basis_index()
			if b >= 0:
				_become_solid(b, "Merge = Hadamard again. The ghosts interfered and recombined into ONE solid cat at %s!" % LETTERS[b])
			else:
				_refresh()
				hud.show_message("Merge = Hadamard again. The ghosts interfered: some possibilities grew, others cancelled out.")
		_:
			return
	cooldowns[id] = power_cooldown


func _visible_centre() -> Vector3:
	var c := Vector3.ZERO
	var w := 0.0
	for g in ghosts:
		if g.probability > 0.001:
			c += g.position * g.probability
			w += g.probability
	return c / w if w > 0.0 else Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q: _use_power("peek")
			KEY_W: _use_power("flip")
			KEY_E: _use_power("merge")
			KEY_R: get_tree().reload_current_scene()


func _process(delta: float) -> void:
	var active := phase == Phase.PLAY or phase == Phase.SOLID
	if active:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_finish(false, "The cat escaped this time.")
	hud.set_timer(time_left)

	for id in cooldowns:
		cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)
		hud.set_cooldown(id, cooldowns[id])

	# ghosts run from the cursor while the level is running
	var cursor = drawer.ground_point(get_viewport().get_mouse_position()) if active else null
	for g in ghosts:
		g.flee_from = cursor

	if phase == Phase.SOLID:
		split_timer -= delta
		ghosts[solid_index].note = "solid! splits in %d" % ceili(split_timer)
		if split_timer <= 0.0:
			_split_from(solid_index, false)

	if phase == Phase.PLAY:
		_check_puddle()


func _check_puddle() -> void:
	for g in ghosts:
		var d := Vector2(g.position.x - PUDDLE_POS.x, (g.position.z - PUDDLE_POS.z) / 0.7)
		var now_in: bool = d.length() < PUDDLE_RADIUS and g.probability > 0.001
		if now_in and not _in_puddle[g.index]:
			state.flip_sign(g.index)
			_refresh()
			hud.show_message("Ghost %s stepped in the puddle: its amplitude flipped sign (a phase flip).\nThe probabilities look the same… but it changes what Merge does!" % g.letter)
		_in_puddle[g.index] = now_in


# ------------------------------------------------------------ screenshots

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	img.save_png(_shots_dir.path_join(name))
	print("[shots] saved ", name)


func _take_screenshots() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	# 1) the intro: solid cat walking toward the Hadamard arch
	await get_tree().create_timer(1.5).timeout
	await _shot("01_intro.png")
	# 2) superposition + a loop being drawn around the two closest ghosts
	while phase != Phase.PLAY:
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	var pair := _closest_pair()
	for g in ghosts:
		g.frozen = true
	var a: Vector3 = ghosts[pair[0]].position
	var b: Vector3 = ghosts[pair[1]].position
	var centre := (a + b) / 2.0
	var radius := a.distance_to(b) / 2.0 + 1.1
	drawer.points.clear()
	for k in 34:
		var t := deg_to_rad(-60.0 + 300.0 * k / 33.0)
		drawer.points.append(centre + Vector3(cos(t) * radius, 0, sin(t) * radius * 0.8))
	hud.show_message("Drawing a loop around %s and %s: %d%% of the cat is inside.\nClosing the loop measures: is the cat inside?" % [LETTERS[pair[0]], LETTERS[pair[1]],
			roundi(state.subset_probability(pair) * 100.0)])
	await get_tree().create_timer(0.6).timeout
	await _shot("02_superposition_loop.png")
	# 3) the loop closed and missed: those two ghosts vanish, the others share 100%
	drawer.points.clear()
	drawer._flash_poly = PackedVector2Array()
	for k in 36:
		var t := deg_to_rad(10.0 * k)
		drawer._flash_poly.append(Vector2(centre.x + cos(t) * radius, centre.z + sin(t) * radius * 0.8))
	drawer._flash_t = 0.7
	state.project_subset(pair, false)
	_refresh()
	for g in ghosts:
		g.frozen = true
	hud.show_message("Measured: NOT inside (you had a 50% chance). Those possibilities vanished,\nand the remaining ghosts share the probability in their old ratio.")
	await get_tree().create_timer(0.35).timeout
	await _shot("03_after_miss.png")
	get_tree().quit()


func _closest_pair() -> Array:
	var best := [0, 1]
	var best_d := INF
	for i in ghosts.size():
		for j in range(i + 1, ghosts.size()):
			var d: float = ghosts[i].position.distance_to(ghosts[j].position)
			if d < best_d:
				best_d = d
				best = [i, j]
	return best
