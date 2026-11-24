extends CanvasLayer
## On-screen UI for the quantum cat game, built in code:
## title, timer, the cat's quantum state panel, power-up bar, message line and end banner.

signal power_pressed(id: String)

const POWERS := [
	# id, key, name, what it is
	["peek", "Q", "Peek", "full measurement"],
	["flip", "W", "Flip", "X gate"],
	["merge", "E", "Merge", "Hadamard again"],
	["trap", "R", "Cat trap", "Grover · locked"],
]

var _timer_label: Label
var _rows := []                 # per basis state: [bar, percent label, amplitude label]
var _ket: Label
var _message: Label
var _message_panel: PanelContainer
var _message_t := 0.0
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _buttons := {}              # id -> Button


func build(state, letters: String, level_text: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- title (top left)
	var title_panel := _panel(root)
	title_panel.position = Vector2(16, 16)
	var tv := VBoxContainer.new()
	title_panel.add_child(tv)
	tv.add_child(_label("CATCH THE CAT!", 30, Color(1.0, 0.9, 0.55)))
	tv.add_child(_label(level_text, 16, Color(0.85, 0.85, 0.95)))
	tv.add_child(_label("Hold the left mouse button and draw a loop.\nClosing the loop measures: is the cat inside?", 14, Color(0.75, 0.75, 0.85)))
	_timer_label = _label("Time  1:30", 26, Color.WHITE)
	tv.add_child(_timer_label)

	# --- quantum state (top right)
	var state_panel := _panel(root)
	state_panel.anchor_left = 1.0
	state_panel.anchor_right = 1.0
	state_panel.offset_left = -360
	state_panel.offset_right = -16
	state_panel.offset_top = 16
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	state_panel.add_child(sv)
	sv.add_child(_label("The cat's quantum state", 18, Color(1.0, 0.9, 0.55)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	sv.add_child(grid)
	for i in state.size():
		grid.add_child(_label("%s  |%s⟩" % [letters[i], state.label(i)], 16, Color.WHITE))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 16)
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.62, 0.5, 1.0)
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		grid.add_child(bar)
		var pct := _label("0%", 16, Color.WHITE)
		pct.custom_minimum_size.x = 48
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(pct)
		var amp := _label("+0.00", 14, Color(0.7, 0.7, 0.8))
		grid.add_child(amp)
		_rows.append([bar, pct, amp])
	sv.add_child(HSeparator.new())
	_ket = _label("", 14, Color(0.85, 0.85, 1.0))
	_ket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ket.custom_minimum_size.x = 320
	sv.add_child(_ket)
	sv.add_child(_label("bar / brightness = probability (amplitude²)\npink = negative amplitude", 12, Color(0.65, 0.65, 0.75)))

	# --- power-up bar (bottom right)
	var bar_box := HBoxContainer.new()
	bar_box.anchor_left = 1.0
	bar_box.anchor_right = 1.0
	bar_box.anchor_top = 1.0
	bar_box.anchor_bottom = 1.0
	bar_box.offset_left = -568
	bar_box.offset_right = -16
	bar_box.offset_top = -86
	bar_box.offset_bottom = -16
	bar_box.alignment = BoxContainer.ALIGNMENT_END
	bar_box.add_theme_constant_override("separation", 8)
	root.add_child(bar_box)
	for p in POWERS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 70)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.set_meta("base_text", "[%s]  %s\n%s" % [p[1], p[2], p[3]])
		b.text = b.get_meta("base_text")
		b.pressed.connect(func(): power_pressed.emit(p[0]))
		if p[0] == "trap":
			b.disabled = true
		bar_box.add_child(b)
		_buttons[p[0]] = b

	# --- message line (bottom left)
	_message_panel = _panel(root)
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.anchor_top = 1.0
	_message_panel.anchor_bottom = 1.0
	_message_panel.offset_left = 16
	_message_panel.offset_right = 576
	_message_panel.offset_top = -86
	_message_panel.offset_bottom = -16
	_message_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_message = _label("", 15, Color.WHITE)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message)
	_message_panel.visible = false

	# --- end banner (centre)
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = -90
	_banner.offset_bottom = 60
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = _label("", 72, Color(1.0, 0.9, 0.55))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_constant_override("outline_size", 18)
	_banner_title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	_banner_sub = _label("", 20, Color.WHITE)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.add_theme_constant_override("outline_size", 10)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_sub)
	_banner.visible = false
	root.add_child(_banner)


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.13, 0.78)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ------------------------------------------------------------------ updates

func set_timer(seconds: float) -> void:
	var s := int(ceil(seconds))
	_timer_label.text = "Time  %d:%02d" % [s / 60, s % 60]
	_timer_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45) if seconds < 10.0 else Color.WHITE)


func set_state(state) -> void:
	for i in _rows.size():
		var p: float = state.probability(i)
		var a: float = state.amps[i]
		_rows[i][0].value = p * 100.0
		_rows[i][1].text = "%d%%" % roundi(p * 100.0)
		_rows[i][2].text = ("−" if a < -1e-6 else "+") + "%.2f" % absf(a)
		_rows[i][2].add_theme_color_override("font_color",
				Color(1.0, 0.6, 0.72) if a < -1e-6 else Color(0.7, 0.7, 0.8))
	_ket.text = state.ket_string()


func set_cooldown(id: String, remaining: float) -> void:
	var b: Button = _buttons.get(id)
	if b == null or id == "trap":
		return
	b.disabled = remaining > 0.0
	b.text = b.get_meta("base_text") if remaining <= 0.0 else "%s (%ds)" % [b.get_meta("base_text").split("\n")[0], ceili(remaining)] + "\n" + b.get_meta("base_text").split("\n")[1]


func show_message(text: String, seconds: float = 7.0) -> void:
	_message.text = text.replace("
", " ")   # the panel wraps lines itself
	_message_panel.visible = true
	_message_t = seconds


func show_banner(title: String, sub: String) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	_banner.visible = true


func _process(delta: float) -> void:
	if _message_t > 0.0:
		_message_t -= delta
		if _message_t <= 0.0:
			_message_panel.visible = false
