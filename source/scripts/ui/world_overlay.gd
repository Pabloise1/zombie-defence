class_name WorldOverlay
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_dt: float) -> void:
	queue_redraw()

func _bar(p: Vector2, w: float, h: float, f: float, fill: Color, back: Color = Color(0.05, 0.06, 0.05, 0.75)) -> void:
	var r := Rect2(round(p.x - w * 0.5), round(p.y - h * 0.5), round(w), round(h))
	draw_rect(r.grow(2.0), Color(1, 1, 1, 0.18))
	draw_rect(r.grow(1.0), back)
	if f > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), fill)

func _no_ammo(p: Vector2) -> void:
	var w := 70.0
	var r := Rect2(p.x - w * 0.5, p.y - 9, w, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.15, 0.1, 0.92)
	sb.set_corner_radius_all(9)
	draw_style_box(sb, r)
	draw_string(Hud.font_heavy, Vector2(r.position.x, r.position.y + 14), "NO AMMO", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1, 0.95, 0.9))

func _plan_label(cam: Camera3D) -> void:
	var b = G.builder
	if b == null or not b.has_tool():
		return
	var txt: String = b.pending_label()
	var at: Vector3 = b.pending_anchor()
	if txt == "" or at == Vector3.INF:
		return
	var sp := _screen(cam, at + Vector3(0, 0.5, 0))
	var ok: bool = b.pending_ok() or (b.is_wall_tool() and b.plan.size() == 1)
	var f := Hud.font_bold
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
	var vsz := get_viewport_rect().size
	var r := Rect2(clampf(sp.x - w * 0.5, 8.0, vsz.x - w - 8.0), sp.y - 64, w, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.07, 0.88)
	sb.border_color = Hud.OK if ok else Hud.DANGER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(13)
	draw_style_box(sb, r)
	draw_string(f, Vector2(r.position.x, r.position.y + 18), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Hud.TEXT)

func _handles(cam: Camera3D) -> void:
	var b = G.builder
	if b == null or not b.has_tool():
		return
	for h in b.handles():
		var sp := _screen(cam, h["pos"] + Vector3(0, 0.2, 0))
		var hot: bool = h["hot"]
		match String(h["kind"]):
			"mid":
				draw_circle(sp, 15.0, Color(0.06, 0.08, 0.07, 0.8))
				draw_arc(sp, 15.0, 0, TAU, 24, Hud.ACCENT, 2.0, true)
				draw_line(sp - Vector2(7, 0), sp + Vector2(7, 0), Hud.ACCENT, 3.0)
				draw_line(sp - Vector2(0, 7), sp + Vector2(0, 7), Hud.ACCENT, 3.0)
			"pin":
				draw_circle(sp, 12.0, Color(0.35, 0.36, 0.33, 0.9))
			"rotate":
				var c := _screen(cam, h["from"] + Vector3(0, 0.2, 0))
				draw_line(c, sp, Color(1, 1, 1, 0.55), 3.0, true)
				draw_circle(sp, 22.0, Color(0.06, 0.08, 0.07, 0.85))
				draw_arc(sp, 22.0, 0, TAU, 32, Hud.ACCENT if not hot else Hud.OK, 3.0, true)
				draw_arc(sp, 11.0, -2.4, 1.2, 16, Hud.TEXT, 3.0, true)
				var tip := sp + Vector2(cos(1.2), sin(1.2)) * 11.0
				draw_line(tip, tip + Vector2(-5, -1), Hud.TEXT, 3.0)
				draw_line(tip, tip + Vector2(1, -6), Hud.TEXT, 3.0)
			_:
				var rad := 20.0 if hot else 17.0
				draw_circle(sp, rad + 3.0, Color(0, 0, 0, 0.35))
				draw_circle(sp, rad, Hud.OK if hot else Color(0.95, 0.95, 0.9, 0.95))
				draw_circle(sp, rad * 0.45, Hud.ACCENT)

func _slots(cam: Camera3D) -> void:
	if G.builder == null:
		return
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
	for p in G.builder.slot_markers():
		var sp := _screen(cam, p + Vector3(0, 0.3, 0))
		draw_circle(sp, 17.0, Color(1.0, 0.75, 0.3, 0.25 * pulse))
		draw_arc(sp, 14.0, 0, TAU, 28, Color(1.0, 0.8, 0.35, 0.9 * pulse), 3.0, true)
		draw_line(sp - Vector2(6, 0), sp + Vector2(6, 0), Hud.TEXT, 3.0)
		draw_line(sp - Vector2(0, 6), sp + Vector2(0, 6), Hud.TEXT, 3.0)

func _badge(p: Vector2, txt: String, col: Color) -> void:
	var w := Hud.font_heavy.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
	var r := Rect2(p.x - w * 0.5, p.y - 9, w, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(9)
	draw_style_box(sb, r)
	draw_string(Hud.font_heavy, Vector2(r.position.x, r.position.y + 13), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(1, 0.95, 0.9))

func _screen(cam: Camera3D, p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return Vector2(-9999, -9999)
	return cam.unproject_position(p)

func _draw() -> void:
	if G.cam == null or G.buildings == null:
		return
	var cam: Camera3D = G.cam.cam
	var vr := get_viewport_rect().grow(40)
	var zoom := clampf(40.0 / G.cam.dist, 0.6, 1.4)
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state == Building.DEAD:
			continue
		var top := 2.4
		if b is LinearStructure:
			top = float(b.def.get("height", 2.2)) + 0.4
		elif b.rect:
			top = 5.0
		elif b.host != null:
			top = 1.8
		if b == G.buildings.hq:
			if b.hp < b.max_hp:
				var sp := _screen(cam, b.position + Vector3(0, 4.2, 0))
				if vr.has_point(sp):
					var f: float = b.hp / b.max_hp
					_bar(sp, 84.0 * zoom, 9.0, f, Hud.health_color(f))
			continue
		var sp2 := _screen(cam, b.position + Vector3(0, top, 0))
		if not vr.has_point(sp2):
			continue
		if b.state == Building.BLUEPRINT:
			_bar(sp2, 40.0 * zoom, 5.0, b.progress, Color(0.45, 0.88, 1.0))
		elif b.has_health() and b.hp < b.max_hp:
			var f2: float = b.hp / b.max_hp
			_bar(sp2, 40.0 * zoom, 6.0, f2, Hud.health_color(f2))
		if b.state == Building.BUILT and b.host != null and not b.crew_ok():
			_badge(sp2 + Vector2(0, -12.0), "NO CREW", Color(0.55, 0.4, 0.1, 0.92))
		if b.state == Building.BUILT and b.kind == "flame" and not b.has_fuel():
			_badge(sp2 + Vector2(0, -12.0), "NO FUEL", Color(0.6, 0.2, 0.1, 0.92))
		if b.state == Building.BUILT and b.mag_size > 0:
			var ap := sp2 + Vector2(0, 10.0)
			if b.out_of_ammo():
				_no_ammo(ap)
			else:
				var af: float = float(b.mag) / float(b.mag_size)
				var col := Color(0.98, 0.82, 0.38) if b.reload_t <= 0.0 else Color(0.6, 0.6, 0.55)
				_bar(ap, 30.0 * zoom, 4.0, af, col)
				if b.reserve_max > 0:
					var rf: float = float(b.reserve) / float(b.reserve_max)
					_bar(ap + Vector2(0, 7), 30.0 * zoom, 3.0, rf, Color(0.85, 0.55, 0.2))
	if G.zombies:
		for z in G.zombies.alive_list:
			if z.alive and z.kind == Defs.Z_BRUTE:
				var zp := _screen(cam, z.position + Vector3(0, 2.9 * z.scale.y / 1.45, 0))
				if vr.has_point(zp):
					var zf: float = z.hp / z.max_hp
					_bar(zp, 40.0 * zoom, 5.0, zf, Hud.DANGER)
	if G.soldiers:
		for s in G.soldiers.soldiers:
			if s.exposed() and s.hp < s.max_hp:
				var spp := _screen(cam, s.position + Vector3(0, 2.1, 0))
				if vr.has_point(spp):
					var sf: float = s.hp / s.max_hp
					_bar(spp, 26.0 * zoom, 4.0, sf, Hud.health_color(sf))
	_slots(cam)
	_handles(cam)
	_plan_label(cam)
	for m in G.buildings.digs:
		if not is_instance_valid(m) or m.done:
			continue
		var sp3 := _screen(cam, m.position + Vector3(0, 1.0, 0))
		if vr.has_point(sp3):
			_bar(sp3, 36.0 * zoom, 5.0, m.progress, Hud.ACCENT)
