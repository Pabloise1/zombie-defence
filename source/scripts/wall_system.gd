class_name WallSystem
extends Node3D
const SNAP_VERTEX := 1.3
const SNAP_SEGMENT := 0.9
const BASTION_WIDTH := 3.0
var segments: Array = []
var broken_count := 0
var expansions: Array = []
var last_plan: Array = []
var rubble: Array = []
var auto_rebuild := true
var _auto_t := 0.0
var _posts := {}
var _post_kind := {}
var _post_built := {}
var _nest_check := false

static func vkey(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x * 4.0), roundi(p.z * 4.0))

func live() -> Array:
	var out := []
	for s in segments:
		if is_instance_valid(s) and s.state != Building.DEAD:
			out.append(s)
	return out

func snap(p: Vector3) -> Dictionary:
	var best := {"pos": Vector3(p.x, 0, p.z), "type": "", "seg": null}
	var bd := SNAP_VERTEX
	for s in live():
		for e in [s.a, s.b]:
			var d := Vector2(e.x - p.x, e.z - p.z).length()
			if d < bd:
				bd = d
				best = {"pos": e, "type": "vertex", "seg": s}
	if best["type"] != "":
		return best
	var sd := SNAP_SEGMENT
	for s in live():
		if s.kind == "gate":
			continue
		var d: float = s.seg_distance(p)
		if d < sd:
			var q: Vector3 = s.closest_point(p)
			if q.distance_to(s.a) > 0.6 and q.distance_to(s.b) > 0.6:
				sd = d
				best = {"pos": q, "type": "segment", "seg": s}
	if best["type"] != "":
		return best
	var bdd := 1.1
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state == Building.DEAD or b.host != null or b is LinearStructure:
			continue
		if not (b.rect or b == G.buildings.hq):
			continue
		var q2 := _building_edge_point(b, p)
		var d2 := Vector2(q2.x - p.x, q2.z - p.z).length()
		if d2 < bdd:
			bdd = d2
			best = {"pos": q2, "type": "building", "seg": b}
	return best

func _building_edge_point(b, p: Vector3) -> Vector3:
	var h: Vector2 = b.half if b.rect else Vector2(Defs.CELL * b.size * 0.5, Defs.CELL * b.size * 0.5)
	var y: float = b.yaw if b.rect else 0.0
	var l := (Vector3(p.x, 0, p.z) - Vector3(b.position.x, 0, b.position.z)).rotated(Vector3.UP, -y)
	var q := Vector3(clampf(l.x, -h.x, h.x), 0, clampf(l.z, -h.y, h.y))
	if absf(l.x) < h.x and absf(l.z) < h.y:
		if h.x - absf(l.x) < h.y - absf(l.z):
			q.x = signf(l.x) * h.x
		else:
			q.z = signf(l.z) * h.y
	for cx in [-h.x, h.x]:
		for cz in [-h.y, h.y]:
			if Vector2(q.x - cx, q.z - cz).length() < 0.9:
				q = Vector3(cx, 0, cz)
	return Vector3(b.position.x, 0, b.position.z) + q.rotated(Vector3.UP, y)

static func angle_snap(prev_dir: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var v := Vector3(b.x - a.x, 0, b.z - a.z)
	var l := v.length()
	if l < 0.01 or prev_dir.length_squared() < 0.01:
		return b
	var ang := atan2(v.z, v.x)
	var base := atan2(prev_dir.z, prev_dir.x)
	var rel := wrapf(ang - base, -PI, PI)
	var step := PI * 0.25
	var snapped := roundf(rel / step) * step
	if absf(rel - snapped) < deg_to_rad(5.0):
		var na := base + snapped
		return a + Vector3(cos(na), 0, sin(na)) * l
	return b

func cost_of(kind: String, length: float) -> int:
	var d: Dictionary = Defs.BUILD[kind]
	return int(ceil(float(d.get("per_m", 10)) * length))

func check_segment(a: Vector3, b: Vector3, ignore: Array = []) -> String:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	if l < Defs.WALL_MIN_SEG:
		return "Too short"
	var g: Grid = G.grid
	var edge := 3.0
	for p in [a, b]:
		if absf(p.x) > Defs.HALF - edge or absf(p.z) > Defs.HALF - edge:
			return "Too close to the edge"
	var planned := _planned_cells(ignore)
	for i in g.supercover(a, b):
		var c := g.ncell_of(i)
		var wp := Defs.nav_center(c)
		var near_end := Vector2(wp.x - a.x, wp.z - a.z).length() < 1.6 or Vector2(wp.x - b.x, wp.z - b.z).length() < 1.6
		var blk := g.nblk[i]
		var own = g.nown[i]
		if own != null and ignore.has(own):
			continue
		if blk == Grid.N_ROCK or blk == Grid.N_STATIC:
			return "Something's in the way"
		if blk == Grid.N_BUILD and not near_end:
			return "Something's in the way"
		var bc := Defs.nav_to_build(c)
		if g.inb(bc):
			var o = g.occ[g.idx(bc)]
			if o != null and not (o is LinearStructure) and not o.rect and o != G.buildings.hq:
				return "Something's in the way"
			if o != null and (o.rect or o == G.buildings.hq) and not near_end and blk != Grid.N_OPEN:
				return "Something's in the way"
			if g.is_trench(bc):
				return "Not across a trench"
			if g.digs[g.idx(bc)] != null:
				return "Not across a trench"
		if (blk == Grid.N_WALL or blk == Grid.N_GATE or planned.has(i)) and not near_end:
			return "Crosses a wall"
	return ""

func _planned_cells(ignore: Array = []) -> Dictionary:
	var d := {}
	for s in live():
		if s.state == Building.BLUEPRINT and not ignore.has(s):
			for i in s.nav_cells:
				d[i] = true
	return d
const CLIP_ANGLE := 0.975
const CLIP_OFF := 1.0

func clip_edge(a: Vector3, b: Vector3, ignore: Array = []) -> Array:
	a.y = 0.0
	b.y = 0.0
	var l := a.distance_to(b)
	if l < 0.01:
		return []
	var d := (b - a) / l
	var nrm := Vector3(-d.z, 0, d.x)
	var iv: Array = []
	for o in live():
		if ignore.has(o) or o.kind == "gate":
			continue
		if absf(o.dir.dot(d)) < CLIP_ANGLE:
			continue
		var ta: float = (o.a - a).dot(d)
		var tb: float = (o.b - a).dot(d)
		var pa: Vector3 = o.a
		var pb: Vector3 = o.b
		if tb < ta:
			var tt := ta
			ta = tb
			tb = tt
			pa = o.b
			pb = o.a
		if tb <= 0.05 or ta >= l - 0.05:
			continue
		var lo := maxf(ta, 0.0)
		var hi := minf(tb, l)
		var off_lo := absf((o.closest_point(a + d * lo) - (a + d * lo)).dot(nrm))
		var off_hi := absf((o.closest_point(a + d * hi) - (a + d * hi)).dot(nrm))
		if off_lo > CLIP_OFF or off_hi > CLIP_OFF:
			continue
		iv.append([ta, tb, pa, pb])
	if iv.is_empty():
		return [[a, b]]
	iv.sort_custom(func(x, y): return x[0] < y[0])
	var merged: Array = []
	for x in iv:
		if not merged.is_empty() and x[0] <= merged[-1][1] + 0.3:
			if x[1] > merged[-1][1]:
				merged[-1][1] = x[1]
				merged[-1][3] = x[3]
		else:
			merged.append(x.duplicate())
	var out: Array = []
	var cur_t := 0.0
	var cur_p := a
	for m in merged:
		if m[0] > cur_t + 0.5:
			out.append([cur_p, m[2]])
		if m[1] > cur_t:
			cur_t = m[1]
			cur_p = m[3]
	if cur_t < l - 0.5:
		out.append([cur_p, b])
	var res: Array = []
	for pc in out:
		if Vector3(pc[0]).distance_to(pc[1]) >= 0.5:
			res.append(pc)
	return res

func check_edge(a: Vector3, b: Vector3, ignore: Array = []) -> String:
	var pieces := clip_edge(a, b, ignore)
	for pc in pieces:
		var why := check_segment(pc[0], pc[1], ignore)
		if why == "Too short" and pieces.size() > 1:
			continue
		if why != "":
			return why
	return ""

func edge_cost(kind: String, a: Vector3, b: Vector3) -> int:
	var c := 0
	for pc in clip_edge(a, b):
		c += cost_of(kind, Vector3(pc[0]).distance_to(pc[1]))
	return c

func add_plan(kind: String, points: Array, closed: bool) -> int:
	var pts: Array = points.duplicate()
	if closed and pts.size() >= 3:
		pts.append(pts[0])
	var total := 0
	for i in pts.size() - 1:
		total += edge_cost(kind, pts[i]["pos"], pts[i + 1]["pos"])
	if total <= 0 or not G.main.spend(total):
		return 0
	for i in pts.size():
		var p: Dictionary = pts[i]
		if p["type"] == "segment" and is_instance_valid(p["seg"]) and p["seg"].state != Building.DEAD:
			var on_line := false
			for j in [i - 1, i + 1]:
				if j >= 0 and j < pts.size():
					var v: Vector3 = Vector3(pts[j]["pos"]) - Vector3(p["pos"])
					if v.length() > 0.01 and absf(v.normalized().dot(p["seg"].dir)) > CLIP_ANGLE:
						on_line = true
			if not on_line:
				split_at(p["seg"], p["pos"])
	var made: Array = []
	for i in pts.size() - 1:
		for pc in clip_edge(pts[i]["pos"], pts[i + 1]["pos"]):
			var a: Vector3 = pc[0]
			var b: Vector3 = pc[1]
			var segs := lay(kind, a, b, cost_of(kind, a.distance_to(b)), false)
			_cover_rubble(segs)
			made.append_array(segs)
	last_plan = made
	if not closed and pts.size() >= 2:
		var t0: String = pts[0]["type"]
		var t1: String = pts[-1]["type"]
		if (t0 == "vertex" or t0 == "segment") and (t1 == "vertex" or t1 == "segment"):
			expansions.append({"segs": made, "a": vkey(pts[0]["pos"]), "b": vkey(pts[-1]["pos"])})
	refresh_posts()
	return made.size()

func _lay(kind: String, a: Vector3, b: Vector3, paid: int, built: bool, rebuild := false) -> int:
	return lay(kind, a, b, paid, built, rebuild).size()

func lay(kind: String, a: Vector3, b: Vector3, paid: int, built: bool, rebuild := false, ports := false) -> Array:
	var made := []
	var l := a.distance_to(b)
	if l < 0.05:
		return made
	var pieces := maxi(1, roundi(l / Defs.WALL_PIECE))
	var per_job := maxi(1, int(Defs.WALL_JOB_MAX / Defs.WALL_PIECE))
	var jobs := int(ceil(float(pieces) / per_job))
	var dirv := (b - a) / l
	var done := 0
	for j in jobs:
		var k := mini(per_job, pieces - done)
		var pa := a + dirv * (l * done / pieces)
		var pb := a + dirv * (l * (done + k) / pieces)
		done += k
		var s := _make(kind, pa, pb, built, ports)
		s.paid = int(round(paid * float(k) / pieces))
		if rebuild:
			s.rebuild_of = kind
			s.paid = 0
		made.append(s)
	return made

func _make(kind: String, a: Vector3, b: Vector3, built: bool, ports := false, heavy := false) -> LinearStructure:
	var s := LinearStructure.new()
	s.name = "%s_%d" % [kind, segments.size()]
	s.heavy = heavy
	add_child(s)
	s.setup_linear(kind, Defs.BUILD[kind], a, b, not built, ports)
	segments.append(s)
	G.buildings.register_linear(s, not built)
	return s

func build_ring(kind: String, pts: Array[Vector3]) -> void:
	for i in pts.size():
		lay(kind, pts[i], pts[(i + 1) % pts.size()], 0, true)
	refresh_posts()

func split_at(s: LinearStructure, p: Vector3) -> Array:
	var q := s.closest_point(p)
	var out := []
	var frac: float = s.hp / s.max_hp
	var built: bool = s.state == Building.BUILT
	var prog: float = s.progress
	var parts := [[s.a, q], [q, s.b]]
	var kind: String = s.kind
	var paid: int = s.paid
	var total_l: float = s.length
	var ported: bool = s.ported
	_retire(s)
	for pr in parts:
		var pa: Vector3 = pr[0]
		var pb: Vector3 = pr[1]
		if pa.distance_to(pb) < 0.4:
			continue
		var ns := _make(kind, pa, pb, built, ported and pa.distance_to(pb) >= 2.0)
		ns.hp = ns.max_hp * frac
		ns.progress = prog
		ns.paid = int(round(paid * pa.distance_to(pb) / total_l))
		out.append(ns)
	return out

func _retire(s: LinearStructure) -> void:
	segments.erase(s)
	s.release_soldiers()
	s.state = Building.DEAD
	G.grid.clear_nav(s.nav_cells, s)
	G.buildings.on_removed(s)
	G.grid.notify_paths_changed()
	s.queue_free()
	_queue_nest_check()

func demolish(p, refund: bool) -> void:
	if p == null or not is_instance_valid(p) or p.state == Building.DEAD:
		return
	var back := int(round(p.paid * Defs.REFUND_BUILT)) if refund else 0
	if G.fx:
		G.fx.dust(p.position + Vector3(0, 0.5, 0), 1.2)
	if p is LinearStructure:
		_retire(p)
		refresh_posts()
	else:
		p.destroy(false)
	if back > 0:
		G.main.add_supplies(back)

func collinear_run(s: LinearStructure) -> Array:
	var run := [s]
	var grew := true
	while grew:
		grew = false
		for o in live():
			if run.has(o) or o.kind != s.kind or o.state != s.state or o.replaced_by != null:
				continue
			if absf(o.dir.dot(s.dir)) < 0.999:
				continue
			for r in run:
				if o.a.distance_to(r.b) < 0.05 or o.b.distance_to(r.a) < 0.05 or o.a.distance_to(r.a) < 0.05 or o.b.distance_to(r.b) < 0.05:
					run.append(o)
					grew = true
					break
	run.sort_custom(func(x, y): return (x.position - s.a).dot(s.dir) < (y.position - s.a).dot(s.dir))
	return run

func cut_spot(p: Vector3, width: float, s: LinearStructure = null) -> Dictionary:
	if s == null:
		var bd := 3.0
		for o in live():
			if o.kind == "gate" or o.replaced_by != null:
				continue
			var d: float = o.seg_distance(p)
			if d < bd:
				bd = d
				s = o
	if s == null:
		return {"ok": false, "reason": "Tap on a wall"}
	var run := collinear_run(s)
	var dirv: Vector3 = s.dir
	var ra: Vector3 = s.a
	var rb: Vector3 = s.b
	var lo := 0.0
	var hi := s.length
	for r in run:
		for e in [r.a, r.b]:
			var t: float = (e - s.a).dot(dirv)
			if t < lo:
				lo = t
				ra = e
			if t > hi:
				hi = t
				rb = e
	var length := hi - lo
	if length < width + 0.3:
		return {"ok": false, "reason": "That wall is too short", "c": s.position, "d": dirv}
	var tc := clampf((Vector3(p.x, 0, p.z) - s.a).dot(dirv), lo + width * 0.5, hi - width * 0.5)
	return {"ok": true, "reason": "", "run": run, "a": ra, "b": rb, "c": s.a + dirv * tc, "d": dirv,
		"kind": s.kind, "built": s.state == Building.BUILT, "w": width}

func gate_spot(p: Vector3) -> Dictionary:
	return cut_spot(p, Defs.GATE_WIDTH)

func place_gate(p: Vector3, s: LinearStructure = null) -> String:
	var spot := cut_spot(p, Defs.GATE_WIDTH, s)
	if not spot["ok"]:
		return spot["reason"]
	var cost := int(Defs.BUILD["gate"]["cost"])
	if not G.main.spend(cost):
		return "Not enough supplies"
	var gate := _cut_gate(spot, false)
	gate.paid = cost
	G.buildings.last_placed = gate
	refresh_posts()
	return ""

func build_gate_now(p: Vector3) -> void:
	var spot := gate_spot(p)
	if spot["ok"]:
		_cut_gate(spot, true)
		refresh_posts()

func _cut(spot: Dictionary) -> Array:
	var paid := 0
	var total := 0.0
	for r in spot["run"]:
		paid += r.paid
		total += r.length
		_retire(r)
	var c: Vector3 = spot["c"]
	var d: Vector3 = spot["d"]
	var w: float = spot["w"]
	var ra: Vector3 = spot["a"]
	var rb: Vector3 = spot["b"]
	var g1 := c - d * w * 0.5
	var g2 := c + d * w * 0.5
	var kind: String = spot["kind"]
	var built: bool = spot["built"]
	var total_m := maxf(total, 0.1)
	if ra.distance_to(g1) >= 0.4:
		lay(kind, ra, g1, int(round(paid * ra.distance_to(g1) / total_m)), built)
	if g2.distance_to(rb) >= 0.4:
		lay(kind, g2, rb, int(round(paid * g2.distance_to(rb) / total_m)), built)
	var temp := []
	if built:
		temp = lay(kind, g1, g2, int(round(paid * w / total_m)), true)
	return [g1, g2, temp]

func _cut_gate(spot: Dictionary, built_gate: bool) -> LinearStructure:
	var res := _cut(spot)
	var gate := _make("gate", res[0], res[1], built_gate, false, spot.get("kind", "") == "fortified")
	if built_gate:
		for t in res[2]:
			_retire(t)
	elif not (res[2] as Array).is_empty():
		var e := WallEdit.new()
		e.refund = false
		e.add_new(gate)
		for t in res[2]:
			e.add_old(t)
	return gate

static func next_tier(kind: String) -> String:
	if softer(kind):
		return "concrete"
	if kind == "concrete":
		return "fortified"
	return ""

func upgrade_cost(s: LinearStructure) -> int:
	var nt := next_tier(s.kind)
	if nt == "":
		return 0
	return maxi(1, cost_of(nt, s.length) - int(cost_of(s.kind if s.kind != "gate" else "wall", s.length) * 0.5))

func upgrade_run_cost(s: LinearStructure) -> int:
	var c := 0
	var nt := next_tier(s.kind)
	for o in run_of(s):
		if nt != "" and next_tier(o.kind) == nt:
			c += upgrade_cost(o)
	return c

func run_of(s: LinearStructure) -> Array:
	var adj := _adjacency(true)
	var out := [s]
	var open := [s]
	while not open.is_empty():
		var cur: LinearStructure = open.pop_back()
		for e in [cur.a, cur.b]:
			for o in adj.get(vkey(e), []):
				if not out.has(o) and o.kind == s.kind and o.state == Building.BUILT and o.replaced_by == null:
					out.append(o)
					open.append(o)
	return out

func _replace(s: LinearStructure, kind: String, ports: bool, cost: int) -> String:
	if s.state != Building.BUILT or s.replaced_by != null:
		return "That wall is already changing"
	if not G.main.spend(cost):
		return "Not enough supplies"
	var e := WallEdit.new()
	e.refund = false
	var made := lay(kind, s.a, s.b, s.paid + cost, false, false, ports)
	for m in made:
		e.add_new(m)
	e.add_old(s)
	G.buildings.last_placed = null
	refresh_posts()
	return ""

func upgrade_segment(s: LinearStructure) -> String:
	var nt := next_tier(s.kind)
	if nt == "" or s.kind == "gate":
		return "Already the strongest wall"
	if G.buildings.unlock_why(nt) != "":
		return G.buildings.unlock_why(nt)
	return _replace(s, nt, s.ported, upgrade_cost(s))

static func softer(kind: String) -> bool:
	return kind == "wall" or kind == "fence" or kind == "picket" or kind == "hedge" or kind == "brickwall"

func upgrade_run(s: LinearStructure) -> String:
	var total := upgrade_run_cost(s)
	if total <= 0:
		return "Nothing to upgrade"
	if G.main.supplies < total:
		return "Needs %d supplies" % total
	var nt := next_tier(s.kind)
	if G.buildings.unlock_why(nt) != "":
		return G.buildings.unlock_why(nt)
	for o in run_of(s):
		if next_tier(o.kind) == nt:
			_replace(o, nt, o.ported, upgrade_cost(o))
	return ""

func ports_cost(s: LinearStructure) -> int:
	if not Defs.BUILD[s.kind].has("port_model"):
		return int(Defs.BUILD["wall"]["port_cost"]) + int(cost_of("wall", s.length) * 0.5)
	return int(Defs.BUILD[s.kind].get("port_cost", 30))

func add_ports(s: LinearStructure) -> String:
	if s.ported:
		return "Already has ports"
	if s.length < 1.8:
		return "Too short for ports"
	var k: String = s.kind if Defs.BUILD[s.kind].has("port_model") else "wall"
	return _replace(s, k, true, ports_cost(s))

func zone_walls(zone_id: int, kind: String = "") -> Array:
	var out := []
	for s in live():
		if (s.kind != kind and kind != "") or (kind == "" and not softer(s.kind)) or s.state != Building.BUILT or s.replaced_by != null:
			continue
		var n := Vector3(-s.dir.z, 0, s.dir.x)
		if G.zones.zone_at(s.position + n * 1.2) == zone_id or G.zones.zone_at(s.position - n * 1.2) == zone_id:
			out.append(s)
	return out

func upgrade_zone_cost(zone_id: int) -> int:
	var c := 0
	for s in zone_walls(zone_id):
		c += upgrade_cost(s)
	return c

func upgrade_zone(zone_id: int) -> String:
	var ws := zone_walls(zone_id)
	if ws.is_empty():
		return "No wooden walls here"
	var total := upgrade_zone_cost(zone_id)
	if G.main.supplies < total:
		return "Needs %d supplies" % total
	for s in ws:
		_replace(s, "concrete", s.ported, upgrade_cost(s))
	return ""

func add_bastion(s: LinearStructure, p: Vector3) -> String:
	var bk := String(Defs.BUILD[s.kind].get("bastion", "bastion"))
	var spot := cut_spot(p, BASTION_WIDTH, s)
	if not spot["ok"]:
		return spot["reason"]
	if not spot["built"]:
		return "Finish the wall first"
	var c: Vector3 = spot["c"]
	var d: Vector3 = spot["d"]
	var yaw := atan2(-d.z, d.x)
	var front := Vector3(-sin(yaw), 0, -cos(yaw))
	if front.dot(-s.inward()) < 0.0:
		yaw += PI
	var near0 := []
	for o in live():
		if o.seg_distance(c) < BASTION_WIDTH:
			near0.append(o)
	var why: String = G.buildings.check_rect(bk, c, yaw, null, near0)
	if why != "":
		return why
	var cost := int(Defs.BUILD[bk]["cost"])
	if G.main.supplies < cost:
		return "Needs %d supplies" % cost
	var res := _cut(spot)
	var near := []
	for o in live():
		if o.seg_distance(c) < BASTION_WIDTH:
			near.append(o)
	var bas: Building = G.buildings.place_rect(bk, c, yaw, false, near)
	if bas == null:
		for t in res[2]:
			t.replaced_by = null
		return "Something's in the way"
	var e := WallEdit.new()
	e.refund = false
	e.add_new(bas)
	for t in res[2]:
		e.add_old(t)
	refresh_posts()
	return ""

func add_nest(s: LinearStructure, p: Vector3, gun: String) -> String:
	if s.state != Building.BUILT or s.kind == "gate":
		return "Needs a finished wall"
	if G.buildings.unlock_why(gun) != "":
		return G.buildings.unlock_why(gun)
	var t := clampf((Vector3(p.x, 0, p.z) - s.a).dot(s.dir), minf(0.8, s.length * 0.5), maxf(s.length - 0.8, s.length * 0.5))
	var q: Vector3 = s.a + s.dir * t
	for b in G.buildings.list:
		if b is WallNest and is_instance_valid(b) and b.state != Building.DEAD:
			if Vector2(b.position.x - q.x, b.position.z - q.z).length() < 2.0:
				return "There's a nest here already"
	var cost: int = int(Defs.BUILD["nest"]["cost"]) + G.buildings.cost_of(gun)
	if not G.main.spend(cost):
		return "Needs %d supplies" % cost
	var n := WallNest.new()
	G.buildings.add_child(n)
	n.setup_nest(q, s.dir, s.kind, true)
	n.paid = int(Defs.BUILD["nest"]["cost"])
	G.buildings.list.append(n)
	G.workers.add_job(n)
	var g: Building = G.buildings.mount(n, 0, gun, false)
	if g:
		g.paid = G.buildings.cost_of(gun)
	G.buildings.last_placed = n
	return ""

func port_near(p: Vector3, r: float) -> bool:
	for s in segments:
		if is_instance_valid(s) and s.ported and s.state == Building.BUILT and s.seg_distance(p) < r + 1.0:
			if s.port_close(p, r):
				return true
	return false

func _queue_nest_check() -> void:
	if not _nest_check:
		_nest_check = true
		call_deferred("_check_nests")

func _check_nests() -> void:
	_nest_check = false
	if G.buildings == null:
		return
	for b in G.buildings.list.duplicate():
		if b is WallNest and is_instance_valid(b) and b.state != Building.DEAD and not b.supported():
			b.destroy(true)

func _adjacency(built_only: bool) -> Dictionary:
	var adj := {}
	for s in live():
		if built_only and s.state != Building.BUILT:
			continue
		for e in [s.a, s.b]:
			var k := vkey(e)
			if not adj.has(k):
				adj[k] = []
			adj[k].append(s)
	return adj

func chain_of(s: LinearStructure) -> Dictionary:
	var adj := _adjacency(true)
	var segs := [s]
	var fwd := _walk(s, s.b, adj, segs)
	var closed: bool = fwd["closed"]
	var back := {"pts": [], "pin": false, "closed": false}
	if not closed:
		back = _walk(s, s.a, adj, segs)
	var pts: Array = []
	var rb: Array = back["pts"]
	rb.reverse()
	pts.append_array(rb)
	pts.append(s.a)
	pts.append(s.b)
	pts.append_array(fwd["pts"])
	if closed and pts.size() > 1 and vkey(pts[-1]) == vkey(pts[0]):
		pts.pop_back()
	pts = simplify(pts, closed)
	return {"pts": pts, "segs": segs, "closed": closed, "pin_a": back["pin"], "pin_b": fwd["pin"], "kind": s.kind}

func _walk(from: LinearStructure, start: Vector3, adj: Dictionary, segs: Array) -> Dictionary:
	var pts := []
	var cur := from
	var v := start
	var guard := 0
	while guard < 500:
		guard += 1
		var at: Array = adj.get(vkey(v), [])
		var others := []
		for o in at:
			if o != cur:
				others.append(o)
		if others.is_empty():
			return {"pts": pts, "pin": _touches_building(v), "closed": false}
		if others.size() != 1:
			return {"pts": pts, "pin": true, "closed": false}
		var n: LinearStructure = others[0]
		if n == from:
			return {"pts": pts, "pin": false, "closed": true}
		if n.kind != from.kind or n.kind == "gate" or n.replaced_by != null:
			return {"pts": pts, "pin": true, "closed": false}
		if segs.has(n):
			return {"pts": pts, "pin": false, "closed": true}
		segs.append(n)
		var nv: Vector3 = n.b if vkey(n.a) == vkey(v) else n.a
		pts.append(nv)
		cur = n
		v = nv
	return {"pts": pts, "pin": true, "closed": false}

func _touches_building(v: Vector3) -> bool:
	var n := Defs.world_to_nav(v)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := n + Vector2i(dx, dy)
			if G.grid.ninb(c) and G.grid.nblk[G.grid.nidx(c)] == Grid.N_BUILD:
				return true
	return false

static func simplify(pts: Array, closed: bool) -> Array:
	var out := pts.duplicate()
	var changed := true
	while changed and out.size() > 2:
		changed = false
		var n := out.size()
		for i in n:
			if not closed and (i == 0 or i == n - 1):
				continue
			var p: Vector3 = out[(i - 1 + n) % n]
			var c: Vector3 = out[i]
			var q: Vector3 = out[(i + 1) % n]
			var d1 := (c - p)
			var d2 := (q - c)
			if d1.length() < 0.01 or d2.length() < 0.01 or d1.normalized().dot(d2.normalized()) > 0.9998:
				out.remove_at(i)
				changed = true
				break
	return out

static func edges_of(pts: Array, closed: bool) -> Array:
	var out := []
	for i in pts.size() - 1:
		out.append([pts[i], pts[i + 1]])
	if closed and pts.size() >= 3:
		out.append([pts[-1], pts[0]])
	return out

static func _same_edge(e1: Array, e2: Array) -> bool:
	var a1: Vector3 = e1[0]
	var b1: Vector3 = e1[1]
	var a2: Vector3 = e2[0]
	var b2: Vector3 = e2[1]
	return (a1.distance_to(a2) < 0.05 and b1.distance_to(b2) < 0.05) or (a1.distance_to(b2) < 0.05 and b1.distance_to(a2) < 0.05)

func reshape_plan(chain: Dictionary, new_pts: Array) -> Dictionary:
	var old_edges := edges_of(chain["pts"], chain["closed"])
	var new_edges := edges_of(new_pts, chain["closed"])
	var build := []
	var kept := []
	for ne in new_edges:
		var same := false
		for oe in old_edges:
			if _same_edge(ne, oe):
				same = true
				kept.append(oe)
				break
		if not same:
			build.append(ne)
	var remove := []
	for s in chain["segs"]:
		var keep := false
		for oe in kept:
			var a: Vector3 = oe[0]
			var b: Vector3 = oe[1]
			var l := a.distance_to(b)
			if l < 0.01:
				continue
			var d := (b - a) / l
			var sp: Vector3 = s.position
			var t := (sp - a).dot(d)
			var off := (sp - (a + d * t)).length()
			if off < 0.05 and t > -0.05 and t < l + 0.05:
				keep = true
				break
		if not keep:
			remove.append(s)
	var cost := 0
	var why := ""
	for e in build:
		cost += cost_of(chain["kind"], (e[0] as Vector3).distance_to(e[1]))
		var w := check_segment(e[0], e[1], chain["segs"])
		if w != "" and why == "":
			why = w
	return {"build": build, "remove": remove, "cost": cost, "why": why}

func reshape(chain: Dictionary, new_pts: Array) -> String:
	var plan := reshape_plan(chain, new_pts)
	if (plan["build"] as Array).is_empty() and (plan["remove"] as Array).is_empty():
		return "Nothing changed"
	if plan["why"] != "":
		return plan["why"]
	if not G.main.spend(plan["cost"]):
		return "Needs %d supplies" % plan["cost"]
	var e := WallEdit.new()
	e.refund = true
	for ed in plan["build"]:
		var a: Vector3 = ed[0]
		var b: Vector3 = ed[1]
		for m in lay(chain["kind"], a, b, cost_of(chain["kind"], a.distance_to(b)), false):
			e.add_new(m)
	for s in plan["remove"]:
		e.add_old(s)
	if e.new_parts.is_empty():
		for s in plan["remove"]:
			demolish(s, true)
	refresh_posts()
	return ""

func is_inner(s) -> bool:
	if G.zones == null:
		return false
	var n := Vector3(-s.dir.z, 0, s.dir.x)
	var off: float = s.thick * 0.5 + 0.8
	return G.zones.zone_at(s.position + n * off) > 0 and G.zones.zone_at(s.position - n * off) > 0

func inner_path(a: Vector2i, b: Vector2i, skip: Array) -> Array:
	var adj := {}
	for s in live():
		if s.state != Building.BUILT or skip.has(s) or not is_inner(s):
			continue
		for e in [s.a, s.b]:
			var k := vkey(e)
			if not adj.has(k):
				adj[k] = []
			adj[k].append(s)
	if not adj.has(a) or not adj.has(b):
		return []
	var prev := {a: null}
	var open := [a]
	while not open.is_empty():
		var k: Vector2i = open.pop_front()
		if k == b:
			break
		for s in adj.get(k, []):
			var other := vkey(s.b) if vkey(s.a) == k else vkey(s.a)
			if not prev.has(other):
				prev[other] = [k, s]
				open.append(other)
	if not prev.has(b):
		return []
	var path := []
	var cur := b
	while cur != a:
		var pr: Array = prev[cur]
		path.append(pr[1])
		cur = pr[0]
	return path

func ready_expansion() -> Array:
	for i in range(expansions.size() - 1, -1, -1):
		var ex: Dictionary = expansions[i]
		var all_built := true
		var any := false
		for s in ex["segs"]:
			if is_instance_valid(s) and s.state != Building.DEAD:
				any = true
				if s.state != Building.BUILT:
					all_built = false
		if not any:
			expansions.remove_at(i)
			continue
		if not all_built:
			continue
		expansions.remove_at(i)
		var path := inner_path(ex["a"], ex["b"], ex["segs"])
		if not path.is_empty():
			return path
	return []

func remove_inner(path: Array) -> void:
	for s in path:
		demolish(s, true)
	refresh_posts()

func on_removed(s: LinearStructure, broken: bool) -> void:
	segments.erase(s)
	if broken:
		broken_count += 1
	if broken and s.replaced_by == null and G.main and G.main.phase != "over":
		_make_rubble(s)
		if G.hud and not G.main.test_mode and broken_count == 1:
			G.hud.event("wall", "A wall broke! Tap the rubble to rebuild it", 6.0)
	refresh_posts()
	_queue_nest_check()

func _make_rubble(s: LinearStructure) -> Rubble:
	var r := Rubble.new()
	r.name = "Rubble%d" % rubble.size()
	add_child(r)
	r.setup(s.kind, s.a, s.b, s.ported)
	rubble.append(r)
	_auto_t = minf(_auto_t, 0.5)
	return r

func rubble_at(p: Vector3, rad: float = 1.4) -> Rubble:
	var best: Rubble = null
	var bd := rad
	for r in rubble:
		if not is_instance_valid(r):
			continue
		var d: float = r.seg_distance(p)
		if d < bd:
			bd = d
			best = r
	return best

func rebuild_rubble(r: Rubble) -> String:
	if r == null or not is_instance_valid(r):
		return "Nothing to rebuild"
	if r.is_rebuilding():
		return "Already being rebuilt"
	var pieces := clip_edge(r.a, r.b)
	if pieces.is_empty():
		clear_rubble(r)
		return ""
	var c: int = r.rebuild_cost()
	if c > 0 and not G.main.spend(c):
		return "Rebuilding costs %d" % c
	var segs: Array = []
	var total := maxf(0.1, r.length)
	for pc in pieces:
		var pa: Vector3 = pc[0]
		var pb: Vector3 = pc[1]
		var made := lay(r.kind, pa, pb, 0, false, true, r.ported and pa.distance_to(pb) >= 2.0)
		for x in made:
			x.paid = int(round(c * x.length / total))
		segs.append_array(made)
	r.rebuild_segs = segs
	refresh_posts()
	return ""

func clear_rubble(r: Rubble) -> void:
	rubble.erase(r)
	if is_instance_valid(r):
		if G.fx:
			G.fx.dust(r.position + Vector3(0, 0.3, 0), 1.0)
		r.queue_free()

func _cover_rubble(segs: Array) -> void:
	for x in segs:
		for r in rubble:
			if not is_instance_valid(r) or absf(r.dir.dot(x.dir)) < CLIP_ANGLE:
				continue
			if r.seg_distance(x.position) < CLIP_OFF and not r.rebuild_segs.has(x):
				r.rebuild_segs.append(x)

func step(dt: float) -> void:
	_auto_t -= dt
	if _auto_t > 0.0:
		return
	_auto_t = 0.5
	for r in rubble.duplicate():
		if not is_instance_valid(r):
			rubble.erase(r)
			continue
		if not r.rebuild_segs.is_empty():
			var done := true
			var alive := false
			for x in r.rebuild_segs:
				if is_instance_valid(x) and x.state != Building.DEAD:
					alive = true
					if x.state != Building.BUILT:
						done = false
			if alive and done:
				rubble.erase(r)
				r.queue_free()
				continue
			if not alive:
				r.rebuild_segs.clear()
		if not auto_rebuild or r.is_rebuilding() or G.main == null or G.main.phase == "over":
			continue
		if G.zombies and G.zombies.any_near_r(r.position, 10.0 + r.length * 0.5):
			continue
		if G.main.supplies >= r.rebuild_cost():
			rebuild_rubble(r)

func heal(cleared: PackedInt32Array) -> void:
	var cs := {}
	for i in cleared:
		cs[i] = true
	var g: Grid = G.grid
	for s in segments:
		if not is_instance_valid(s) or s.state != Building.BUILT:
			continue
		for i in s.nav_cells:
			if cs.has(i) and g.nblk[i] == Grid.N_OPEN:
				g.nblk[i] = Grid.N_GATE if s.kind == "gate" else Grid.N_WALL
				g.nown[i] = s
	if G.buildings:
		for b in G.buildings.list:
			if is_instance_valid(b) and b.rect and b.state == Building.BUILT:
				for i in b.nav_list:
					if cs.has(i) and g.nblk[i] == Grid.N_OPEN:
						g.nblk[i] = Grid.N_BUILD
						g.nown[i] = b
	if G.map:
		G.map.heal(cs)

func segment_at(p: Vector3, r: float = 1.2) -> LinearStructure:
	var best: LinearStructure = null
	var bd := r
	for s in live():
		var d: float = s.edge_distance(p)
		if d < bd:
			bd = d
			best = s
	return best

func refresh_posts() -> void:
	var info := {}
	for s in live():
		for e in [s.a, s.b]:
			var k := vkey(e)
			if not info.has(k):
				info[k] = {"pos": e, "built": false, "concrete": false, "segs": []}
			var d: Dictionary = info[k]
			d["segs"].append(s)
			if s.state == Building.BUILT:
				d["built"] = true
			if s.kind != "wall":
				d["concrete"] = true
			if s.kind == "fortified" or s.heavy:
				d["fort"] = true
	for k in _posts.keys():
		if not info.has(k):
			_posts[k].queue_free()
			_posts.erase(k)
			_post_kind.erase(k)
			_post_built.erase(k)
	for k in info.keys():
		var d: Dictionary = info[k]
		var segs: Array = d["segs"]
		var need := true
		var map_only := true
		for x in segs:
			if x.kind == "wall" or x.kind == "concrete" or x.kind == "gate" or x.kind == "fortified":
				map_only = false
		if map_only:
			need = false
		if segs.size() == 2 and segs[0].kind == segs[1].kind and segs[0].kind != "gate":
			if absf(segs[0].dir.dot(segs[1].dir)) > 0.999:
				need = false
		if segs.size() >= 2:
			var all_straight := true
			for x in segs:
				if absf(x.dir.dot(segs[0].dir)) < 0.999 or x.kind == "gate":
					all_straight = false
			if all_straight:
				need = false
		if not need:
			if _posts.has(k):
				_posts[k].queue_free()
				_posts.erase(k)
				_post_kind.erase(k)
				_post_built.erase(k)
			continue
		var pk := "wall_post_concrete" if d["concrete"] else "wall_post_wood"
		if d.get("fort", false):
			pk = "fortified_post"
		if _posts.has(k) and _post_kind[k] != pk:
			_posts[k].queue_free()
			_posts.erase(k)
		if not _posts.has(k):
			var m := Art.model(pk)
			m.position = d["pos"]
			add_child(m)
			_posts[k] = m
			_post_kind[k] = pk
			_post_built[k] = not d["built"]
		if _post_built[k] != d["built"]:
			_post_built[k] = d["built"]
			Art.set_override(_posts[k], null if d["built"] else Art.mat_blueprint)
			Art.set_shadows(_posts[k], d["built"])
