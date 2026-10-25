class_name InfoCard
extends Control
signal action(id: String, target)
const BTN_H := 46.0
const GAP := 8.0
const PER_ROW := 3
const PAD := 16.0
const HEAD := 50.0
const LINE := 20.0
const ROW := 58.0
var target = null
var popover := false
var anchor := Vector2.ZERO
var _buttons: Array = []
var _t := 0.0
var _close_rect := Rect2()
var _slider_rect := Rect2()
var _sliding := false
var _press_id := ""
var _press_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	visible = false

func show_for(t) -> void:
	target = t
	visible = true
	queue_redraw()

func _lines() -> Array:
	if target is DigMark:
		return ["Being dug  %d%%" % int(target.progress * 100.0)]
	if target.has_method("card_lines"):
		return target.card_lines()
	return []

func _btns() -> Array:
	if target is DigMark:
		return [["sell", "CANCEL +%d" % target.paid, true]]
	if target.has_method("card_buttons"):
		return target.card_buttons()
	return []

func _has_bar() -> bool:
	return target is Building and target.has_health() and target.state == Building.BUILT

func wanted_height() -> float:
	if not _valid():
		return 170.0
	var h := PAD + HEAD
	if _has_bar():
		h += 18.0
	h += _lines().size() * LINE
	if target.has_method("card_rows"):
		h += target.card_rows().size() * ROW + 8.0
	if target.has_method("card_slider"):
		h += 60.0
	var bl := _btns()
	if not bl.is_empty():
		var per := _per_row(bl, (size.x if size.x > 100.0 else 360.0) - PAD * 2.0)
		if G.hud and G.hud.card == self and G.hud.vs.x > 0.0:
			var cw: float = clampf(G.hud.vs.x * 0.5, 360.0, 460.0) if not (G.hud.portrait or G.hud.vs.x < 640.0) else minf(G.hud.R - G.hud.L, 520.0)
			per = _per_row(bl, cw - PAD * 2.0)
		var rows := int(ceil(float(bl.size()) / per))
		h += 10.0 + rows * (BTN_H + GAP) - GAP
	return h + PAD

func _per_row(bl: Array, w: float) -> int:
	var per := PER_ROW
	while per > 1:
		var bw := (w - GAP * (per - 1)) / per
		var fits := true
		for b in bl:
			var need := Hud.font_heavy.get_string_size(String(b[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
			if String(b[0]).begins_with("auto_"):
				need += 34.0
			if need > bw:
				fits = false
				break
		if fits:
			break
		per -= 1
	return per

func _label_size(bl: Array, per: int, w: float) -> int:
	var bw := (w - GAP * (per - 1)) / per
	var fs := 14
	while fs > 11:
		var ok := true
		for b in bl:
			var icon := Icons.for_action(String(b[0]))
			var need := Hud.font_heavy.get_string_size(String(b[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0 + (21.0 if icon != "" else 0.0)
			if String(b[0]).begins_with("auto_"):
				need += 34.0
			if need > bw:
				ok = false
				break
		if ok:
			break
		fs -= 1
	return fs

func hide_card() -> void:
	target = null
	visible = false

func _valid() -> bool:
	if target == null:
		return false
	if target is Object and not is_instance_valid(target):
		return false
	if target is FenceRun and target.claimed:
		return false
	if target is Rubble and not G.walls.rubble.has(target):
		return false
	if target is Building and target.state == Building.DEAD:
		return false
	if target is DigMark and target.done:
		return false
	if target is CardModels.SlotPick:
		if target.host != null and (not is_instance_valid(target.host) or target.host.state == Building.DEAD):
			return false
		if target.seg != null and (not is_instance_valid(target.seg) or target.seg.state == Building.DEAD):
			return false
	return true

func _process(dt: float) -> void:
	if _press_t > 0.0:
		_press_t = maxf(0.0, _press_t - dt * 5.0)
		queue_redraw()
	if not visible:
		return
	if not _valid():
		hide_card()
		if G.hud:
			G.hud.hide_card()
		return
	_t -= dt
	if _t <= 0.0:
		_t = 0.15
		var want := wanted_height()
		if absf(want - size.y) > 1.0 and G.hud:
			G.hud.relayout()
		queue_redraw()

func _icon_kind() -> String:
	if target is CardModels.ZoneInfo:
		return "zone"
	if target is Rubble:
		return "rubble"
	if target is FenceRun:
		return "wall"
	if target is CardModels.SlotPick:
		return "platform"
	if target is CardModels.Settings:
		return "sound"
	if target is CardModels.Ask:
		return "check"
	if target is DigMark:
		return "dig"
	if target is MapBuilding:
		match String(target.kind):
			"petrol_station":
				return "fuel"
			"corner_shop":
				return "depot"
			"garage_detached":
				return "workshop"
		return "house"
	if target is Building:
		if target == G.buildings.hq:
			return "hq"
		var k: String = target.kind
		if k in ["fence", "picket", "hedge", "brickwall"]:
			return "wall"
		if k.begins_with("bastion"):
			return "watchtower"
		return k
	return "zone"

func _draw_row(row: Array, x: float, y: float, w: float) -> void:
	var job: String = row[0]
	var bsz := 48.0
	var jicon: String = {"worker": "hammer", "soldier": "soldier", "loader": "crate", "fetcher": "supplies", "crafter": "workshop",
		"zspeed": "zombie", "horde": "zombie", "spawn": "clock"}.get(job, "person")
	Icons.draw(self, jicon, Rect2(x, y + 8.0, 22.0, 22.0), Hud.ACCENT)
	draw_string(Hud.font_heavy, Vector2(x + 30.0, y + 24), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.45, 16, Hud.TEXT)
	draw_string(Hud.font_bold, Vector2(x + 30.0, y + 42), String(row[5]), HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, 12, Hud.MUTED)
	var plus := Rect2(x + w - bsz, y + 2.0, bsz, bsz)
	var minus := Rect2(x + w - bsz * 2.0 - 50.0, y + 2.0, bsz, bsz)
	draw_string(Hud.font_heavy, Vector2(minus.end.x, y + 34), "%d" % int(row[2]), HORIZONTAL_ALIGNMENT_CENTER, 50.0, 22, Hud.TEXT)
	for pair in [[minus, "minus", bool(row[3]), "minus:" + job], [plus, "plus", bool(row[4]), "plus:" + job]]:
		var r: Rect2 = pair[0]
		var en: bool = pair[2]
		var hot: bool = en and pair[1] == "plus"
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		sb.bg_color = Hud.ACCENT if hot else (Color(1, 1, 1, 0.1) if en else Color(1, 1, 1, 0.04))
		draw_style_box(sb, r)
		var c := Hud.ACCENT_DK if hot else (Hud.TEXT if en else Hud.MUTED)
		Icons.draw(self, pair[1], r.grow(-14.0), c)
		_buttons.append([r, pair[3], en])

func _slide_to(x: float) -> void:
	if _slider_rect.size.x <= 0.0 or not target.has_method("set_slider"):
		return
	target.set_slider(clampf((x - _slider_rect.position.x) / _slider_rect.size.x, 0.0, 1.0))
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and _sliding:
		_slide_to(e.position.x)
		accept_event()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_sliding = false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		accept_event()
		if _slider_rect.grow(14.0).has_point(e.position):
			_sliding = true
			_slide_to(e.position.x)
			return
		if _close_rect.grow(6.0).has_point(e.position):
			action.emit("close", target)
			return
		for b in _buttons:
			if (b[0] as Rect2).has_point(e.position) and b[2]:
				_press_id = b[1]
				_press_t = 1.0
				action.emit(b[1], target)
				queue_redraw()
				return
	elif e is InputEventScreenTouch:
		accept_event()

static func _secondary(id: String) -> bool:
	return id == "sell" or id == "close" or id.begins_with("ask_no") or id == "inner_no" or id == "clear_rubble" or id == "cancel_claim" or id == "mute" or id.begins_with("auto_")

func _draw() -> void:
	_buttons.clear()
	if not _valid():
		return
	var r := Rect2(Vector2.ZERO, size)
	if popover:
		var py := clampf(anchor.y, 26.0, r.size.y - 26.0)
		if anchor.x < 0.0:
			draw_colored_polygon(PackedVector2Array([Vector2(1, py - 10), Vector2(-9, py), Vector2(1, py + 10)]), Color(0.05, 0.062, 0.055, 0.94))
		elif anchor.x > r.size.x:
			draw_colored_polygon(PackedVector2Array([Vector2(r.size.x - 1, py - 10), Vector2(r.size.x + 9, py), Vector2(r.size.x - 1, py + 10)]), Color(0.05, 0.062, 0.055, 0.94))
	Hud.glass(self, r, 22.0, Color(0.05, 0.062, 0.055, 0.94), Color(1, 1, 1, 0.11))
	if not popover:
		Hud.pill(self, Rect2(r.size.x * 0.5 - 20.0, 6.0, 40.0, 4.0), Color(1, 1, 1, 0.18))
	var x := PAD
	var w := r.size.x - PAD * 2.0
	var tile := Rect2(x, PAD - 2.0, 40.0, 40.0)
	Hud.pill(self, tile, Color(Hud.ACCENT.r, Hud.ACCENT.g, Hud.ACCENT.b, 0.15), Color(0, 0, 0, 0), 12.0)
	Icons.draw(self, _icon_kind(), tile.grow(-8.0), Hud.ACCENT)
	var title := ""
	if target.has_method("card_title"):
		title = target.card_title()
	elif target is Building:
		title = target.long_name()
	elif target is DigMark:
		title = "Trench"
	var tfs := 17
	while tfs > 12 and Hud.font_heavy.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > w - 100.0:
		tfs -= 1
	draw_string(Hud.font_heavy, Vector2(x + 52.0, PAD + 24.0), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 100.0, tfs, Hud.TEXT)
	_close_rect = Rect2(r.size.x - 50.0, 10.0, 40.0, 40.0)
	Hud.pill(self, _close_rect, Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 12.0)
	Icons.draw(self, "close", _close_rect.grow(-12.0), Hud.MUTED)
	var y := PAD + HEAD
	if _has_bar():
		var f: float = clampf(target.hp / target.max_hp, 0.0, 1.0)
		var bw := w - 92.0
		Hud.pill(self, Rect2(x, y - 4.0, bw, 6.0), Color(0, 0, 0, 0.5))
		Hud.pill(self, Rect2(x, y - 4.0, maxf(6.0, bw * f), 6.0), Hud.health_color(f))
		draw_string(Hud.font_bold, Vector2(x + w - 86.0, y + 3.0), "%d / %d" % [int(ceil(target.hp)), int(target.max_hp)], HORIZONTAL_ALIGNMENT_RIGHT, 86.0, 12, Hud.MUTED)
		y += 18.0
	if target is MortarPit and target.state == Building.BUILT:
		var rf: float = target.reload_frac()
		Hud.pill(self, Rect2(x, y - 8.0, w, 3.0), Color(0, 0, 0, 0.45))
		Hud.pill(self, Rect2(x, y - 8.0, w * rf, 3.0), Hud.ACCENT if rf < 1.0 else Hud.OK)
	var rows_mode: bool = target.has_method("card_rows")
	var first := true
	for l in _lines():
		var s := String(l)
		var fs := 14
		while fs > 11 and Hud.font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			fs -= 1
		draw_string(Hud.font_bold, Vector2(x, y + 14.0), s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, Hud.TEXT if first and not rows_mode else Hud.MUTED)
		first = false
		y += LINE
	if rows_mode:
		y += 6.0
		for row in target.card_rows():
			_draw_row(row, x, y, w)
			y += ROW
	_slider_rect = Rect2()
	if target.has_method("card_slider"):
		var v: float = clampf(target.card_slider(), 0.0, 1.0)
		draw_string(Hud.font_bold, Vector2(x, y + 16), String(target.slider_label()), HORIZONTAL_ALIGNMENT_LEFT, w, 14, Hud.TEXT)
		_slider_rect = Rect2(x + 10, y + 34, w - 20, 8)
		Hud.pill(self, _slider_rect, Color(1, 1, 1, 0.12))
		Hud.pill(self, Rect2(_slider_rect.position, Vector2(maxf(8.0, _slider_rect.size.x * v), _slider_rect.size.y)), Hud.ACCENT)
		draw_circle(Vector2(_slider_rect.position.x + _slider_rect.size.x * v, _slider_rect.get_center().y), 13.0, Hud.TEXT)
		y += 60.0
	var btns := _btns()
	if btns.is_empty():
		return
	var per := _per_row(btns, w)
	var fs_all := _label_size(btns, per, w)
	var rows := int(ceil(float(btns.size()) / per))
	var by0 := r.size.y - PAD - rows * (BTN_H + GAP) + GAP
	var primary_done := false
	for i in btns.size():
		var row_i := i / per
		var in_row := mini(per, btns.size() - row_i * per)
		var col := i % per
		var bw2 := (w - GAP * (in_row - 1)) / in_row
		var br := Rect2(x + col * (bw2 + GAP), by0 + row_i * (BTN_H + GAP), bw2, BTN_H)
		var b: Array = btns[i]
		var id := String(b[0])
		var enabled: bool = b[2]
		var primary := enabled and not primary_done and not _secondary(id)
		if primary:
			primary_done = true
		if _press_t > 0.0 and _press_id == id:
			br = br.grow(-2.5 * sin(_press_t * PI))
		var bsb := StyleBoxFlat.new()
		bsb.set_corner_radius_all(14)
		bsb.anti_aliasing = true
		if not enabled:
			bsb.bg_color = Color(1, 1, 1, 0.04)
		elif primary:
			bsb.bg_color = Hud.ACCENT
		else:
			bsb.bg_color = Color(1, 1, 1, 0.08)
			bsb.border_color = Color(1, 1, 1, 0.12)
			bsb.set_border_width_all(1)
		draw_style_box(bsb, br)
		var tc := Hud.MUTED
		var ic := Hud.MUTED
		if enabled:
			tc = Hud.ACCENT_DK if primary else Hud.TEXT
			ic = Hud.ACCENT_DK if primary else (Hud.DANGER if id == "sell" or id == "clear_rubble" else Hud.ACCENT)
		var label := String(b[1])
		var icon := Icons.for_action(id)
		var toggle := id.begins_with("auto_")
		var isz := 16.0 if icon != "" else 0.0
		var fs2 := fs_all
		var lw := Hud.font_heavy.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var avail := bw2 - 14.0 - (isz + 5.0 if icon != "" else 0.0) - (34.0 if toggle else 0.0)
		if lw > avail and icon != "":
			icon = ""
			isz = 0.0
		var total := lw + (isz + 5.0 if icon != "" else 0.0) + (34.0 if toggle else 0.0)
		var lx := br.position.x + (br.size.x - total) * 0.5
		if icon != "":
			Icons.draw(self, icon, Rect2(lx, br.position.y + (BTN_H - isz) * 0.5, isz, isz), ic)
			lx += isz + 5.0
		draw_string(Hud.font_heavy, Vector2(lx, br.position.y + BTN_H * 0.5 + fs2 * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
		if toggle:
			var on := _toggle_on(id)
			var sw := Rect2(lx + lw + 8.0, br.position.y + BTN_H * 0.5 - 8.0, 26.0, 16.0)
			Hud.pill(self, sw, (Hud.ACCENT_DK if primary else Hud.ACCENT) if on else Color(1, 1, 1, 0.18))
			draw_circle(Vector2(sw.end.x - 8.0 if on else sw.position.x + 8.0, sw.get_center().y), 6.0, Hud.TEXT if not primary else Color(1, 0.95, 0.85))
		_buttons.append([br, b[0], enabled])

func _toggle_on(id: String) -> bool:
	match id:
		"auto_rebuild":
			return G.walls != null and G.walls.auto_rebuild
	return false
