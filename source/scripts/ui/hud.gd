class_name Hud
extends CanvasLayer
signal tool_pressed(tool: String)
signal start_wave_pressed
signal play_pressed
signal continue_pressed
signal restart_pressed
signal card_action(id: String, target)
signal plan_done
signal plan_undo
signal confirm_pressed
signal cancel_pressed
signal undo_last_pressed
signal settings_pressed
signal map_picked(id: String)
const PANEL := Color(0.055, 0.068, 0.06, 0.84)
const PANEL_HI := Color(1, 1, 1, 0.07)
const PANEL_EDGE := Color(1, 1, 1, 0.1)
const TEXT := Color(0.96, 0.95, 0.89)
const MUTED := Color(0.64, 0.67, 0.6)
const ACCENT := Color(0.97, 0.65, 0.22)
const ACCENT_DK := Color(0.13, 0.085, 0.03)
const DANGER := Color(0.93, 0.33, 0.26)
const OK := Color(0.47, 0.86, 0.47)
const SUPPLY := Color(0.99, 0.82, 0.38)
const GUTTER := 12.0
const BAR_H := 40.0
const ANIM := 0.18

static var font: Font

static var font_bold: Font

static var font_heavy: Font

class Painter extends Control:
	var paint: Callable
	var on_press: Callable
	var on_press_at: Callable
	var press_fx := 0.0
	var bounce := true
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
	func _draw() -> void:
		if bounce and press_fx > 0.0:
			var k := 1.0 - 0.06 * sin(press_fx * PI)
			draw_set_transform(size * 0.5 * (1.0 - k), 0.0, Vector2(k, k))
		if paint.is_valid():
			paint.call(self, Rect2(Vector2.ZERO, size))
	func _process(dt: float) -> void:
		if press_fx > 0.0:
			press_fx = maxf(0.0, press_fx - dt * 5.0)
			queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if on_press_at.is_valid() or on_press.is_valid():
				press_fx = 1.0
			if on_press_at.is_valid():
				on_press_at.call(e.position)
			elif on_press.is_valid():
				on_press.call()
			accept_event()
		elif e is InputEventScreenTouch:
			accept_event()
var root: Control
var overlay: WorldOverlay
var stats: Painter
var wave_chip: Painter
var settings_btn: Painter
var goal_chip: Painter
var build_btn: Painter
var start_btn: Painter
var sheet: Painter
var tool_chip: Painter
var ok_btn: Painter
var x_btn: Painter
var undo_btn: Painter
var done_btn: Painter
var undo_last_btn: Painter
var toast_layer: Painter
var banner: Painter
var title_card: Painter
var over_card: Painter
var fps_label: Label
var buttons: Array[ToolButton] = []
var tabs: Array[TabChip] = []
var card: InfoCard
var tab := "defend"
var safe := Rect2()
var compact := false
var portrait := false
var supplies := 0
var _shown_supplies := 0.0
var _shown_crates := 0.0
var _shown_people := 0.0
var _gain := 0
var _gain_t := 0.0
var wave := 1
var phase := "build"
var phase_time := 0.0
var zombies_left := 0
var hq_frac := 1.0
var _hq_hit_t := 0.0
var people := 0
var idle_people := 0
var pop_cap := 10
var crates := 0
var crate_cap := 10
var goal := ""
var tool := ""
var _hint_text := ""
var _pulse := 0.0
var _over_waves := 0
var _over_kills := 0
var _plan_points := 0
var _sheet_open := false
var _sheet_k := 0.0
var _card_k := 0.0
var _row_k := 1.0
var _chip_k := 0.0
var _toasts: Array = []
var _banners: Array = []
var _banner_age := -1.0
var _cur_banner: Array = []

static func health_color(f: float) -> Color:
	if f > 0.6:
		return OK
	if f > 0.3:
		return ACCENT
	return DANGER

static func _make_fonts() -> void:
	if font != null:
		return
	font = ThemeDB.fallback_font
	var b := FontVariation.new()
	b.base_font = font
	b.variation_embolden = 0.6
	font_bold = b
	var h := FontVariation.new()
	h.base_font = font
	h.variation_embolden = 1.1
	h.spacing_glyph = 1
	font_heavy = h

static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func _ready() -> void:
	layer = 10
	_make_fonts()
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	overlay = WorldOverlay.new()
	root.add_child(overlay)
	stats = _painter(_paint_stats)
	stats.bounce = false
	wave_chip = _painter(_paint_wave)
	wave_chip.bounce = false
	goal_chip = _painter(_paint_goal)
	goal_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_btn = _painter(_paint_settings, func(): settings_pressed.emit())
	build_btn = _painter(_paint_build, _toggle_sheet)
	start_btn = _painter(_paint_start, func(): start_wave_pressed.emit())
	sheet = _painter(_paint_sheet)
	sheet.bounce = false
	sheet.on_press_at = _sheet_press
	for tdef in Defs.TABS:
		var tc := TabChip.new()
		tc.setup(String(tdef["id"]), String(tdef["name"]))
		tc.pressed.connect(set_tab)
		sheet.add_child(tc)
		tabs.append(tc)
	for t in Defs.TOOLS + ["remove"]:
		var b := ToolButton.new()
		var d: Dictionary = Defs.BUILD.get(t, {})
		var linear: bool = d.has("per_m") and bool(d.get("linear", false))
		b.setup(t, String(d.get("name", "Remove")), int(d["per_m"]) if linear else int(d.get("cost", 0)))
		b.per_m = linear
		b.unlock = int(d.get("unlock", 0))
		b.pressed.connect(func(tt): tool_pressed.emit(tt))
		sheet.add_child(b)
		buttons.append(b)
	tool_chip = _painter(_paint_tool_chip)
	tool_chip.bounce = false
	tool_chip.on_press_at = _tool_chip_press
	undo_btn = _painter(_paint_undo, func(): plan_undo.emit())
	done_btn = _painter(_paint_done, func(): plan_done.emit())
	undo_btn.visible = false
	done_btn.visible = false
	undo_last_btn = _painter(_paint_undo_last, func(): undo_last_pressed.emit())
	undo_last_btn.visible = false
	ok_btn = _painter(_paint_ok, func(): confirm_pressed.emit())
	x_btn = _painter(_paint_x, func(): cancel_pressed.emit())
	ok_btn.visible = false
	x_btn.visible = false
	card = InfoCard.new()
	card.action.connect(func(id, t): card_action.emit(id, t))
	root.add_child(card)
	toast_layer = _painter(_paint_toasts)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = _painter(_paint_banner)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	title_card = _painter(_paint_title)
	title_card.bounce = false
	title_card.on_press_at = _title_press
	over_card = _painter(_paint_over, func(): restart_pressed.emit())
	over_card.visible = false
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 12)
	fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	fps_label.visible = false
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _painter(paint: Callable, press: Callable = Callable()) -> Painter:
	var p := Painter.new()
	p.paint = paint
	p.on_press = press
	root.add_child(p)
	return p

func set_safe_insets(l: float, t: float, r: float, b: float) -> void:
	safe = Rect2(l, t, r, b)
	_layout()
var L := 0.0
var T := 0.0
var R := 0.0
var B := 0.0
var vs := Vector2.ZERO

func _layout() -> void:
	vs = get_viewport().get_visible_rect().size
	compact = vs.x < 640.0
	portrait = vs.y > vs.x * 1.05
	L = safe.position.x + GUTTER
	T = safe.position.y + 10.0
	R = vs.x - safe.size.x - GUTTER
	B = vs.y - safe.size.y - 12.0
	var bh0 := _bar_h()
	stats.size = Vector2(_stats_width(), bh0)
	stats.position = Vector2(L, T)
	settings_btn.size = Vector2(bh0, bh0)
	settings_btn.position = Vector2(R - bh0, T)
	var ww := 116.0 if compact else 156.0
	wave_chip.size = Vector2(ww, bh0)
	if vs.x * 0.5 - ww * 0.5 > stats.position.x + stats.size.x + 8.0 and vs.x * 0.5 + ww * 0.5 < settings_btn.position.x - 8.0:
		wave_chip.position = Vector2(vs.x * 0.5 - ww * 0.5, T)
	else:
		wave_chip.position = Vector2(settings_btn.position.x - 6.0 - ww, T)
	var gw := font_bold.get_string_size(goal, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36.0 if goal != "" else 0.0
	goal_chip.size = Vector2(minf(gw, R - L), 32.0)
	goal_chip.position = Vector2(vs.x * 0.5 - goal_chip.size.x * 0.5, T + bh0 + 8.0)
	goal_chip.visible = goal != "" and phase == "build" and not title_card.visible
	var bh := 56.0
	var show_start := phase == "build"
	var bw := 148.0
	var sw := 150.0
	var gap := 10.0
	var row_w := bw + (gap + sw if show_start else 0.0)
	var x0 := vs.x * 0.5 - row_w * 0.5
	build_btn.size = Vector2(bw, bh)
	build_btn.position = Vector2(x0, B - bh + (1.0 - _row_k) * 90.0)
	start_btn.size = Vector2(sw, bh)
	start_btn.position = Vector2(x0 + bw + gap, B - bh + (1.0 - _row_k) * 90.0)
	var land := not portrait and vs.y < 520.0
	var shw := minf(R - L, 520.0 if land else 560.0)
	var n := 5
	var tgap := 8.0
	var pad := 12.0
	var tbw := clampf((shw - pad * 2.0 - tgap * (n - 1)) / n, 58.0, 96.0)
	shw = tbw * n + tgap * (n - 1) + pad * 2.0
	var tbh := clampf(tbw * 1.08, 68.0, 92.0)
	var th := 40.0
	if land:
		tbh = 64.0
		th = 34.0
	var handle := 18.0
	var shh := handle + th + 10.0 + tbh + pad + 4.0
	sheet.size = Vector2(shw, shh)
	var k := ease_out(_sheet_k)
	sheet.position = Vector2(vs.x * 0.5 - shw * 0.5, lerpf(vs.y + 10.0, B - shh, k))
	sheet.modulate.a = clampf(_sheet_k * 1.6, 0.0, 1.0)
	sheet.visible = _sheet_k > 0.001
	var tw := (shw - pad * 2.0 - 6.0 * (tabs.size() - 1)) / tabs.size()
	for i in tabs.size():
		tabs[i].position = Vector2(pad + i * (tw + 6.0), handle)
		tabs[i].size = Vector2(tw, th)
		tabs[i].set_active(tabs[i].id == tab)
		tabs[i].queue_redraw()
	var shown: Array = _tab_tools(tab)
	var rw := tbw * shown.size() + tgap * (shown.size() - 1)
	var bx0 := (shw - rw) * 0.5
	for b in buttons:
		var kk := shown.find(b.tool)
		b.visible = kk >= 0
		if kk >= 0:
			b.position = Vector2(bx0 + kk * (tbw + tgap), handle + th + 10.0)
			b.size = Vector2(tbw, tbh)
			b.queue_redraw()
	var narrow_chip := R - L < 470.0
	var cw := minf(R - L - (0.0 if narrow_chip else 124.0), 340.0)
	tool_chip.size = Vector2(cw, 56.0)
	tool_chip.position = Vector2(vs.x * 0.5 - cw * 0.5, B - 56.0 + (1.0 - ease_out(_chip_k)) * 80.0)
	tool_chip.modulate.a = clampf(_chip_k * 1.5, 0.0, 1.0)
	tool_chip.visible = _chip_k > 0.001
	undo_btn.size = Vector2(52.0, 52.0)
	undo_btn.position = Vector2(maxf(L, tool_chip.position.x - 60.0), B - 54.0)
	if narrow_chip:
		undo_btn.position = Vector2(tool_chip.position.x, B - 56.0 - 60.0)
	done_btn.size = Vector2(52.0, 52.0)
	done_btn.position = Vector2(tool_chip.position.x + cw + 8.0, B - 54.0)
	undo_last_btn.size = Vector2(112.0, 44.0)
	undo_last_btn.position = Vector2(L, B - 56.0 - 52.0)
	ok_btn.size = Vector2(60, 60)
	x_btn.size = Vector2(48, 48)
	_layout_card()
	toast_layer.size = Vector2(minf(R - L, 440.0), 90.0)
	toast_layer.position = Vector2(vs.x * 0.5 - toast_layer.size.x * 0.5, T + bh0 + 8.0 + (40.0 if goal_chip.visible else 0.0))
	banner.size = Vector2(minf(560.0, vs.x - 20.0), 110.0)
	banner.position = Vector2(vs.x * 0.5 - banner.size.x * 0.5, vs.y * (0.24 if portrait else 0.26) - 30.0)
	var tcw := minf(460.0, vs.x - 32.0)
	title_card.size = Vector2(tcw, 440.0 + (70.0 if not save_info.is_empty() else 0.0))
	title_card.position = (vs - title_card.size) * 0.5
	over_card.size = Vector2(tcw, 230.0)
	over_card.position = (vs - over_card.size) * 0.5
	fps_label.position = Vector2(L, T + BAR_H + 6.0)
	for c in [stats, wave_chip, goal_chip, build_btn, start_btn, sheet, tool_chip, toast_layer, banner, title_card, over_card, undo_btn, done_btn, ok_btn, x_btn, undo_last_btn, settings_btn]:
		c.queue_redraw()

func _layout_card() -> void:
	var want := card.wanted_height()
	var k := ease_out(_card_k)
	if portrait or vs.x < 640.0:
		var w := minf(R - L, 520.0)
		card.size = Vector2(w, want)
		card.position = Vector2(vs.x * 0.5 - w * 0.5, B - want + (1.0 - k) * (want + 30.0))
		card.modulate.a = clampf(_card_k * 2.0, 0.0, 1.0)
		card.popover = false
	else:
		var w2 := clampf(vs.x * 0.5, 360.0, 460.0)
		card.size = Vector2(w2, want)
		var anchor := Vector2(vs.x * 0.62, vs.y * 0.5)
		if G.builder and G.cam and G.builder.sel_point != Vector3.INF and not G.cam.cam.is_position_behind(G.builder.sel_point):
			anchor = G.cam.cam.unproject_position(G.builder.sel_point)
		var x := anchor.x + 46.0
		if x + w2 > R:
			x = anchor.x - 46.0 - w2
		x = clampf(x, L, R - w2)
		var y := clampf(anchor.y - want * 0.5, T + BAR_H + 10.0, B - want)
		card.position = Vector2(x, y + (1.0 - k) * 14.0)
		card.modulate.a = clampf(_card_k * 1.6, 0.0, 1.0)
		card.popover = true
		card.anchor = anchor - card.position

func relayout() -> void:
	_layout()

func _bar_h() -> float:
	return 36.0 if compact else BAR_H

func _isz() -> float:
	return 15.0 if compact else 18.0

func _nfs() -> int:
	return 15 if compact else 16

func _stats_width() -> float:
	var ig := _isz() + 5.0
	var sep := 12.0 if compact else 14.0
	var w := 12.0
	w += ig + _num_w("%d" % int(round(_shown_supplies))) + sep
	w += ig + _num_w("%d" % crates) + sep
	w += ig + _num_w("%d/%d" % [people, pop_cap]) + 9.0
	return w + 8.0

func _num_w(s: String) -> float:
	return font_heavy.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _nfs()).x

func _tab_tools(id: String) -> Array:
	for tdef in Defs.TABS:
		if tdef["id"] == id:
			return tdef["tools"]
	return []

func set_tab(id: String) -> void:
	if id != tab and G.sfx:
		G.sfx.play_ui("ui_tap")
	tab = id
	_layout()

func _toggle_sheet() -> void:
	if phase == "over" or phase == "title":
		return
	_sheet_open = not _sheet_open
	if _sheet_open:
		if card.visible and G.builder:
			G.builder.select(null)
		if tool != "":
			tool_pressed.emit(tool)
	if G.sfx:
		G.sfx.play_ui("ui_open" if _sheet_open else "ui_close")

func close_sheet() -> void:
	_sheet_open = false

func _sheet_press(p: Vector2) -> void:
	if p.y < 22.0 or (p.x > sheet.size.x - 46.0 and p.y < 22.0):
		close_sheet()
		if G.sfx:
			G.sfx.play_ui("ui_close")

func _tool_chip_press(p: Vector2) -> void:
	if p.x > tool_chip.size.x - 56.0:
		tool_pressed.emit(tool)
	else:
		var t := tool
		tool_pressed.emit(t)
		_sheet_open = true

func show_card(t) -> void:
	card.show_for(t)
	_sheet_open = false
	_layout()

func set_people(total: int, idle: int, cap: int = 10) -> void:
	if total != people or idle != idle_people or cap != pop_cap:
		people = total
		idle_people = idle
		pop_cap = cap
		_layout()

func set_crates(n: int, cap: int) -> void:
	if n != crates or cap != crate_cap:
		crates = n
		crate_cap = cap
		stats.queue_redraw()

func set_goal(t: String) -> void:
	if t != goal:
		goal = t
		_layout()

func set_plan(active: bool, points: int) -> void:
	_plan_points = points if active else 0
	undo_btn.visible = active and points > 0
	done_btn.visible = false

func place_confirm(anchor: Vector2, show: bool, ok: bool) -> void:
	ok_btn.visible = show
	x_btn.visible = show
	if not show:
		return
	var p := anchor + Vector2(52, -40)
	var top := T + BAR_H + 52.0
	var bottom := B - 70.0
	p.x = clampf(p.x, L, R - 60.0)
	p.y = clampf(p.y, top, bottom - 66.0)
	if ok_btn.position.distance_to(p) > 0.5 or ok_btn.get_meta("ok", true) != ok:
		ok_btn.position = p
		x_btn.position = p + Vector2(6, 68)
		ok_btn.set_meta("ok", ok)
		ok_btn.queue_redraw()
		x_btn.queue_redraw()

func set_undo_last(t: float) -> void:
	var show := t > 0.0
	if show != undo_last_btn.visible:
		undo_last_btn.visible = show
	if show:
		undo_last_btn.set_meta("t", t)
		undo_last_btn.queue_redraw()

func hide_card() -> void:
	card.hide_card()

func is_over_ui(p: Vector2) -> bool:
	for c in [stats, wave_chip, settings_btn, build_btn, start_btn, sheet, tool_chip, title_card, over_card, card, undo_btn, done_btn, ok_btn, x_btn, undo_last_btn]:
		if c.visible and c.modulate.a > 0.05 and c.get_global_rect().grow(4.0).has_point(p):
			return true
	return false

func set_state(s: int, w: int, ph: String, t: float, left: int, hq: float) -> void:
	if s > supplies and supplies > 0:
		_gain += s - supplies
		_gain_t = 1.2
	supplies = s
	if w != wave or ph != phase:
		wave = w
		phase = ph
		_layout()
	if absf(t - phase_time) > 0.2 or left != zombies_left:
		phase_time = t
		zombies_left = left
		wave_chip.queue_redraw()
	if absf(hq - hq_frac) > 0.001:
		if hq < hq_frac:
			_hq_hit_t = 0.6
		hq_frac = hq
		wave_chip.queue_redraw()
	for b in buttons:
		b.set_state(b.tool == tool, b.cost <= supplies)
		b.set_locked(b.unlock > wave)

func set_tool(t: String, hint_text: String) -> void:
	tool = t
	if t != "":
		_sheet_open = false
		hide_card()
		for tdef in Defs.TABS:
			if (tdef["tools"] as Array).has(t) and tdef["id"] != tab:
				tab = String(tdef["id"])
	_hint_text = hint_text
	tool_chip.queue_redraw()
	for b in buttons:
		b.set_state(b.tool == tool, b.cost <= supplies)
	_layout()
var _event_t := {}

func event(key: String, text: String, gap: float = 8.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_event_t.get(key, -100.0)) < gap:
		return
	_event_t[key] = now
	toast(text)

func toast(text: String) -> void:
	var danger := text.ends_with("!") or text.begins_with("Not ") or text.contains("can't") or text.contains("Can't") or text.contains("costs") or text.contains("caught")
	for x in _toasts:
		if x[0] == text:
			x[1] = minf(x[1], 0.2)
			return
	_toasts.append([text, 0.0, danger, clampf(2.0 + text.length() / 22.0, 2.4, 5.0)])
	while _toasts.size() > 2:
		_toasts.pop_front()
	toast_layer.queue_redraw()

func show_banner(title: String, sub: String, col: Color = DANGER) -> void:
	if not _cur_banner.is_empty() and _cur_banner[0] == title:
		_cur_banner = [title, sub, col]
		_banner_age = minf(_banner_age, 0.3)
		return
	for x in _banners:
		if x[0] == title:
			return
	_banners.append([title, sub, col])
	if _banners.size() > 3:
		_banners.pop_front()

func show_title(on: bool) -> void:
	title_card.visible = on
	for c in [stats, wave_chip, settings_btn]:
		c.visible = not on
	settings_btn.visible = true
	_layout()

func show_game_over(waves: int, kills: int) -> void:
	_over_waves = waves
	_over_kills = kills
	over_card.visible = true
	_sheet_open = false
	over_card.queue_redraw()

func hide_game_over() -> void:
	over_card.visible = false

func _process(dt: float) -> void:
	_pulse += dt
	var relayout_needed := false
	var target := float(supplies)
	if absf(_shown_supplies - target) > 0.5:
		_shown_supplies = move_toward(_shown_supplies, target, maxf(60.0, absf(target - _shown_supplies) * 6.0) * dt)
		stats.queue_redraw()
	elif _shown_supplies != target:
		_shown_supplies = target
		stats.queue_redraw()
		relayout_needed = true
	if absf(_shown_crates - crates) > 0.01:
		_shown_crates = move_toward(_shown_crates, crates, maxf(4.0, absf(crates - _shown_crates) * 8.0) * dt)
		stats.queue_redraw()
	if absf(_shown_people - people) > 0.01:
		_shown_people = move_toward(_shown_people, people, maxf(4.0, absf(people - _shown_people) * 8.0) * dt)
		stats.queue_redraw()
	if _gain_t > 0.0:
		_gain_t -= dt
		stats.queue_redraw()
		if _gain_t <= 0.0:
			_gain = 0
	if _hq_hit_t > 0.0:
		_hq_hit_t -= dt
		wave_chip.queue_redraw()
	var in_game := not title_card.visible and not over_card.visible
	var card_on := card.visible
	var want_sheet := 1.0 if _sheet_open and in_game and not card_on else 0.0
	var want_chip := 1.0 if tool != "" and in_game and not card_on and not _sheet_open else 0.0
	var want_card := 1.0 if card_on else 0.0
	var want_row := 1.0 if in_game and not card_on and tool == "" and not _sheet_open else 0.0
	var step := dt / ANIM
	var moved := false
	for pair in [["_sheet_k", want_sheet], ["_chip_k", want_chip], ["_card_k", want_card], ["_row_k", want_row]]:
		var cur: float = get(pair[0])
		if cur != pair[1]:
			set(pair[0], move_toward(cur, pair[1], step))
			moved = true
	build_btn.visible = _row_k > 0.01
	start_btn.visible = _row_k > 0.01 and phase == "build"
	build_btn.modulate.a = clampf(_row_k * 1.5, 0.0, 1.0)
	start_btn.modulate.a = build_btn.modulate.a
	undo_btn.visible = _plan_points > 0 and _chip_k > 0.5
	if moved or relayout_needed:
		_layout()
	elif card.visible and not (portrait or vs.x < 640.0):
		_layout_card()
	if not _toasts.is_empty():
		for x in _toasts:
			x[1] += dt
		while not _toasts.is_empty() and _toasts[0][1] > _toasts[0][3]:
			_toasts.pop_front()
		toast_layer.queue_redraw()
	if _banner_age < 0.0 and not _banners.is_empty():
		_cur_banner = _banners.pop_front()
		_banner_age = 0.0
	if _banner_age >= 0.0:
		_banner_age += dt
		banner.visible = true
		var fin := clampf(_banner_age / 0.22, 0.0, 1.0)
		var fout := clampf((2.6 - _banner_age) / 0.45, 0.0, 1.0)
		banner.modulate.a = minf(fin, fout)
		var sc := lerpf(0.9, 1.0, ease_out(fin))
		banner.scale = Vector2(sc, sc)
		banner.pivot_offset = banner.size * 0.5
		banner.queue_redraw()
		if _banner_age > 2.6:
			_banner_age = -1.0
			banner.visible = false
	if start_btn.visible:
		start_btn.queue_redraw()
	if fps_label.visible:
		fps_label.text = "%d fps  %d zombies" % [Engine.get_frames_per_second(), G.zombies.alive_count if G.zombies else 0]

func toggle_fps() -> void:
	fps_label.visible = not fps_label.visible

static func glass(ci: CanvasItem, r: Rect2, radius: float = 16.0, col: Color = PANEL, edge: Color = PANEL_EDGE, shadow := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.28)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 3)
	ci.draw_style_box(sb, r)
	var hi := StyleBoxFlat.new()
	hi.bg_color = PANEL_HI
	hi.corner_radius_top_left = int(radius)
	hi.corner_radius_top_right = int(radius)
	hi.anti_aliasing = true
	ci.draw_style_box(hi, Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, minf(r.size.y * 0.45, 18.0))))

static func pill(ci: CanvasItem, r: Rect2, col: Color, edge: Color = Color(0, 0, 0, 0), radius: float = -1.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r.size.y * 0.5 if radius < 0.0 else radius))
	sb.anti_aliasing = true
	if edge.a > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(1)
	ci.draw_style_box(sb, r)

static func text(ci: CanvasItem, p: Vector2, s: String, size: int, col: Color, f: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	ci.draw_string(f if f else font_bold, p, s, align, w, size, col)

func _paint_stats(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, r.size.y * 0.5)
	var x := r.position.x + 12.0
	var cy := r.position.y + r.size.y * 0.5
	var isz := _isz()
	var fs := _nfs()
	var half_sep := 6.0 if compact else 7.0
	Icons.draw(ci, "supplies", Rect2(x, cy - isz * 0.5, isz, isz), SUPPLY)
	x += isz + 5.0
	var st := "%d" % int(round(_shown_supplies))
	text(ci, Vector2(x, cy + fs * 0.36), st, fs, TEXT, font_heavy)
	x += _num_w(st) + half_sep
	ci.draw_line(Vector2(x, cy - 9.0), Vector2(x, cy + 9.0), Color(1, 1, 1, 0.12), 1.0)
	x += half_sep
	Icons.draw(ci, "crate", Rect2(x, cy - isz * 0.5, isz, isz), Color(0.62, 0.68, 0.38) if crates > 0 else DANGER)
	x += isz + 5.0
	var ct := "%d" % int(round(_shown_crates))
	text(ci, Vector2(x, cy + fs * 0.36), ct, fs, TEXT if crates > 0 else DANGER, font_heavy)
	x += _num_w(ct) + half_sep
	ci.draw_line(Vector2(x, cy - 9.0), Vector2(x, cy + 9.0), Color(1, 1, 1, 0.12), 1.0)
	x += half_sep
	Icons.draw(ci, "person", Rect2(x, cy - isz * 0.5, isz, isz), TEXT)
	x += isz + 5.0
	var pt := "%d/%d" % [int(round(_shown_people)), pop_cap]
	text(ci, Vector2(x, cy + fs * 0.36), pt, fs, TEXT, font_heavy)
	x += _num_w(pt) + 3.0
	if idle_people > 0:
		ci.draw_circle(Vector2(x + 3.0, cy - 8.0), 4.0, SUPPLY)
	if _gain > 0 and _gain_t > 0.0:
		var a := clampf(_gain_t / 0.5, 0.0, 1.0)
		var rise := (1.2 - _gain_t) * 8.0
		text(ci, Vector2(r.position.x + 16.0, r.end.y + 18.0 - rise), "+%d" % _gain, 15, Color(OK.r, OK.g, OK.b, a), font_heavy)

func _paint_wave(ci: CanvasItem, r: Rect2) -> void:
	var danger := phase == "wave"
	var hit := _hq_hit_t > 0.0
	glass(ci, r, r.size.y * 0.5, PANEL, Color(DANGER.r, DANGER.g, DANGER.b, 0.75) if hit else (Color(DANGER.r, DANGER.g, DANGER.b, 0.35) if danger else PANEL_EDGE))
	var cy := r.position.y + r.size.y * 0.5
	text(ci, Vector2(r.position.x + 14.0, cy - 2.0), "WAVE %d" % wave, 10, DANGER if danger else MUTED, font_heavy)
	var main_s := ""
	var icon := "clock"
	if phase == "build":
		var t := int(ceil(phase_time))
		main_s = "%d:%02d" % [t / 60, t % 60]
	elif phase == "wave":
		main_s = "%d left" % zombies_left
		icon = "zombie"
	elif phase == "over":
		main_s = "HQ lost"
		icon = "hq"
	Icons.draw(ci, icon, Rect2(r.position.x + 14.0, cy + 1.0, 12.0, 12.0), DANGER if danger else MUTED)
	text(ci, Vector2(r.position.x + 30.0, cy + 12.0), main_s, 13 if compact else 14, TEXT, font_heavy)
	var hc := health_color(hq_frac)
	var bx := r.end.x - (36.0 if compact else 44.0)
	Icons.draw(ci, "hq", Rect2(bx + 8.0, cy - (8.0 if compact else 13.0), 14.0, 14.0), hc)
	if not compact:
		text(ci, Vector2(bx - 6.0, cy + 13.0), "%d%%" % int(ceil(hq_frac * 100.0)), 11, TEXT if hq_frac > 0.3 else DANGER, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, 42.0)
	pill(ci, Rect2(r.position.x + 14.0, r.end.y - 5.0, r.size.x - 28.0, 2.5), Color(0, 0, 0, 0.45))
	pill(ci, Rect2(r.position.x + 14.0, r.end.y - 5.0, (r.size.x - 28.0) * clampf(hq_frac, 0.0, 1.0), 2.5), hc)

func _paint_goal(ci: CanvasItem, r: Rect2) -> void:
	if goal == "":
		return
	pill(ci, r, Color(0.06, 0.08, 0.05, 0.9), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75))
	text(ci, Vector2(r.position.x, r.position.y + 21.0), goal, 14, TEXT, font_bold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _paint_settings(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, r.size.y * 0.5)
	Icons.draw(ci, "muted" if AudioServer.is_bus_mute(0) else "sound", r.grow(-10.0), DANGER if AudioServer.is_bus_mute(0) else TEXT)

func _paint_build(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, 18.0, Color(0.07, 0.085, 0.07, 0.92), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55))
	Icons.draw(ci, "hammer", Rect2(r.position.x + 18.0, r.position.y + r.size.y * 0.5 - 13.0, 26.0, 26.0), ACCENT)
	text(ci, Vector2(r.position.x + 50.0, r.position.y + r.size.y * 0.5 + 7.0), "BUILD", 19, TEXT, font_heavy)

func _paint_start(ci: CanvasItem, r: Rect2) -> void:
	var glow := 0.5 + 0.5 * sin(_pulse * 3.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT.lerp(Color(1.0, 0.76, 0.36), glow * 0.3)
	sb.set_corner_radius_all(18)
	sb.anti_aliasing = true
	sb.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2 + glow * 0.2)
	sb.shadow_size = int(5 + glow * 6)
	ci.draw_style_box(sb, r)
	Icons.draw(ci, "play", Rect2(r.position.x + 16.0, r.position.y + r.size.y * 0.5 - 11.0, 22.0, 22.0), ACCENT_DK)
	text(ci, Vector2(r.position.x + 42.0, r.position.y + r.size.y * 0.5 - 1.0), "START", 17, ACCENT_DK, font_heavy)
	text(ci, Vector2(r.position.x + 42.0, r.position.y + r.size.y * 0.5 + 14.0), "WAVE %d" % wave, 11, Color(ACCENT_DK.r, ACCENT_DK.g, ACCENT_DK.b, 0.75), font_heavy)

func _paint_sheet(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, 22.0, Color(0.05, 0.062, 0.055, 0.93))
	pill(ci, Rect2(r.position.x + r.size.x * 0.5 - 22.0, r.position.y + 7.0, 44.0, 4.0), Color(1, 1, 1, 0.22))

func _paint_tool_chip(ci: CanvasItem, r: Rect2) -> void:
	if tool == "":
		return
	glass(ci, r, 18.0, Color(0.06, 0.075, 0.065, 0.93), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6))
	var d: Dictionary = Defs.BUILD.get(tool, {})
	var name := String(d.get("long", "Remove" if tool == "remove" else ("Move" if tool == "_move" else ("Reshape" if tool == "_reshape" else tool.capitalize()))))
	var icon := tool if not tool.begins_with("_") else ("move" if tool == "_move" else "reshape")
	pill(ci, Rect2(r.position.x + 8.0, r.position.y + 8.0, 40.0, 40.0), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.16), Color(0, 0, 0, 0), 12.0)
	Icons.draw(ci, icon, Rect2(r.position.x + 14.0, r.position.y + 14.0, 28.0, 28.0), ACCENT)
	var x := r.position.x + 58.0
	var w := r.size.x - 58.0 - 56.0
	var cost := ""
	if d.has("per_m") and bool(d.get("linear", false)):
		cost = "  ·  %d/m" % int(d["per_m"])
	elif d.has("cost"):
		cost = "  ·  %d" % int(d["cost"])
	text(ci, Vector2(x, r.position.y + 25.0), name + cost, 15, TEXT, font_heavy, HORIZONTAL_ALIGNMENT_LEFT, w)
	var hint := _hint_text
	var fs := 12
	while fs > 10 and font_bold.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	text(ci, Vector2(x, r.position.y + 43.0), hint, fs, MUTED, font_bold, HORIZONTAL_ALIGNMENT_LEFT, w)
	var xr := Rect2(r.end.x - 50.0, r.position.y + 8.0, 40.0, 40.0)
	pill(ci, xr, Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 12.0)
	Icons.draw(ci, "close", xr.grow(-11.0), TEXT)

func _paint_ok(ci: CanvasItem, r: Rect2) -> void:
	var ok: bool = ok_btn.get_meta("ok", true)
	var c := r.get_center()
	ci.draw_circle(c + Vector2(0, 3), r.size.x * 0.5, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r.size.x * 0.5, OK if ok else Color(0.33, 0.36, 0.31))
	ci.draw_arc(c, r.size.x * 0.5 - 1.0, 0, TAU, 40, Color(1, 1, 1, 0.25), 1.5, true)
	Icons.draw(ci, "check", Rect2(c - Vector2(16, 16), Vector2(32, 32)), Color(0.04, 0.12, 0.04) if ok else Color(0.7, 0.7, 0.66))

func _paint_x(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	ci.draw_circle(c + Vector2(0, 2), r.size.x * 0.5, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r.size.x * 0.5, Color(0.08, 0.09, 0.08, 0.92))
	ci.draw_arc(c, r.size.x * 0.5 - 1.0, 0, TAU, 32, Color(1, 1, 1, 0.16), 1.5, true)
	Icons.draw(ci, "close", Rect2(c - Vector2(12, 12), Vector2(24, 24)), TEXT)

func _paint_undo_last(ci: CanvasItem, r: Rect2) -> void:
	var t: float = undo_last_btn.get_meta("t", 0.0)
	glass(ci, r, 16.0, PANEL, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6))
	Icons.draw(ci, "undo", Rect2(r.position.x + 12.0, r.position.y + r.size.y * 0.5 - 10.0, 20.0, 20.0), ACCENT)
	text(ci, Vector2(r.position.x + 38.0, r.position.y + r.size.y * 0.5 + 6.0), "UNDO", 15, TEXT, font_heavy)
	var f := clampf(t / 5.0, 0.0, 1.0)
	pill(ci, Rect2(r.position.x + 12.0, r.end.y - 6.0, (r.size.x - 24.0) * f, 3.0), ACCENT)

func _paint_undo(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, r.size.y * 0.5)
	Icons.draw(ci, "undo", r.grow(-14.0), TEXT)

func _paint_done(ci: CanvasItem, r: Rect2) -> void:
	pill(ci, r, OK)
	Icons.draw(ci, "check", r.grow(-14.0), Color(0.05, 0.12, 0.05))

func _paint_toasts(ci: CanvasItem, r: Rect2) -> void:
	var y := r.position.y
	for x in _toasts:
		var age: float = x[1]
		var life: float = x[3]
		var a := minf(clampf(age / 0.15, 0.0, 1.0), clampf((life - age) / 0.3, 0.0, 1.0))
		var slide := (1.0 - ease_out(age / 0.18)) * -8.0
		var s: String = x[0]
		var fs := 14
		var tw := font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while fs > 11 and tw > r.size.x - 40.0:
			fs -= 1
			tw = font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := minf(r.size.x, tw + 34.0)
		var tr := Rect2(r.position.x + (r.size.x - w) * 0.5, y + slide, w, 34.0)
		var danger: bool = x[2]
		var edge := Color(DANGER.r, DANGER.g, DANGER.b, 0.6 * a) if danger else Color(1, 1, 1, 0.12 * a)
		pill(ci, tr, Color(0.05, 0.06, 0.055, 0.9 * a), edge)
		text(ci, Vector2(tr.position.x, tr.position.y + 22.0), s, fs, Color(TEXT.r, TEXT.g, TEXT.b, a), font_bold, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
		y += 40.0

func _paint_banner(ci: CanvasItem, r: Rect2) -> void:
	if _cur_banner.is_empty():
		return
	var title: String = _cur_banner[0]
	var sub: String = _cur_banner[1]
	var col: Color = _cur_banner[2]
	var fs := 42 if not compact else 34
	text(ci, Vector2(r.position.x + 2, r.position.y + 52), title, fs, Color(0, 0, 0, 0.5), font_heavy, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(ci, Vector2(r.position.x, r.position.y + 50), title, fs, col, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if sub != "":
		var sw := font_bold.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30.0
		var sr := Rect2(r.position.x + (r.size.x - sw) * 0.5, r.position.y + 64.0, sw, 30.0)
		pill(ci, sr, Color(0.04, 0.05, 0.045, 0.78))
		text(ci, Vector2(sr.position.x, sr.position.y + 20.0), sub, 15, TEXT, font_bold, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
var _map_rects := {}
var _play_rect := Rect2()
var _continue_rect := Rect2()
# {wave, map, people} of the save to continue, or empty.
var save_info: Dictionary = {}:
	set(v):
		save_info = v
		if title_card:
			_layout()
			title_card.queue_redraw()

func _title_press(p: Vector2) -> void:
	if not save_info.is_empty() and _continue_rect.has_point(p):
		continue_pressed.emit()
		return
	if _play_rect.has_point(p):
		play_pressed.emit()
		return
	for id in _map_rects:
		if (_map_rects[id] as Rect2).has_point(p):
			map_picked.emit(id)
			return

func _paint_title(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, 24.0, Color(0.05, 0.06, 0.055, 0.9))
	text(ci, Vector2(r.position.x, r.position.y + 54), "ZOMBIE DEFENCE", 32, TEXT, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(ci, Vector2(r.position.x, r.position.y + 82), "Wall in a safe zone. Keep the HQ standing.", 14, MUTED, font_bold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(ci, Vector2(r.position.x + 18, r.position.y + 114), "PICK A MAP", 11, ACCENT, font_heavy)
	_map_rects.clear()
	var pad := 16.0
	var gap := 10.0
	var cw := (r.size.x - pad * 2.0 - gap) * 0.5
	var chh := 96.0
	for i in Defs.MAPS.size():
		var m: Dictionary = Defs.MAPS[i]
		var cr := Rect2(r.position.x + pad + (i % 2) * (cw + gap), r.position.y + 124 + (i / 2) * (chh + gap), cw, chh)
		var on: bool = m["id"] == G.map_id
		var ready: bool = m["ready"]
		var sb2 := StyleBoxFlat.new()
		sb2.set_corner_radius_all(16)
		sb2.anti_aliasing = true
		sb2.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.16) if on else Color(1, 1, 1, 0.05 if ready else 0.025)
		sb2.border_color = ACCENT if on else Color(1, 1, 1, 0.12 if ready else 0.05)
		sb2.set_border_width_all(2 if on else 1)
		ci.draw_style_box(sb2, cr)
		var icon: String = {"fields": "wall", "suburb": "house", "forest": "radio", "city": "depot"}.get(m["id"], "zone")
		Icons.draw(ci, icon, Rect2(cr.position.x + 14, cr.position.y + 14, 22, 22), (ACCENT if on else TEXT) if ready else MUTED)
		text(ci, Vector2(cr.position.x + 44, cr.position.y + 32), String(m["name"]).to_upper(), 18, (ACCENT if on else TEXT) if ready else MUTED, font_heavy)
		var about := String(m["about"])
		ci.draw_multiline_string(font_bold, Vector2(cr.position.x + 14, cr.position.y + 58), about, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 24, 12, 2 if ready else 1, MUTED if ready else Color(MUTED.r, MUTED.g, MUTED.b, 0.6))
		if ready:
			_map_rects[m["id"]] = cr
		else:
			pill(ci, Rect2(cr.position.x + 14, cr.position.y + 70, 96, 18), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14))
			text(ci, Vector2(cr.position.x + 14, cr.position.y + 83), "COMING SOON", 10, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8), font_heavy, HORIZONTAL_ALIGNMENT_CENTER, 96)
	var br := Rect2(r.position.x + r.size.x * 0.5 - 100, r.end.y - 78, 200, 56)
	_play_rect = br
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	sb.anti_aliasing = true
	if not save_info.is_empty():
		var cr2 := Rect2(r.position.x + 16, r.end.y - 148, r.size.x - 32, 60)
		_continue_rect = cr2
		sb.bg_color = ACCENT
		ci.draw_style_box(sb, cr2)
		Icons.draw(ci, "play", Rect2(cr2.position.x + 22, cr2.position.y + 19, 22, 22), ACCENT_DK)
		var map_name := String(save_info.get("map", "")).capitalize()
		text(ci, Vector2(cr2.position.x + 30, cr2.position.y + 28), "CONTINUE", 21, ACCENT_DK, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, cr2.size.x - 30)
		text(ci, Vector2(cr2.position.x + 30, cr2.position.y + 48), "Wave %d  ·  %s  ·  %d people" % [int(save_info["wave"]), map_name, int(save_info.get("people", 0))], 13, ACCENT_DK, font_bold, HORIZONTAL_ALIGNMENT_CENTER, cr2.size.x - 30)
		var sb3 := StyleBoxFlat.new()
		sb3.set_corner_radius_all(18)
		sb3.anti_aliasing = true
		sb3.bg_color = Color(1, 1, 1, 0.06)
		sb3.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7)
		sb3.set_border_width_all(2)
		ci.draw_style_box(sb3, br)
		text(ci, Vector2(br.position.x, br.position.y + 35), "NEW GAME", 19, ACCENT, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
		return
	sb.bg_color = ACCENT
	ci.draw_style_box(sb, br)
	Icons.draw(ci, "play", Rect2(br.position.x + 40, br.position.y + 17, 22, 22), ACCENT_DK)
	text(ci, Vector2(br.position.x + 30, br.position.y + 36), "PLAY", 22, ACCENT_DK, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)

func _paint_over(ci: CanvasItem, r: Rect2) -> void:
	glass(ci, r, 24.0, Color(0.07, 0.04, 0.035, 0.92), Color(DANGER.r, DANGER.g, DANGER.b, 0.55))
	text(ci, Vector2(r.position.x, r.position.y + 54), "HQ LOST", 34, DANGER, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var held := "You held %d wave%s" % [_over_waves, "" if _over_waves == 1 else "s"]
	text(ci, Vector2(r.position.x, r.position.y + 90), held, 17, TEXT, font_bold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(ci, Vector2(r.position.x, r.position.y + 114), "%d zombies down" % _over_kills, 14, MUTED, font_bold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var br := Rect2(r.position.x + r.size.x * 0.5 - 100, r.end.y - 78, 200, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT
	sb.set_corner_radius_all(18)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, br)
	text(ci, Vector2(br.position.x, br.position.y + 35), "PLAY AGAIN", 19, ACCENT_DK, font_heavy, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
