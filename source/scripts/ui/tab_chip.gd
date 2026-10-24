class_name TabChip
extends Control
signal pressed(id: String)
var id := ""
var label := ""
var active := false
var _press := 0.0

func setup(i: String, l: String) -> void:
	id = i
	label = l
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func set_active(v: bool) -> void:
	if v != active:
		active = v
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_press = 1.0
		pressed.emit(id)
		accept_event()
	elif e is InputEventScreenTouch:
		accept_event()

func _process(dt: float) -> void:
	if _press > 0.0:
		_press = maxf(0.0, _press - dt * 5.0)
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-1.0)
	if _press > 0.0:
		var k := 1.0 - 0.06 * sin(_press * PI)
		draw_set_transform(size * 0.5 * (1.0 - k), 0.0, Vector2(k, k))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.anti_aliasing = true
	sb.bg_color = Color(Hud.ACCENT.r, Hud.ACCENT.g, Hud.ACCENT.b, 0.95) if active else Color(1, 1, 1, 0.045)
	draw_style_box(sb, r)
	var col := Hud.ACCENT_DK if active else Hud.MUTED
	var icon := Icons.for_tab(id)
	var narrow := r.size.x < 78.0
	var isz := 16.0
	if narrow:
		Icons.draw(self, icon, Rect2(r.position.x + (r.size.x - isz) * 0.5, r.position.y + 4.0, isz, isz), col)
		var fs := 10
		while fs > 8 and Hud.font_heavy.get_string_size(label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 4.0:
			fs -= 1
		draw_string(Hud.font_heavy, Vector2(r.position.x, r.end.y - 6.0), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
		return
	var fs2 := 13
	var tw := Hud.font_heavy.get_string_size(label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	while fs2 > 10 and tw + isz + 6.0 > r.size.x - 10.0:
		fs2 -= 1
		tw = Hud.font_heavy.get_string_size(label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var x0 := r.position.x + (r.size.x - (tw + isz + 6.0)) * 0.5
	Icons.draw(self, icon, Rect2(x0, r.position.y + (r.size.y - isz) * 0.5, isz, isz), col)
	draw_string(Hud.font_heavy, Vector2(x0 + isz + 6.0, r.position.y + r.size.y * 0.5 + fs2 * 0.36), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, col)
