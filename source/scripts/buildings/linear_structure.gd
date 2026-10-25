class_name LinearStructure
extends Building
var a := Vector3.ZERO
var b := Vector3.ZERO
var length := 1.0
var dir := Vector3.RIGHT
var thick := 0.6
var nav_cells := PackedInt32Array()
var pieces: Array[Node3D] = []
var rebuild_of := ""
var ported := false
var _port_pieces: Array[Node3D] = []
var _leaves: Array[Node3D] = []
var _open := 0.0
var _want_open := 0.0
var _gate_cells := {}
var _gate_t := 0.0
var heavy := false
# Zombies pressing on this wall right now (brutes count 2), from ZombieManager.
var press := 0

# How many zombies it takes to pile up and climb over it.
func pile_need() -> int:
	return maxi(3, int(ceil(float(def.get("height", 2.2)) * 3.5)))

func setup_linear(k: String, d: Dictionary, pa: Vector3, pb: Vector3, blueprint: bool, with_ports: bool = false) -> void:
	kind = k
	def = d
	ported = with_ports and d.has("port_model")
	a = Vector3(pa.x, 0, pa.z)
	b = Vector3(pb.x, 0, pb.z)
	length = maxf(0.05, a.distance_to(b))
	dir = (b - a) / length
	thick = float(d.get("thick", 0.6))
	if d.has("hp_per_m"):
		max_hp = float(d["hp_per_m"]) * length
	else:
		max_hp = float(d.get("hp", 500.0))
	hp = max_hp
	position = (a + b) * 0.5
	nav_cells = G.grid.supercover(a, b)
	_build_visual()
	if blueprint:
		state = BLUEPRINT
		Art.set_override(model, Art.mat_blueprint)
		Art.set_shadows(model, false)
	else:
		_finish(true)

func _build_visual() -> void:
	model = Node3D.new()
	model.name = "Pieces"
	add_child(model)
	var ang := atan2(-dir.z, dir.x)
	var mname := String(def.get("model", "wall"))
	if kind == "gate":
		if heavy:
			mname = "fortified_gate"
		var g := Art.model(mname)
		g.rotation.y = ang
		g.scale = Vector3(length / Defs.GATE_WIDTH, 1, 1)
		model.add_child(g)
		pieces.append(g)
		for n in ["LeafL", "LeafR"]:
			var leaf := g.find_child(n, true, false) as Node3D
			if leaf:
				_leaves.append(leaf)
		return
	var n := maxi(1, roundi(length / Defs.WALL_PIECE))
	var pl := length / n
	var port_from := -1
	var port_to := -1
	if ported:
		port_from = (n - 1) / 2
		port_to = port_from + (1 if n >= 4 else 0)
	var port_ang := ang
	var walk := bool(def.get("walk", false))
	if ported or walk:
		var out_n := -inward()
		if Vector3(dir.z, 0, -dir.x).dot(out_n) < 0.0:
			port_ang = ang + PI
	for i in n:
		var is_port := port_from >= 0 and i >= port_from and i <= port_to
		var m := Art.model(String(def.get("port_model", mname)) if is_port else mname)
		m.position = a - position + dir * (pl * (i + 0.5))
		m.rotation.y = port_ang if (is_port or walk) else ang
		m.scale = Vector3(pl / Defs.WALL_PIECE, 1, 1)
		model.add_child(m)
		pieces.append(m)
		if is_port:
			_port_pieces.append(m)

func cells() -> Array[Vector2i]:
	return []

func display_name() -> String:
	return String(def.get("name", kind))

func long_name() -> String:
	if ported:
		return String(def.get("long", kind)) + " (ports)"
	return super.long_name()

func is_wallish() -> bool:
	return true

func edge_distance(p: Vector3) -> float:
	return maxf(0.0, seg_distance(p) - thick * 0.5)

func seg_distance(p: Vector3) -> float:
	var ap := Vector3(p.x - a.x, 0, p.z - a.z)
	var t := clampf(ap.dot(dir), 0.0, length)
	var q := a + dir * t
	return Vector2(p.x - q.x, p.z - q.z).length()

func closest_point(p: Vector3) -> Vector3:
	var ap := Vector3(p.x - a.x, 0, p.z - a.z)
	var t := clampf(ap.dot(dir), 0.0, length)
	return a + dir * t

func push_out(p: Vector3, r: float) -> Vector3:
	var q := closest_point(p)
	var dx := p.x - q.x
	var dz := p.z - q.z
	var d := sqrt(dx * dx + dz * dz)
	var need := thick * 0.5 + r
	if d >= need:
		return p
	if d < 0.0001:
		dx = -dir.z
		dz = dir.x
		d = 1.0
	return Vector3(q.x + dx / d * need, p.y, q.z + dz / d * need)

func inward() -> Vector3:
	var n := Vector3(-dir.z, 0, dir.x)
	if G.zones:
		if G.zones.zone_at(position + n * 1.3) > 0:
			return n
		if G.zones.zone_at(position - n * 1.3) > 0:
			return -n
	return n if (Defs.hq_center() - position).dot(n) > 0.0 else -n

func entry_point() -> Vector3:
	return position + inward() * 1.3

func access_goals() -> Dictionary:
	return G.grid.point_goals(entry_point(), 1)

func job_adjacent() -> bool:
	return true

func job_goals() -> Dictionary:
	return G.grid.ring_goals(nav_cells)

func job_world_pos() -> Vector3:
	return position

func capacity() -> int:
	if kind == "gate":
		return 0
	return 2 if ported or is_walk() else 0

func is_walk() -> bool:
	return bool(def.get("walk", false)) and not pieces.is_empty()

func soldier_range() -> float:
	return Defs.SOLDIER_RANGE * (1.0 + float(def.get("walk_bonus", 0.0))) + 3.0

func walk_spots() -> Array:
	var out := []
	if pieces.is_empty():
		return out
	var m: Node3D = pieces[pieces.size() / 2]
	for nm in ["Walk1", "Walk2"]:
		var w := m.find_child(nm, true, false) as Node3D
		if w:
			out.append(w.global_position)
	if out.is_empty():
		out.append(position + Vector3(0, float(def.get("nest_h", 3.7)), 0) + inward() * 0.5)
	return out

func port_points() -> Array:
	var out := []
	if is_walk() and not ported:
		for w in walk_spots():
			out.append(w + Vector3(0, 1.5, 0))
		return out
	for m in _port_pieces:
		var found := false
		for i in 4:
			var pm := m.find_child("Port%d" % (i + 1), true, false) as Node3D
			if pm:
				out.append(pm.global_position)
				found = true
		if not found:
			out.append(m.global_position + Vector3(0, float(def.get("height", 2.2)) * 0.6, 0))
	if out.is_empty() and ported:
		out.append(position + Vector3(0, 1.4, 0))
	return out

func perch_for(s):
	if is_walk():
		var ws := walk_spots()
		var k0 := clampi(occupants.find(s), 0, ws.size() - 1)
		return ws[k0]
	var pts := port_points()
	if pts.is_empty():
		return null
	var k := clampi(occupants.find(s), 0, 1)
	var p: Vector3 = pts[k % pts.size()]
	var side := (-1.0 if k == 0 else 1.0) * (0.45 if pts.size() == 1 else 0.0)
	return Vector3(p.x, maxf(0.0, p.y - 1.45), p.z) + inward() * (thick * 0.5 + 0.45) + dir * side

func port_close(p: Vector3, r: float) -> bool:
	if not ported or state != BUILT:
		return false
	var inn := inward()
	if (p - position).dot(inn) < 0.0:
		return false
	for q in port_points():
		if Vector2(p.x - q.x, p.z - q.z).length() <= r:
			return true
	return false

func work(dt: float) -> bool:
	if state != BLUEPRINT:
		return true
	if zombies_close():
		return false
	var t := float(def.get("time_per_m", 0.0)) * length
	if t <= 0.0:
		t = float(def.get("time", 4.0))
	progress += dt / maxf(0.5, t)
	if progress >= 1.0:
		_finish(false)
		return true
	build_look()
	return false

func _rise_model() -> Node3D:
	var dup := model.duplicate() as Node3D
	return dup

func _make_scaffold() -> MeshInstance3D:
	var h := float(def.get("height", 2.2))
	var mi := MeshInstance3D.new()
	mi.mesh = Art.scaffold_mesh(length, thick + 0.3, h)
	mi.material_override = Art.mat_vc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = atan2(-dir.z, dir.x)
	return mi

func _on_damage_stage(st: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = get_instance_id()
	for m in pieces:
		if kind == "gate":
			continue
		var lean := 0.0
		var drop := 1.0
		if st >= 3:
			lean = r.randf_range(-0.07, 0.07)
			drop = r.randf_range(0.7, 0.92)
		elif st >= 2:
			lean = r.randf_range(-0.03, 0.03)
			drop = r.randf_range(0.88, 1.0)
		m.rotation.z = lean
		m.scale.y = drop

func zombies_close() -> bool:
	if G.zombies == null:
		return false
	return G.zombies.any_near(a, 2.0) or G.zombies.any_near(position, 2.0) or G.zombies.any_near(b, 2.0)

func _finish(instant: bool) -> void:
	state = BUILT
	progress = 1.0
	_clear_build_look()
	Art.set_override(model, null)
	Art.set_shadows(model, true)
	G.grid.mark_nav(nav_cells, Grid.N_GATE if kind == "gate" else Grid.N_WALL, self)
	G.grid.notify_paths_changed()
	if not instant and G.fx:
		G.fx.dust(position + Vector3(0, 0.4, 0), 1.0)
	if not instant and G.sfx:
		G.sfx.play("build", position)
	if G.walls:
		G.walls.refresh_posts()
	if edit_group != null:
		edit_group.check()

func destroy(effects: bool) -> void:
	if state == DEAD:
		return
	var was_built := state == BUILT
	state = DEAD
	release_soldiers()
	if G.fx:
		G.fx.smoke_detach(self)
	G.grid.clear_nav(nav_cells, self)
	if G.buildings:
		G.buildings.on_removed(self)
	if G.walls:
		G.walls.on_removed(self, effects and was_built)
	if effects and G.fx:
		for i in mini(3, pieces.size()):
			var p := a + dir * (length * (i + 0.5) / 3.0)
			G.fx.debris(p + Vector3(0, 0.8, 0), 1)
			G.fx.dust(p + Vector3(0, 0.5, 0), 1.4)
		if G.cam:
			G.cam.shake(0.25)
		if G.sfx:
			G.sfx.play("break", position)
	if edit_group != null:
		edit_group.check()
	G.grid.notify_paths_changed()
	queue_free()

func card_lines() -> Array:
	if state == BLUEPRINT:
		var q := ""
		if G.workers:
			var pos: int = G.workers.queue_pos(self)
			if pos > 0:
				q = "  ·  queue %d of %d" % [pos, G.workers.pending_count()]
		if rebuild_of != "":
			q += "  ·  repair (goes first)"
		return ["Being built  %d%%" % int(progress * 100.0) + q]
	if replaced_by != null:
		return ["Being replaced: stays up until the new part is done"]
	if kind == "gate":
		return ["Opens for people, not zombies"]
	var out := ["%.1f m  ·  %s" % [length, String(def.get("about", ""))]]
	if ported or is_walk():
		var coming := "  (+%d coming)" % incoming.size() if not incoming.is_empty() else ""
		out.append("%s: soldiers %d/2%s" % ["Walkway" if is_walk() and not ported else "Firing ports", occupants.size(), coming])
	return out

func card_buttons() -> Array:
	if state == BLUEPRINT:
		return [["sell", "CANCEL +%d" % paid, true]]
	var refund := int(round(paid * Defs.REFUND_BUILT))
	if kind == "gate" or replaced_by != null:
		return [["sell", "REMOVE +%d" % refund, replaced_by == null]]
	var w: WallSystem = G.walls
	var out := []
	var nt := WallSystem.next_tier(kind)
	if nt != "":
		var lock: String = G.buildings.unlock_why(nt)
		var word := "CONCRETE" if nt == "concrete" else "FORTIFY"
		if lock != "":
			out.append(["upgrade", "%s W%d" % [word, int(Defs.BUILD[nt].get("unlock", 0))], false])
		else:
			out.append(["upgrade", "%s %d" % [word, w.upgrade_cost(self)], true])
			var rc: int = w.upgrade_run_cost(self)
			out.append(["upgrade_run", "ALL RUN %d" % rc, rc > 0])
	if is_walk() and not ported:
		var idle0: int = G.soldiers.idle_count() if G.soldiers else 0
		out.append(["assign", "WALKWAY" if free_slots() > 0 else "FULL", free_slots() > 0 and idle0 > 0])
	elif not ported:
		out.append(["ports", "PORTS %d" % w.ports_cost(self), true])
	else:
		var idle: int = G.soldiers.idle_count() if G.soldiers else 0
		out.append(["assign", "ASSIGN" if free_slots() > 0 else "FULL", free_slots() > 0 and idle > 0])
	out.append(["mount", "MOUNT GUN", true])
	out.append(["bastion", "BASTION %d" % int(Defs.BUILD[String(def.get("bastion", "bastion"))]["cost"]), true])
	out.append(["gate", "GATE %d" % int(Defs.BUILD["gate"]["cost"]), true])
	out.append(["reshape", "RESHAPE", true])
	out.append(["sell", "REMOVE +%d" % refund, true])
	return out

func tick(dt: float) -> void:
	if (ported or is_walk()) and state == BUILT and not occupants.is_empty():
		port_tick(dt)
	if kind != "gate" or state != BUILT or _leaves.is_empty():
		return
	_gate_t -= dt
	if _gate_t <= 0.0:
		_gate_t = 0.2
		if _gate_cells.is_empty():
			for i in nav_cells:
				_gate_cells[i] = true
		var want := 1.0 if G.people and G.people.anyone_passing(position, _gate_cells) else 0.0
		if G.sfx and want != _want_open:
			G.sfx.play("gate_open" if want > 0.5 else "gate_close", position)
		_want_open = want
	var want_now := _want_open
	_open = move_toward(_open, want_now, dt * 2.2)
	var s := smoothstep(0.0, 1.0, _open)
	_leaves[0].rotation.y = -s * 1.65
	if _leaves.size() > 1:
		_leaves[1].rotation.y = s * 1.65
