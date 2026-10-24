class_name ElevatedNet
extends Node
const LINK := 2.8
const STEP_H := 1.3
var dirty := true
var nodes: Array = []
var adj: Array = []
var _of := {}

func _ensure() -> void:
	if dirty:
		dirty = false
		_rebuild()

func _add(pos: Vector3, ref, access: Vector3, kind: String) -> int:
	nodes.append({"pos": pos, "ref": ref, "access": access, "kind": kind})
	adj.append([])
	var id: int = ref.get_instance_id()
	if not _of.has(id):
		_of[id] = []
	_of[id].append(nodes.size() - 1)
	return nodes.size() - 1

func _link(i: int, j: int, pts: Array, seen: bool = true) -> void:
	adj[i].append([j, pts, seen])
	var back := pts.duplicate()
	back.reverse()
	adj[j].append([i, back, seen])

func _rebuild() -> void:
	nodes.clear()
	adj.clear()
	_of.clear()
	if G.buildings == null or G.walls == null:
		return
	var blocks := []
	var stairs := []
	var walks := []
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state != Building.BUILT:
			continue
		if b is RoomBlock:
			blocks.append(b)
			_add(b.position + Vector3(0, b.roof_height(), 0), b, b.entry_point(), "roof")
		elif b is StairsTower:
			stairs.append(b)
			var lv: Array = b.level_points()
			var lo := _add(lv[0], b, b.bottom_point(), "stairs")
			var hi := _add(lv[1], b, Vector3.INF, "stairs")
			_link(lo, hi, [lv[0], lv[1]])
	for s in G.walls.live():
		if s.state != Building.BUILT:
			continue
		if s.kind == "fortified" or (s.kind == "gate" and s.heavy):
			walks.append(s)
			var wp: Vector3 = s.position + Vector3(0, 3.7, 0) + s.inward() * 0.5
			var acc := Vector3.INF
			if s.kind == "gate":
				acc = s.position + s.inward() * 2.2
			_add(wp, s, acc, "walk")
	for i in walks.size():
		for j in range(i + 1, walks.size()):
			var a = walks[i]
			var b2 = walks[j]
			var shared := Vector3.INF
			for ea in [a.a, a.b]:
				for eb in [b2.a, b2.b]:
					if ea.distance_to(eb) < 0.3:
						shared = ea
			if shared == Vector3.INF:
				continue
			var na: int = _of[a.get_instance_id()][0]
			var nb: int = _of[b2.get_instance_id()][0]
			var corner: Vector3 = shared + Vector3(0, 3.7, 0) + (a.inward() + b2.inward()).normalized() * 0.5
			_link(na, nb, [nodes[na]["pos"], corner, nodes[nb]["pos"]])
	for st in stairs:
		var ids: Array = _of[st.get_instance_id()]
		for b in blocks:
			if b.edge_distance(st.position) > LINK:
				continue
			var nb2: int = _of[b.get_instance_id()][0]
			for k in ids:
				if absf(nodes[k]["pos"].y - nodes[nb2]["pos"].y) < STEP_H:
					_link(k, nb2, [nodes[k]["pos"], nodes[nb2]["pos"]])
		for w in walks:
			if w.seg_distance(st.position) > LINK + 0.6:
				continue
			var nw: int = _of[w.get_instance_id()][0]
			var foot: Vector3 = w.closest_point(st.position) + Vector3(0, 3.7, 0) + w.inward() * 0.5
			for k in ids:
				if absf(nodes[k]["pos"].y - 3.7) < STEP_H:
					_link(k, nw, [nodes[k]["pos"], foot, nodes[nw]["pos"]])
	for b in blocks:
		if b.storeys != 1:
			continue
		for w in walks:
			if w.edge_distance(b.position) > b.half.x + 1.2:
				continue
			var nb3: int = _of[b.get_instance_id()][0]
			var nw2: int = _of[w.get_instance_id()][0]
			_link(nb3, nw2, [nodes[nb3]["pos"], w.closest_point(b.position) + Vector3(0, 3.7, 0) + w.inward() * 0.5, nodes[nw2]["pos"]])
	for b in G.buildings.list:
		if not is_instance_valid(b) or not (b is RoofBridge) or b.state != Building.BUILT:
			continue
		var ia := _node_of(b.end_a, b.pa)
		var ib := _node_of(b.end_b, b.pb)
		if ia >= 0 and ib >= 0:
			_link(ia, ib, [nodes[ia]["pos"], b.pa, b.pb, nodes[ib]["pos"]])

func _node_of(ref, p: Vector3) -> int:
	if ref == null or not is_instance_valid(ref) or not _of.has(ref.get_instance_id()):
		return -1
	var best := -1
	var bd := INF
	for k in _of[ref.get_instance_id()]:
		var d: float = nodes[k]["pos"].distance_to(p)
		if d < bd:
			bd = d
			best = k
	return best

static func needs_climb(b) -> bool:
	if b == null or not is_instance_valid(b):
		return false
	if b is LinearStructure:
		return b.kind == "fortified"
	if b is WallNest:
		return b.wall_kind == "fortified"
	if b is Building and b.host != null:
		return needs_climb(b.host)
	return false

func route_for(b, from: Vector3) -> Dictionary:
	if not needs_climb(b):
		return {}
	_ensure()
	var host = b.host if b is Building and b.host != null else b
	var target_ref = host
	var tp: Vector3 = host.position
	if host is WallNest:
		target_ref = _wall_under(host)
		tp = host.position
	var goal := _node_of(target_ref, tp + Vector3(0, 3.7, 0))
	if goal < 0:
		return {"ok": false}
	var dist := {}
	var prev := {}
	var open := [goal]
	dist[goal] = 0.0
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if dist[open[k]] < dist[open[bi]]:
				bi = k
		var u: int = open[bi]
		open.remove_at(bi)
		for e in adj[u]:
			var v: int = e[0]
			var nd: float = dist[u] + _len(e[1])
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				prev[v] = [u, e]
				open.append(v)
	var best := -1
	var bs := INF
	for v in dist:
		var acc: Vector3 = nodes[v]["access"]
		if acc == Vector3.INF:
			continue
		var score: float = dist[v] + acc.distance_to(from)
		if G.zones and G.zones.zone_at(acc) == 0:
			score += 200.0
		if score < bs:
			bs = score
			best = v
	if best < 0:
		return {"ok": false}
	var pts: Array = []
	var seen: Array = []
	var cur := best
	var acc_pt: Vector3 = nodes[best]["access"]
	pts.append(acc_pt)
	seen.append(nodes[best]["kind"] != "roof")
	pts.append(nodes[best]["pos"])
	seen.append(nodes[best]["kind"] != "roof")
	while cur != goal:
		var pr = prev.get(cur)
		if pr == null:
			break
		var e: Array = pr[1]
		var wps: Array = e[1].duplicate()
		wps.reverse()
		for w in wps:
			pts.append(w)
			seen.append(true)
		cur = pr[0]
	return {"ok": true, "access": acc_pt, "points": pts, "seen": seen}

func _wall_under(nest):
	var best = null
	var bd := 2.0
	for s in G.walls.live():
		if s.kind != "fortified":
			continue
		var d: float = s.seg_distance(nest.position)
		if d < bd:
			bd = d
			best = s
	return best

static func _len(pts: Array) -> float:
	var l := 0.0
	for i in pts.size() - 1:
		l += Vector3(pts[i]).distance_to(pts[i + 1])
	return l

func links_of(ref) -> int:
	_ensure()
	if ref == null or not _of.has(ref.get_instance_id()):
		return 0
	var n := 0
	for k in _of[ref.get_instance_id()]:
		for e in adj[k]:
			if nodes[e[0]]["ref"] != ref:
				n += 1
	return n

func anchor_near(p: Vector3, toward: Vector3 = Vector3.INF) -> Dictionary:
	var best := {}
	var bd := 4.5
	if G.buildings:
		for b in G.buildings.list:
			if not is_instance_valid(b) or b.state != Building.BUILT:
				continue
			if b is RoomBlock:
				var d: float = b.edge_distance(p)
				if d < bd:
					bd = d
					var dirv: Vector3 = (toward - b.position) if toward != Vector3.INF else (p - b.position)
					dirv.y = 0.0
					var edge := _rect_edge(b, dirv)
					best = {"pos": Vector3(edge.x, b.deck_height(), edge.z), "ref": b}
			elif b is StairsTower:
				var d2: float = Vector2(p.x - b.position.x, p.z - b.position.z).length() - 1.2
				if d2 < bd:
					bd = d2
					var top: Vector3 = b.level_points()[1]
					best = {"pos": top, "ref": b}
	if G.walls:
		for s in G.walls.live():
			if s.state != Building.BUILT or s.kind != "fortified":
				continue
			var d3: float = s.seg_distance(p)
			if d3 < bd:
				bd = d3
				var q: Vector3 = s.closest_point(p)
				best = {"pos": q + Vector3(0, 3.7, 0) + s.inward() * 0.6, "ref": s}
	return best

static func _rect_edge(b, d: Vector3) -> Vector3:
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	var l: Vector3 = d.normalized().rotated(Vector3.UP, -b.yaw)
	var tx: float = (b.half.x + 0.1) / maxf(absf(l.x), 0.0001)
	var tz: float = (b.half.y + 0.1) / maxf(absf(l.z), 0.0001)
	var t := minf(tx, tz)
	return b.position + (l * t).rotated(Vector3.UP, b.yaw)
