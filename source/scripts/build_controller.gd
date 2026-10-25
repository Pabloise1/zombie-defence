class_name BuildController
extends Node3D
signal tool_changed(tool: String)
signal placed(kind: String, count: int)
signal message(text: String)
signal plan_changed
const MAX_LINE := 40
const GRAB_PX := 44.0
const UNDO_TIME := 5.0
var tool := ""
var selected = null
var sel_point := Vector3.INF
var heli_pad = null
var br_a := {}
var br_b := {}
var _br_ghost: Node3D
var g_has := false
var g_pos := Vector3.ZERO
var g_cell := Vector2i(-1, -1)
var g_yaw := 0.0
var g_ok := false
var g_why := ""
var g_host = null
var g_slot := -1
var g_line_a := Vector2i(-1, -1)
var g_line_b := Vector2i(-1, -1)
var g_target = null
var g_spot := {}
var g_moving = null
var _ghost: Node3D
var _ghost_kind := ""
var _line_ghosts: Array[Node3D] = []
var _line_ok: Array[bool] = []
var _line_cells: Array[Vector2i] = []
var _remove_box: MeshInstance3D
var plan: Array = []
var plan_closed := false
var plan_bad := -1
var plan_why := ""
var _plan_meshes: Array[MeshInstance3D] = []
var _plan_posts: Array[MeshInstance3D] = []
var rs_chain := {}
var rs_pts: Array = []
var rs_hist: Array = []
var rs_info := {}
var _rs_meshes: Array[MeshInstance3D] = []
var _drag := ""
var _drag_i := -1
var _drag_off := Vector3.ZERO
var undo_items: Array = []
var undo_t := 0.0
var _ring: MeshInstance3D
var _range: MeshInstance3D
var _range_r := -1.0
var _range_mat: StandardMaterial3D

func has_tool() -> bool:
	return tool != ""

func is_wall_tool() -> bool:
	return tool == "wall" or tool == "concrete"

func _is_line_tool() -> bool:
	return bool(Defs.BUILD.get(tool, {}).get("line", false))

func _is_gun_tool() -> bool:
	return Defs.MOUNTABLE.has(tool)

func _is_prefab_tool() -> bool:
	return Defs.is_prefab(tool)

func set_tool(t: String) -> void:
	if t == tool and not t.begins_with("_"):
		t = ""
	_clear_all()
	tool = t
	if tool != "":
		selected = null
		if G.hud:
			G.hud.hide_card()
		_update_ring()
	if G.terrain:
		var grid_on := tool != "" and not is_wall_tool() and tool != "gate" and tool != "_reshape" and not _is_prefab_tool() and tool != "_move" and tool != "bridge" and not tool.begins_with("_heli")
		G.terrain.set_grid_alpha(1.0 if grid_on else 0.0)
	tool_changed.emit(tool)
	plan_changed.emit()

func _clear_all() -> void:
	_clear_bridge()
	_clear_ghost()
	_clear_plan()
	_clear_reshape()
	g_moving = null
	_drag = ""

func _ground(sp: Vector2) -> Vector3:
	return G.cam.ground_at(sp) if G.cam else Vector3.INF

func _screen(p: Vector3) -> Vector2:
	var cam: Camera3D = G.cam.cam
	if cam.is_position_behind(p):
		return Vector2(-99999, -99999)
	return cam.unproject_position(p)

static func snap_half(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x * 2.0) * 0.5, 0, roundf(p.z * 2.0) * 0.5)

static func grid_center(kind: String, p: Vector3) -> Vector3:
	var c := BuildingManager.origin_for(kind, p)
	var sz := BuildingManager.size_of(kind)
	return Defs.cell_center(c) + Vector3((sz - 1), 0, (sz - 1))

static func snap_yaw(y: float) -> float:
	var step := deg_to_rad(15.0)
	return wrapf(roundf(y / step) * step, -PI, PI)

func begin_move(b) -> void:
	set_tool("_move")
	g_moving = b
	g_has = true
	g_pos = Vector3(b.position.x, 0, b.position.z)
	g_yaw = b.yaw if b.rect else b.rest_yaw
	g_cell = b.cell
	_refresh_ghost()
	message.emit("Drag it or tap a new spot, turn the handle, then tick")

func begin_reshape(s: LinearStructure) -> void:
	set_tool("_reshape")
	rs_chain = G.walls.chain_of(s)
	rs_pts = (rs_chain["pts"] as Array).duplicate()
	rs_hist.clear()
	_refresh_reshape()
	message.emit("Drag the corners. Tap + to add a corner. tick to build")

func tap(sp: Vector2) -> void:
	var p := _ground(sp)
	if tool == "":
		_select_at(sp, p)
		return
	if p == Vector3.INF:
		return
	sel_point = p
	if is_wall_tool():
		_plan_tap(p)
		return
	match tool:
		"_reshape":
			return
		"_heli_rescue", "_heli_patrol":
			_heli_pick(p)
			return
		"bridge":
			_bridge_tap(p)
			return
		"_move":
			g_pos = snap_half(p) if g_moving.rect else grid_center(g_moving.kind, p)
		"remove":
			var c := Defs.world_to_cell(p)
			g_target = G.buildings.removable_at(c)
			g_has = g_target != null
			if not g_has:
				message.emit("Nothing to remove there")
		"gate":
			g_spot = G.walls.gate_spot(p)
			g_has = g_spot.has("c")
			if not g_spot.get("ok", false):
				message.emit(String(g_spot.get("reason", "Tap on a wall")))
		_:
			if _is_line_tool():
				var c2 := Defs.world_to_cell(p)
				if not g_has:
					g_line_a = c2
					g_line_b = c2
					g_has = true
				else:
					g_line_b = c2
			elif _is_prefab_tool():
				g_pos = snap_half(p)
				g_has = true
			else:
				g_host = null
				g_slot = -1
				if _is_gun_tool():
					var sl := _slot_near(sp)
					if not sl.is_empty():
						g_host = sl[0]
						g_slot = sl[1]
				if g_host == null:
					g_cell = BuildingManager.origin_for(tool, p)
					var sz := BuildingManager.size_of(tool)
					g_pos = Defs.cell_center(g_cell) + Vector3((sz - 1), 0, (sz - 1))
				else:
					g_pos = g_host.slot_xform(g_slot).origin
				g_has = true
	_refresh_ghost()

func _select_at(sp: Vector2, p: Vector3) -> void:
	var best = null
	var bd := GRAB_PX
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state == Building.DEAD:
			continue
		if b.host == null and not (b is WallNest):
			continue
		var d := _screen(b.position + Vector3(0, 0.6, 0)).distance_to(sp)
		if d < bd:
			bd = d
			best = b
	if best != null:
		sel_point = best.position
		select(best)
		return
	var sl := _slot_near(sp)
	if not sl.is_empty():
		sel_point = sl[0].position
		select(CardModels.SlotPick.new(sl[0], sl[1]))
		return
	if p == Vector3.INF:
		select(null)
		return
	sel_point = p
	var c := Defs.world_to_cell(p)
	var thing = null
	if G.grid.inb(c):
		var i: int = G.grid.idx(c)
		if G.grid.occ[i] != null and is_instance_valid(G.grid.occ[i]):
			thing = G.grid.occ[i]
		elif G.grid.digs[i] != null:
			thing = G.grid.digs[i]
	if thing == null and G.walls:
		thing = G.walls.segment_at(p, 1.2)
	if thing == null and G.walls:
		thing = G.walls.rubble_at(p, 1.4)
	if thing == null and G.map:
		thing = G.map.fence_near(p, 1.2)
	if thing == null and G.zones and G.zones.zone_at(p) > 0:
		thing = CardModels.ZoneInfo.new(G.zones.zone_at(p))
	select(thing)

func _slot_near(sp: Vector2) -> Array:
	var best := []
	var bd := GRAB_PX
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state != Building.BUILT or b.mounted.is_empty():
			continue
		for i in b.mounted.size():
			var m = b.mounted[i]
			if m != null and is_instance_valid(m) and m.state != Building.DEAD:
				continue
			var d := _screen(b.slot_xform(i).origin).distance_to(sp)
			if d < bd:
				bd = d
				best = [b, i]
	return best

func slot_markers() -> Array:
	var show: bool = _is_gun_tool() or (selected != null and is_instance_valid(selected) and selected is Building and not selected.mounted.is_empty())
	var out := []
	if not show:
		return out
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state != Building.BUILT or b.mounted.is_empty():
			continue
		if not _is_gun_tool() and b != selected:
			continue
		for i in b.mounted.size():
			var m = b.mounted[i]
			if m == null or not is_instance_valid(m) or m.state == Building.DEAD:
				out.append(b.slot_xform(i).origin)
	return out

func wants_grab(sp: Vector2) -> bool:
	return _grab_kind(sp)[0] != ""

func _grab_kind(sp: Vector2) -> Array:
	if is_wall_tool():
		for i in plan.size():
			if _screen(plan[i]["pos"]).distance_to(sp) < GRAB_PX:
				return ["plan", i]
		return ["", -1]
	if tool == "_reshape":
		for i in rs_pts.size():
			if _rs_movable(i) and _screen(rs_pts[i]).distance_to(sp) < GRAB_PX:
				return ["rs", i]
		var edges := WallSystem.edges_of(rs_pts, rs_chain.get("closed", false))
		for i in edges.size():
			var m: Vector3 = ((edges[i][0] as Vector3) + (edges[i][1] as Vector3)) * 0.5
			if _screen(m).distance_to(sp) < GRAB_PX * 0.8:
				return ["rs_mid", i]
		return ["", -1]
	if not g_has:
		return ["", -1]
	if _has_rotate() and _screen(rotate_handle()).distance_to(sp) < GRAB_PX:
		return ["rotate", -1]
	if _is_line_tool():
		if _screen(Defs.cell_center(g_line_b)).distance_to(sp) < GRAB_PX:
			return ["line_b", -1]
		return ["", -1]
	if tool == "remove" or tool == "gate" or g_host != null:
		return ["", -1]
	if _screen(g_pos + Vector3(0, 0.5, 0)).distance_to(sp) < GRAB_PX * 1.4:
		return ["ghost", -1]
	return ["", -1]

func grab_start(sp: Vector2) -> void:
	var k := _grab_kind(sp)
	_drag = k[0]
	_drag_i = k[1]
	var p := _ground(sp)
	if _drag == "ghost" and p != Vector3.INF:
		_drag_off = g_pos - Vector3(p.x, 0, p.z)
	elif _drag == "rs_mid":
		rs_hist.append(rs_pts.duplicate())
		var edges := WallSystem.edges_of(rs_pts, rs_chain.get("closed", false))
		var m: Vector3 = ((edges[_drag_i][0] as Vector3) + (edges[_drag_i][1] as Vector3)) * 0.5
		rs_pts.insert(_drag_i + 1, m)
		_drag = "rs"
		_drag_i += 1
		_refresh_reshape()
	elif _drag == "rs":
		rs_hist.append(rs_pts.duplicate())

func grab_move(sp: Vector2) -> void:
	var p := _ground(sp)
	if p == Vector3.INF or _drag == "":
		return
	p = Vector3(p.x, 0, p.z)
	match _drag:
		"ghost":
			var q := p + _drag_off
			if tool == "_move" and not g_moving.rect:
				g_pos = grid_center(g_moving.kind, q)
			elif tool == "_move" or _is_prefab_tool():
				g_pos = snap_half(q)
			else:
				g_cell = BuildingManager.origin_for(tool, q)
				var sz := BuildingManager.size_of(tool)
				g_pos = Defs.cell_center(g_cell) + Vector3((sz - 1), 0, (sz - 1))
			_refresh_ghost()
		"rotate":
			var v := p - g_pos
			if v.length() > 0.3:
				g_yaw = snap_yaw(atan2(-v.x, -v.z))
				_refresh_ghost()
		"line_b":
			g_line_b = Defs.world_to_cell(p)
			_refresh_ghost()
		"plan":
			var sn: Dictionary = G.walls.snap(p)
			plan[_drag_i] = {"pos": sn["pos"], "type": sn["type"], "seg": sn["seg"]}
			_validate_plan()
			_draw_plan()
			plan_changed.emit()
		"rs":
			rs_pts[_drag_i] = snap_half(p)
			_refresh_reshape()

func grab_end(sp: Vector2, was_tap: bool) -> void:
	var d := _drag
	var i := _drag_i
	_drag = ""
	if d == "rs" and not was_tap:
		var n := rs_pts.size()
		var closed: bool = rs_chain.get("closed", false)
		for j in [i - 1, i + 1]:
			var jj: int = (j + n) % n if closed else j
			if jj >= 0 and jj < n and jj != i and (rs_pts[jj] as Vector3).distance_to(rs_pts[i]) < 1.0 and n > (3 if closed else 2):
				rs_pts.remove_at(i)
				break
		_refresh_reshape()
	if was_tap and d != "rs":
		tap(sp)

func grab_cancel() -> void:
	_drag = ""

func has_pending() -> bool:
	if tool == "bridge":
		return not br_a.is_empty()
	if is_wall_tool():
		return plan.size() >= 1
	if tool == "_reshape":
		return true
	return g_has

func pending_ok() -> bool:
	if tool == "bridge":
		return bridge_why() == ""
	if is_wall_tool():
		return (plan.size() >= 2 or (plan_closed and plan.size() >= 3)) and plan_bad < 0 and G.main.supplies >= plan_cost()
	if tool == "_reshape":
		return rs_info.get("why", "x") == "" and (not (rs_info.get("build", []) as Array).is_empty() or not (rs_info.get("remove", []) as Array).is_empty())
	return g_has and g_ok

func pending_anchor() -> Vector3:
	if tool == "bridge":
		if not br_b.is_empty():
			return br_b["pos"]
		return br_a.get("pos", Vector3.INF)
	if is_wall_tool():
		return Vector3(plan[-1]["pos"]) if not plan.is_empty() else Vector3.INF
	if tool == "_reshape":
		if rs_pts.is_empty():
			return Vector3.INF
		var c := Vector3.ZERO
		for p in rs_pts:
			c += p
		return c / rs_pts.size()
	if not g_has:
		return Vector3.INF
	if _is_line_tool():
		return Defs.cell_center(g_line_b)
	if tool == "gate":
		return g_spot.get("c", Vector3.INF)
	if tool == "remove" and g_target != null and is_instance_valid(g_target):
		return g_target.position
	return g_pos

func confirm() -> void:
	if not has_pending():
		return
	if not pending_ok():
		var why := g_why
		if is_wall_tool():
			why = plan_why if plan_why != "" else ("Tap at least two points" if plan.size() < 2 else "Not enough supplies")
		elif tool == "_reshape":
			why = String(rs_info.get("why", ""))
			if why == "":
				why = "Nothing changed yet"
		message.emit(why if why != "" else "Can't build there")
		return
	var made: Array = []
	if tool == "bridge":
		var bb = G.buildings.place_bridge(br_a, br_b)
		if bb == null:
			message.emit(bridge_why() if bridge_why() != "" else "Can't build that bridge")
			return
		made = [bb]
		placed.emit("bridge", 1)
		_clear_bridge()
		if G.sfx:
			G.sfx.play("place", Vector3.ZERO)
		_start_undo(made)
		plan_changed.emit()
		return
	if is_wall_tool():
		var n: int = G.walls.add_plan(tool, plan, plan_closed)
		if n == 0:
			message.emit("Not enough supplies")
			return
		made = G.walls.last_plan.duplicate()
		placed.emit(tool, n)
		_clear_plan()
	elif tool == "_reshape":
		var why2: String = G.walls.reshape(rs_chain, rs_pts)
		if why2 != "":
			message.emit(why2)
			return
		placed.emit("reshape", 1)
		set_tool("")
		return
	elif tool == "_move":
		var why3: String = G.buildings.move_building(g_moving, g_pos, g_yaw)
		if why3 != "":
			message.emit(why3)
			return
		var lp = G.buildings.last_placed
		if lp != null and is_instance_valid(lp) and lp is Building and lp.move_from == g_moving:
			made = [G.buildings.last_placed]
		placed.emit("move", 1)
		set_tool("")
		_start_undo(made)
		return
	elif tool == "remove":
		G.buildings.remove_thing(g_target)
		placed.emit("remove", 1)
		_clear_ghost()
	elif tool == "gate":
		var why4: String = G.walls.place_gate(g_spot.get("c", Vector3.ZERO))
		if why4 != "":
			message.emit(why4)
			return
		made = [G.buildings.last_placed]
		placed.emit("gate", 1)
		_clear_ghost()
	elif _is_line_tool():
		for c in _line_cells:
			if G.buildings.place(tool, c):
				made.append(G.buildings.last_placed)
		if made.is_empty():
			message.emit(G.buildings.check(tool, _line_cells[0]) if not _line_cells.is_empty() else "Can't build there")
			return
		placed.emit(tool, made.size())
		_clear_ghost()
	elif _is_prefab_tool():
		var b: Building = G.buildings.place_rect(tool, g_pos, g_yaw)
		if b == null:
			message.emit("Can't build there")
			return
		made = [b]
		placed.emit(tool, 1)
		_clear_ghost()
	elif g_host != null:
		var m: Building = G.buildings.mount(g_host, g_slot, tool)
		if m == null:
			message.emit("Can't put that there")
			return
		made = [m]
		placed.emit(tool, 1)
		_clear_ghost()
	else:
		if not G.buildings.place(tool, g_cell, g_yaw):
			message.emit(G.buildings.check(tool, g_cell))
			return
		made = [G.buildings.last_placed]
		placed.emit(tool, 1)
		_clear_ghost()
	if G.sfx:
		G.sfx.play("place", Vector3.ZERO)
	_start_undo(made)
	plan_changed.emit()

func cancel() -> void:
	if tool == "_move" or tool == "_reshape" or tool.begins_with("_heli"):
		set_tool("")
		return
	_clear_bridge()
	_clear_ghost()
	_clear_plan()
	plan_changed.emit()

func undo_point() -> void:
	if is_wall_tool() and not plan.is_empty():
		plan.pop_back()
		plan_closed = false
		_validate_plan()
		_draw_plan()
	elif tool == "_reshape" and not rs_hist.is_empty():
		rs_pts = rs_hist.pop_back()
		_refresh_reshape()
	plan_changed.emit()

func _start_undo(items: Array) -> void:
	undo_items = []
	for it in items:
		if it != null:
			undo_items.append(it)
	undo_t = UNDO_TIME if not undo_items.is_empty() else 0.0

func undo_last() -> int:
	var n := 0
	for it in undo_items:
		if is_instance_valid(it) and G.buildings.undo_thing(it):
			n += 1
	undo_items.clear()
	undo_t = 0.0
	if n > 0:
		G.walls.refresh_posts()
	return n

func _process(dt: float) -> void:
	if undo_t > 0.0:
		undo_t -= dt
		if undo_t <= 0.0:
			undo_items.clear()
	if _ring != null and (_ring.visible or selected != null):
		_update_ring()
	_update_range()

func select(thing) -> void:
	if thing != null and thing != selected and G.sfx:
		G.sfx.play_ui("ui_open")
	selected = thing
	if G.hud:
		if thing == null:
			G.hud.hide_card()
		else:
			G.hud.show_card(thing)
	_update_ring()

func _update_ring() -> void:
	if _ring == null:
		_ring = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1, 1)
		_ring.mesh = pm
		_ring.material_override = Art.mat_select
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)
	var ok: bool = selected != null and is_instance_valid(selected) and selected is Node3D and G.hud != null and G.hud.card.visible
	if ok and selected is Building and selected.state == Building.DEAD:
		ok = false
	_ring.visible = ok
	if ok:
		var p: Vector3 = selected.position
		_ring.position = Vector3(p.x, maxf(0.0, p.y) + 0.06, p.z)
		if selected is LinearStructure:
			_ring.rotation.y = atan2(-selected.dir.z, selected.dir.x)
			_ring.scale = Vector3(selected.length + 1.0, 1, 2.0)
		elif selected is Building and selected.rect:
			_ring.rotation.y = selected.yaw
			_ring.scale = Vector3(selected.half.x * 2.5, 1, selected.half.y * 2.5)
		else:
			_ring.rotation.y = 0.0
			var sz := 1.0
			if selected is Building:
				sz = selected.size
			var w := Defs.CELL * sz * 1.25
			_ring.scale = Vector3(w, 1, w)

func _update_range() -> void:
	var r := 0.0
	var at := Vector3.ZERO
	if _is_gun_tool() and g_has:
		var bonus := 0.0
		if g_host != null:
			bonus = g_host.slot_bonus()
		elif G.walls and G.walls.port_near(g_pos, 3.2):
			bonus = Defs.PORT_BONUS
		r = Defs.gun_range(tool) * (1.0 + bonus)
		at = g_pos
	elif selected != null and is_instance_valid(selected) and selected is Building and selected.is_gun() and selected.state != Building.DEAD and G.hud and G.hud.card.visible:
		r = selected.gun_range()
		at = selected.position
	elif selected is CardModels.SlotPick and is_instance_valid(selected.host):
		r = Defs.TURRET_RANGE * (1.0 + selected.bonus())
		at = selected.spot()
	if r <= 0.0:
		if _range:
			_range.visible = false
		return
	if _range == null:
		_range = MeshInstance3D.new()
		_range_mat = StandardMaterial3D.new()
		_range_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_range_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_range_mat.albedo_color = Color(1.0, 0.75, 0.3, 0.55)
		_range_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_range.material_override = _range_mat
		_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_range)
	if absf(r - _range_r) > 0.05:
		_range_r = r
		_range.mesh = _ring_mesh(r)
	_range.visible = true
	_range.position = Vector3(at.x, 0.1, at.z)

static func _ring_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	var w := 0.18
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		st.add_vertex(p0 * (r - w))
		st.add_vertex(p0 * (r + w))
		st.add_vertex(p1 * (r + w))
		st.add_vertex(p0 * (r - w))
		st.add_vertex(p1 * (r + w))
		st.add_vertex(p1 * (r - w))
	return st.commit()

func _has_rotate() -> bool:
	if not g_has:
		return false
	if tool == "_move":
		return g_moving.rect or g_moving.is_gun()
	return _is_prefab_tool() or (_is_gun_tool() and g_host == null)

func rotate_handle() -> Vector3:
	var reach := 2.6
	if tool == "_move" and g_moving.rect:
		reach = maxf(g_moving.half.x, g_moving.half.y) + 1.8
	elif _is_prefab_tool():
		var h: Vector2 = Defs.BUILD[tool].get("half", Vector2.ONE)
		reach = maxf(h.x, h.y) + 1.8
	return g_pos + Vector3(-sin(g_yaw), 0, -cos(g_yaw)) * reach

func _ghost_kind_now() -> String:
	if tool == "_move":
		return g_moving.kind
	return tool

func _model_for(kind: String) -> String:
	if g_host != null and kind == "sniper":
		return "sniper_nest"
	return String(Defs.BUILD.get(kind, {}).get("model", kind))

func _refresh_ghost() -> void:
	if not g_has:
		_clear_ghost()
		return
	var kind := _ghost_kind_now()
	g_ok = false
	g_why = ""
	if tool == "remove":
		_show_remove()
		g_ok = g_target != null and is_instance_valid(g_target)
		plan_changed.emit()
		return
	if _is_line_tool():
		_show_line()
		plan_changed.emit()
		return
	var mk := _model_for(kind) if tool != "gate" else "concrete_gate"
	if _ghost == null or _ghost_kind != mk:
		if _ghost:
			_ghost.queue_free()
		_ghost = Node3D.new()
		var m := Art.model(mk)
		for n in m.find_children("*", "CPUParticles3D", true, false):
			n.queue_free()
		_ghost.add_child(m)
		Art.set_shadows(_ghost, false)
		add_child(_ghost)
		_ghost_kind = mk
	_ghost.visible = true
	if tool == "gate":
		g_ok = g_spot.get("ok", false) and G.main.supplies >= int(Defs.BUILD["gate"]["cost"])
		g_why = String(g_spot.get("reason", ""))
		if g_spot.has("c"):
			var d: Vector3 = g_spot["d"]
			_ghost.position = g_spot["c"]
			_ghost.rotation.y = atan2(-d.z, d.x)
	elif tool == "_move":
		_ghost.position = g_pos
		_ghost.rotation.y = g_yaw if g_moving.rect else 0.0
		if g_moving.rect:
			g_why = G.buildings.check_rect(g_moving.kind, g_pos, g_yaw, g_moving)
		else:
			var c := BuildingManager.origin_for(g_moving.kind, g_pos)
			g_why = "" if c == g_moving.cell else G.buildings.check(g_moving.kind, c, g_moving)
			_turn_ghost_gun(g_yaw)
		var moved: bool = g_pos.distance_to(Vector3(g_moving.position.x, 0, g_moving.position.z)) > 0.1
		if g_why == "" and moved and G.main.supplies < G.buildings.move_cost(g_moving):
			g_why = "Moving costs %d" % G.buildings.move_cost(g_moving)
		g_ok = g_why == ""
	elif _is_prefab_tool():
		_ghost.position = g_pos
		_ghost.rotation.y = g_yaw
		g_why = G.buildings.check_rect(tool, g_pos, g_yaw)
		if g_why == "" and G.main.supplies < G.buildings.cost_of(tool):
			g_why = "Not enough supplies"
		g_ok = g_why == ""
	elif g_host != null:
		_ghost.position = g_pos
		_ghost.rotation.y = 0.0
		g_why = G.buildings.unlock_why(tool)
		if g_why == "" and G.main.supplies < G.buildings.cost_of(tool):
			g_why = "Not enough supplies"
		g_ok = g_why == ""
	else:
		_ghost.position = Vector3(g_pos.x, G.grid.floor_y(g_cell) if G.grid.inb(g_cell) else 0.0, g_pos.z)
		_ghost.rotation.y = 0.0
		_turn_ghost_gun(g_yaw)
		g_why = G.buildings.check(tool, g_cell)
		if g_why == "" and G.main.supplies < G.buildings.cost_of(tool):
			g_why = "Not enough supplies"
		g_ok = g_why == ""
	Art.set_override(_ghost, Art.mat_ghost_ok if g_ok else Art.mat_ghost_bad)
	plan_changed.emit()

func _turn_ghost_gun(y: float) -> void:
	if _ghost == null:
		return
	var yaw := _ghost.find_child("Yaw", true, false) as Node3D
	if yaw:
		yaw.rotation.y = y
	elif Defs.GUNS.has(_ghost_kind_now()):
		_ghost.rotation.y = y

func _show_remove() -> void:
	if _remove_box == null:
		_remove_box = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		_remove_box.mesh = bm
		_remove_box.material_override = Art.mat_ghost_bad
		_remove_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_remove_box)
	if g_target == null or not is_instance_valid(g_target):
		_remove_box.visible = false
		return
	_remove_box.visible = true
	var t = g_target
	if t is LinearStructure:
		_remove_box.position = t.position + Vector3(0, 1.2, 0)
		_remove_box.rotation.y = atan2(-t.dir.z, t.dir.x)
		_remove_box.scale = Vector3(t.length, 2.4, t.thick + 0.3)
	elif t is Building and t.rect:
		_remove_box.position = t.position + Vector3(0, 1.5, 0)
		_remove_box.rotation.y = t.yaw
		_remove_box.scale = Vector3(t.half.x * 2.0 + 0.2, 3.0, t.half.y * 2.0 + 0.2)
	else:
		var sz := 1
		if t is Building:
			sz = t.size
		_remove_box.position = t.position + Vector3(0, 1.0, 0)
		_remove_box.rotation.y = 0.0
		_remove_box.scale = Vector3(Defs.CELL * sz, 2.0, Defs.CELL * sz)

func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a.x < 0 and a.y < 0:
		return out
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while out.size() < MAX_LINE:
		out.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return out

func _show_line() -> void:
	_line_cells = _line(g_line_a, g_line_b)
	var budget: int = G.main.supplies
	while _line_ghosts.size() < _line_cells.size():
		var root := Node3D.new()
		if tool == "dig":
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(Defs.CELL * 0.96, 0.25, Defs.CELL * 0.96)
			mi.mesh = bm
			mi.position.y = -0.05
			root.add_child(mi)
		else:
			root.add_child(Art.model(String(Defs.BUILD[tool]["model"])))
		Art.set_shadows(root, false)
		add_child(root)
		_line_ghosts.append(root)
		_line_ok.append(false)
	var any := false
	for i in _line_ghosts.size():
		var gh := _line_ghosts[i]
		if i >= _line_cells.size():
			gh.visible = false
			continue
		var c := _line_cells[i]
		var ok: bool = G.buildings.check(tool, c) == ""
		var cost: int = G.buildings.cost_of(tool)
		if ok and cost > budget:
			ok = false
		if ok:
			budget -= cost
			any = true
		gh.visible = G.grid.inb(c)
		var p := Defs.cell_center(c)
		p.y = G.grid.floor_y(c) if G.grid.inb(c) else 0.0
		gh.position = p
		if _line_ok[i] != ok or not gh.has_meta("tinted"):
			_line_ok[i] = ok
			gh.set_meta("tinted", true)
			Art.set_override(gh, Art.mat_ghost_ok if ok else Art.mat_ghost_bad)
	g_ok = any
	g_why = "" if any else "Can't build there"

func _clear_ghost() -> void:
	g_has = false
	g_target = null
	g_spot = {}
	g_host = null
	g_slot = -1
	g_line_a = Vector2i(-1, -1)
	if _ghost:
		_ghost.queue_free()
		_ghost = null
		_ghost_kind = ""
	for gh in _line_ghosts:
		gh.queue_free()
	_line_ghosts.clear()
	_line_ok.clear()
	_line_cells.clear()
	if _remove_box:
		_remove_box.visible = false

func _bridge_tap(p: Vector3) -> void:
	var to: Vector3 = br_a.get("pos", Vector3.INF) if not br_a.is_empty() else Vector3.INF
	var an: Dictionary = G.net.anchor_near(p, to) if G.net else {}
	if an.is_empty():
		message.emit("Tap a roof, a fortified walkway or a stair top")
		return
	if br_a.is_empty() or not br_b.is_empty():
		br_a = an
		br_b = {}
	else:
		if an["ref"] == br_a["ref"]:
			message.emit("Pick somewhere else for the other end")
			return
		var a2: Dictionary = G.net.anchor_near(br_a["pos"], an["pos"])
		if not a2.is_empty() and a2["ref"] == br_a["ref"]:
			br_a = a2
		br_b = an
	if G.sfx:
		G.sfx.play("place", p)
	_draw_bridge()
	plan_changed.emit()

func bridge_why() -> String:
	if br_a.is_empty() or br_b.is_empty():
		return "Tap the other end"
	var pa: Vector3 = br_a["pos"]
	var pb: Vector3 = br_b["pos"]
	var l := Vector2(pb.x - pa.x, pb.z - pa.z).length()
	if l < 2.0:
		return "Too short"
	if l > float(Defs.BUILD["bridge"].get("max_len", 16.0)):
		return "Too long (16 m at most)"
	if absf(pb.y - pa.y) > 1.6:
		return "The ends are at different heights"
	if G.main.supplies < G.buildings.bridge_cost(pa, pb):
		return "Not enough supplies"
	return ""

func _draw_bridge() -> void:
	if _br_ghost:
		_br_ghost.queue_free()
		_br_ghost = null
	if br_a.is_empty():
		return
	_br_ghost = Node3D.new()
	add_child(_br_ghost)
	var pa: Vector3 = br_a["pos"]
	var mark := _post_mesh()
	mark.reparent(_br_ghost)
	mark.position = pa + Vector3(0, 0.2, 0)
	mark.material_override = Art.mat_ghost_ok
	if br_b.is_empty():
		return
	var pb: Vector3 = br_b["pos"]
	var ok := bridge_why() == ""
	var l := maxf(0.5, Vector2(pb.x - pa.x, pb.z - pa.z).length())
	var n := maxi(1, int(ceil(l / 6.0)))
	var dirv := Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized()
	for i in n:
		var m := Art.model("roof_bridge")
		m.position = pa.lerp(pb, float(i) / n)
		m.rotation = Vector3(0, atan2(-dirv.z, dirv.x), atan2(pb.y - pa.y, l))
		m.scale = Vector3(l / n / 4.0, 1, 1)
		Art.set_override(m, Art.mat_ghost_ok if ok else Art.mat_ghost_bad)
		Art.set_shadows(m, false)
		_br_ghost.add_child(m)

func _clear_bridge() -> void:
	br_a = {}
	br_b = {}
	if _br_ghost:
		_br_ghost.queue_free()
		_br_ghost = null

func bridge_label() -> String:
	if br_a.is_empty():
		return ""
	if br_b.is_empty():
		return "Now tap the other end"
	var why := bridge_why()
	return why if why != "" else "Bridge %d" % G.buildings.bridge_cost(br_a["pos"], br_b["pos"])

func _heli_pick(p: Vector3) -> void:
	if heli_pad == null or not is_instance_valid(heli_pad) or heli_pad.heli == null or not is_instance_valid(heli_pad.heli):
		set_tool("")
		return
	var h = heli_pad.heli
	var why := ""
	if tool == "_heli_rescue":
		var g = G.people.group_near(p, 14.0)
		if g == null:
			message.emit("Tap a group of survivors (SOS)")
			return
		why = h.start_rescue(g)
	else:
		why = h.start_patrol(p)
	if why != "":
		message.emit(why)
		return
	if G.sfx:
		G.sfx.play_ui("ui_confirm")
	if G.hud:
		G.hud.toast("The %s is on its way" % h.display_name())
	set_tool("")

func _plan_tap(p: Vector3) -> void:
	if plan_closed:
		message.emit("Tap the tick to build it, or UNDO")
		return
	if not plan.is_empty() and plan.size() >= 2 and String(plan[-1]["type"]) in ["vertex", "segment", "building"]:
		message.emit("Joined. Tap the tick to build it, or UNDO")
		return
	var sn: Dictionary = G.walls.snap(p)
	var pos: Vector3 = sn["pos"]
	if plan.size() >= 3:
		var first: Vector3 = plan[0]["pos"]
		if Vector2(first.x - p.x, first.z - p.z).length() < 1.6:
			var why0: String = G.walls.check_edge(plan[-1]["pos"], first)
			if why0 != "":
				message.emit(why0)
				return
			plan_closed = true
			_validate_plan()
			_draw_plan()
			plan_changed.emit()
			return
	if sn["type"] == "" and plan.size() >= 1:
		var last: Vector3 = plan[-1]["pos"]
		var prev := Vector3(1, 0, 0)
		if plan.size() >= 2:
			prev = last - Vector3(plan[-2]["pos"])
		pos = WallSystem.angle_snap(prev, last, pos)
	if plan.is_empty():
		var edge := Defs.HALF - 3.0
		if absf(pos.x) > edge or absf(pos.z) > edge:
			message.emit("Too close to the edge")
			return
	else:
		var why: String = G.walls.check_edge(plan[-1]["pos"], pos)
		if why != "":
			message.emit(why)
			return
		if G.main.supplies < plan_cost() + G.walls.edge_cost(tool, plan[-1]["pos"], pos):
			message.emit("Not enough supplies")
			return
	plan.append({"pos": pos, "type": sn["type"], "seg": sn["seg"]})
	if G.sfx:
		G.sfx.play("place", pos)
	_validate_plan()
	_draw_plan()
	plan_changed.emit()

func _validate_plan() -> void:
	plan_bad = -1
	plan_why = ""
	var pts: Array = []
	for q in plan:
		pts.append(q["pos"])
	if plan_closed and pts.size() >= 3:
		pts.append(pts[0])
	for i in pts.size() - 1:
		var why: String = G.walls.check_edge(pts[i], pts[i + 1])
		if why != "":
			plan_bad = i
			plan_why = why
			return

func plan_cost() -> int:
	var c := 0
	var pts: Array = []
	for q in plan:
		pts.append(q["pos"])
	if plan_closed and pts.size() >= 3:
		pts.append(pts[0])
	for i in pts.size() - 1:
		c += G.walls.edge_cost(tool, pts[i], pts[i + 1])
	return c

func plan_length() -> float:
	var l := 0.0
	for i in plan.size() - 1:
		l += Vector3(plan[i]["pos"]).distance_to(plan[i + 1]["pos"])
	if plan_closed and plan.size() >= 3:
		l += Vector3(plan[-1]["pos"]).distance_to(plan[0]["pos"])
	return l

func _clear_plan() -> void:
	plan.clear()
	plan_closed = false
	plan_bad = -1
	plan_why = ""
	for m in _plan_meshes:
		m.queue_free()
	_plan_meshes.clear()
	for m in _plan_posts:
		m.queue_free()
	_plan_posts.clear()

func _seg_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _post_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.3
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _place_seg(mi: MeshInstance3D, kind: String, a: Vector3, b: Vector3, ok: bool) -> void:
	var d: Dictionary = Defs.BUILD[kind]
	var h := float(d.get("height", 2.2))
	var th := float(d.get("thick", 0.6))
	var l := maxf(0.05, a.distance_to(b))
	var dirv := (b - a) / l
	mi.position = (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
	mi.rotation = Vector3(0, atan2(-dirv.z, dirv.x), 0)
	mi.scale = Vector3(l, h, th)
	mi.material_override = Art.mat_ghost_ok if ok else Art.mat_ghost_bad
	mi.visible = true

func _draw_plan() -> void:
	var pts: Array = []
	for q in plan:
		pts.append(q["pos"])
	if plan_closed and pts.size() >= 3:
		pts.append(pts[0])
	var segs: Array = []
	for i in pts.size() - 1:
		for pc in G.walls.clip_edge(pts[i], pts[i + 1]):
			segs.append([pc[0], pc[1], i != plan_bad])
	var need := segs.size()
	while _plan_meshes.size() < need:
		_plan_meshes.append(_seg_mesh())
	for i in _plan_meshes.size():
		if i < need:
			_place_seg(_plan_meshes[i], tool, segs[i][0], segs[i][1], segs[i][2])
		else:
			_plan_meshes[i].visible = false
	while _plan_posts.size() < plan.size():
		_plan_posts.append(_post_mesh())
	for i in _plan_posts.size():
		if i < plan.size():
			_plan_posts[i].position = Vector3(plan[i]["pos"]) + Vector3(0, 0.15, 0)
			_plan_posts[i].material_override = Art.mat_ghost_ok
			_plan_posts[i].visible = true
		else:
			_plan_posts[i].visible = false

func _rs_movable(i: int) -> bool:
	if rs_chain.get("closed", false):
		return true
	if i == 0 and rs_chain.get("pin_a", false):
		return false
	if i == rs_pts.size() - 1 and rs_chain.get("pin_b", false):
		return false
	return true

func _refresh_reshape() -> void:
	if rs_chain.is_empty():
		return
	rs_info = G.walls.reshape_plan(rs_chain, rs_pts)
	var build: Array = rs_info["build"]
	while _rs_meshes.size() < build.size():
		_rs_meshes.append(_seg_mesh())
	for i in _rs_meshes.size():
		if i < build.size():
			var e: Array = build[i]
			var ok: bool = G.walls.check_segment(e[0], e[1], rs_chain["segs"]) == ""
			_place_seg(_rs_meshes[i], String(rs_chain["kind"]), e[0], e[1], ok)
		else:
			_rs_meshes[i].visible = false
	plan_changed.emit()

func _clear_reshape() -> void:
	rs_chain = {}
	rs_pts = []
	rs_hist.clear()
	rs_info = {}
	for m in _rs_meshes:
		m.queue_free()
	_rs_meshes.clear()

func handles() -> Array:
	var out := []
	if is_wall_tool():
		for i in plan.size():
			out.append({"pos": plan[i]["pos"], "kind": "point", "hot": _drag == "plan" and _drag_i == i})
	elif tool == "_reshape":
		for i in rs_pts.size():
			out.append({"pos": rs_pts[i], "kind": "corner" if _rs_movable(i) else "pin", "hot": _drag == "rs" and _drag_i == i})
		for e in WallSystem.edges_of(rs_pts, rs_chain.get("closed", false)):
			out.append({"pos": ((e[0] as Vector3) + (e[1] as Vector3)) * 0.5, "kind": "mid", "hot": false})
	elif g_has:
		if _has_rotate():
			out.append({"pos": rotate_handle(), "kind": "rotate", "hot": _drag == "rotate", "from": g_pos})
		if _is_line_tool():
			out.append({"pos": Defs.cell_center(g_line_b), "kind": "end", "hot": _drag == "line_b"})
	return out

func pending_label() -> String:
	if tool == "bridge":
		return bridge_label()
	if is_wall_tool():
		if plan.is_empty():
			return ""
		if plan_bad >= 0:
			return plan_why
		if plan.size() == 1:
			return "Tap the next point"
		return "%.1f m  ·  %d%s" % [plan_length(), plan_cost(), "  (closed)" if plan_closed else ""]
	if tool == "_reshape":
		if rs_info.get("why", "") != "":
			return rs_info["why"]
		return "Cost %d" % int(rs_info.get("cost", 0))
	if not g_has:
		return ""
	if not g_ok:
		return g_why
	if tool == "_move":
		return "Move  %d" % G.buildings.move_cost(g_moving)
	if tool == "remove":
		return "Remove  +%d" % G.buildings.refund_of(g_target)
	if _is_line_tool():
		return "%d  ·  %d each" % [_line_cells.size(), G.buildings.cost_of(tool)]
	if g_host != null:
		return "%s on top  ·  +%d%% range" % [String(Defs.BUILD[tool]["name"]), int(g_host.slot_bonus() * 100.0)]
	var cost: int = int(Defs.BUILD["gate"]["cost"]) if tool == "gate" else G.buildings.cost_of(tool)
	return "%d" % cost
