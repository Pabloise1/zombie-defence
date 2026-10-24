class_name ToolButton
extends Control
signal pressed(tool: String)
var tool := ""
var label := ""
var cost := 0
var per_m := false
var active := false
var affordable := true
var unlock := 0
var locked := false
var _press := 0.0

func setup(t: String, l: String, c: int) -> void:
	tool = t
	label = l
	cost = c
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func set_state(is_active: bool, can_afford: bool) -> void:
	if is_active != active or can_afford != affordable:
		active = is_active
		affordable = can_afford
		queue_redraw()

func set_locked(v: bool) -> void:
	if v != locked:
		locked = v
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_press = 1.0
		pressed.emit(tool)
		accept_event()
		queue_redraw()
	elif e is InputEventScreenTouch and e.pressed:
		accept_event()

func _process(dt: float) -> void:
	if _press > 0.0:
		_press = maxf(0.0, _press - dt * 5.0)
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _press > 0.0:
		var k := 1.0 - 0.07 * sin(_press * PI)
		draw_set_transform(size * 0.5 * (1.0 - k), 0.0, Vector2(k, k))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.anti_aliasing = true
	if active:
		sb.bg_color = Color(Hud.ACCENT.r, Hud.ACCENT.g, Hud.ACCENT.b, 0.2)
		sb.border_color = Hud.ACCENT
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(1, 1, 1, 0.055)
		sb.border_color = Color(1, 1, 1, 0.08)
		sb.set_border_width_all(1)
	draw_style_box(sb, r)
	var dim := (not affordable and tool != "remove") or locked
	var icol := Hud.ACCENT if active else Hud.TEXT
	if dim:
		icol = Color(icol.r, icol.g, icol.b, 0.32)
	var isz := minf(r.size.x * 0.46, r.size.y * 0.38)
	var irect := Rect2(r.position.x + (r.size.x - isz) * 0.5, r.position.y + r.size.y * 0.12, isz, isz)
	Icons.draw(self, tool, irect, icol)
	var fs := 13 if r.size.x < 70 else 14
	var ly := irect.end.y + fs + 3.0
	var lcol := Hud.TEXT if not dim else Hud.MUTED
	draw_string(Hud.font_bold, Vector2(r.position.x, ly), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, lcol)
	if locked:
		var c := Vector2(r.end.x - 15, r.position.y + 15)
		draw_arc(c + Vector2(0, -3), 4.5, PI, TAU, 10, Hud.MUTED, 2.0, true)
		draw_rect(Rect2(c.x - 6, c.y - 2, 12, 9), Hud.MUTED)
		draw_string(Hud.font_heavy, Vector2(r.position.x, ly + 15), "WAVE %d" % unlock, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Hud.MUTED)
	elif cost > 0:
		var ctext := ("%d/m" % cost) if per_m else ("%d" % cost)
		var ccol := Hud.SUPPLY if affordable else Hud.DANGER
		draw_string(Hud.font_heavy, Vector2(r.position.x, ly + 15), ctext, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, ccol)
	elif tool == "remove":
		draw_string(Hud.font_bold, Vector2(r.position.x, ly + 15), "refund", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Hud.MUTED)
