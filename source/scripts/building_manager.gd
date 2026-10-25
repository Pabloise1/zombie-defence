class_name BuildingManager
extends Node3D
signal changed
const HQ_DEF := {
	"name": "HQ", "long": "HQ", "hp": 2000.0, "blocks": true, "zcost": 1.0, "model": "hq", "size": 3, "time": 1.0,
}
var list: Array = []
var digs: Array = []
var hq: HQBuilding
var last_placed = null
var _order := 0

func spawn_hq() -> void:
	hq = HQBuilding.new()
	hq.name = "HQ"
	add_child(hq)
	hq.init_building("hq", Defs.HQ_ORIGIN, HQ_DEF, false)
	hq.rotation.y = PI
	for c in hq.cells():
		G.grid.occ[G.grid.idx(c)] = hq
	G.grid.mark_nav(G.grid.building_nav_cells(hq), Grid.N_BUILD, hq)
	list.append(hq)

func _make(kind: String) -> Building:
	match kind:
		"room_block":
			return RoomBlock.new()
		"stairs":
			return StairsTower.new()
		"helipad", "helipad_large":
			return Helipad.new()
		"fort_wood", "fort_concrete":
			return FortModule.new()
	if Defs.is_prefab(kind):
		return PrefabBuilding.new()
	match kind:
		"turret":
			return Turret.new()
		"cannon":
			return Cannon.new()
		"spikes":
			return SpikeTrap.new()
		"mine":
			return Mine.new()
		"mortar":
			return MortarPit.new()
		"sniper":
			return SniperTower.new()
		"garrison":
			return GarrisonBunker.new()
		"flame":
			return FlameBunker.new()
		"wire":
			return WireBarrier.new()
		"platform":
			return GunPlatform.new()
		"ammo_point", "radio", "fuel":
			return SupplyDevice.new()
		_:
			return Building.new()

static func size_of(kind: String) -> int:
	return int(Defs.BUILD.get(kind, {}).get("size", 1))

static func origin_for(kind: String, p: Vector3) -> Vector2i:
	var sz := size_of(kind)
	var off := (sz - 1) * Defs.CELL * 0.5
	return Defs.world_to_cell(p - Vector3(off, 0, off))

func check(kind: String, c: Vector2i, ignore = null) -> String:
	var sz := size_of(kind)
	var d: Dictionary = Defs.BUILD.get(kind, {})
	var why := unlock_why(kind)
	if why != "":
		return why
	for y in sz:
		for x in sz:
			why = _check_cell(kind, d, c + Vector2i(x, y), ignore)
			if why != "":
				return why
	return ""

func unlock_why(kind: String) -> String:
	var d: Dictionary = Defs.BUILD.get(kind, {})
	if kind != "dig" and G.main and int(d.get("unlock", 0)) > G.main.wave:
		return "Unlocks at wave %d" % int(d.get("unlock", 0))
	return ""

func _check_cell(kind: String, d: Dictionary, c: Vector2i, ignore = null) -> String:
	var g: Grid = G.grid
	if not g.inb(c):
		return "Outside the map"
	if c.x <= 1 or c.y <= 1 or c.x >= Defs.W - 2 or c.y >= Defs.H - 2:
		return "Too close to the edge"
	if g.is_hq(c):
		return "That's the HQ"
	var i := g.idx(c)
	var clutter := g.is_clutter_cell(c)
	if g.terrain[i] == Defs.T_ROCK and not clutter:
		return "Blocked"
	if (g.occ[i] != null and g.occ[i] != ignore) or g.digs[i] != null:
		return "Already used"
	for n in g.build_to_nav_cells(c):
		var ni := g.nidx(n)
		if g.clutter_nav.has(ni):
			continue
		if g.nblk[ni] != Grid.N_OPEN and not (ignore != null and g.nown[ni] == ignore):
			if g.nblk[ni] == Grid.N_SLOW:
				return "A fence is in the way"
			if g.nblk[ni] == Grid.N_STATIC:
				return "Something's in the way"
			return "A wall is in the way"
	if G.walls:
		var center := Defs.cell_center(c)
		for s in G.walls.live():
			if s.state == Building.BLUEPRINT and s.edge_distance(center) < 1.0:
				return "A wall is in the way"
	var trench := g.is_trench(c)
	if kind == "dig":
		if G.map and G.map.is_paved(c):
			return "Can't dig up the road"
		return "Already dug" if trench else ""
	if trench and not bool(d.get("trench", false)):
		return "Not in a trench"
	if not trench and not bool(d.get("ground", true)):
		return "Needs a trench"
	return ""

func cost_of(kind: String) -> int:
	return int(Defs.BUILD.get(kind, {}).get("cost", 0))

func place(kind: String, c: Vector2i, rest: float = 0.0) -> bool:
	if check(kind, c) != "":
		return false
	var cost := cost_of(kind)
	if not G.main.spend(cost):
		return false
	_order += 1
	var i: int = G.grid.idx(c)
	G.grid.clear_clutter_cells(_footprint(kind, c))
	if kind == "dig":
		var m := DigMark.new()
		add_child(m)
		m.init_mark(c)
		m.order = _order
		m.paid = cost
		G.grid.digs[i] = m
		digs.append(m)
		G.workers.add_job(m)
		last_placed = m
	else:
		var b := _make(kind)
		b.rest_yaw = rest
		add_child(b)
		for cc in _footprint(kind, c):
			G.grid.occ[G.grid.idx(cc)] = b
			if G.main.decor:
				G.main.decor.clear_cell(cc)
		b.init_building(kind, c, Defs.BUILD[kind], true)
		b.order = _order
		b.paid = cost
		list.append(b)
		G.workers.add_job(b)
		last_placed = b
	changed.emit()
	return true

func place_built(kind: String, c: Vector2i) -> Building:
	if check(kind, c) != "" or kind == "dig":
		return null
	G.grid.clear_clutter_cells(_footprint(kind, c))
	var b := _make(kind)
	add_child(b)
	for cc in _footprint(kind, c):
		G.grid.occ[G.grid.idx(cc)] = b
	b.init_building(kind, c, Defs.BUILD[kind], false)
	list.append(b)
	return b

func _footprint(kind: String, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sz := size_of(kind)
	for y in sz:
		for x in sz:
			out.append(c + Vector2i(x, y))
	return out

func rect_of(kind: String, p: Vector3, yaw: float) -> Dictionary:
	var h: Vector2 = Defs.BUILD[kind].get("half", Vector2.ONE)
	return G.grid.rect_footprint(p, yaw, h.x, h.y)

func check_rect(kind: String, p: Vector3, yaw: float, ignore = null, cut: Array = []) -> String:
	var why := unlock_why(kind)
	if why != "":
		return why
	var edge := Defs.HALF - 4.0
	if absf(p.x) > edge or absf(p.z) > edge:
		return "Too close to the edge"
	var fp := rect_of(kind, p, yaw)
	var g: Grid = G.grid
	for c in fp["cells"]:
		if not g.inb(c):
			return "Outside the map"
		var i := g.idx(c)
		if g.is_hq(c):
			return "That's the HQ"
		if g.terrain[i] == Defs.T_ROCK and not g.is_clutter_cell(c):
			return "Blocked"
		if g.is_trench(c) or g.digs[i] != null:
			return "Not on a trench"
		var o = g.occ[i]
		if o != null and o != ignore and not (o is LinearStructure and cut.has(o)):
			return "Something's in the way"
	for ni in fp["nav"]:
		var b := g.nblk[ni]
		if b == Grid.N_OPEN or g.clutter_nav.has(ni):
			continue
		var own = g.nown[ni]
		if own != null and (own == ignore or cut.has(own)):
			continue
		if b == Grid.N_ROCK or b == Grid.N_STATIC:
			return "Blocked"
		if b == Grid.N_SLOW:
			return "A fence is in the way"
		return "A wall is in the way" if (b == Grid.N_WALL or b == Grid.N_GATE) else "Something's in the way"
	if G.walls:
		for s in G.walls.live():
			if s.state == Building.BLUEPRINT and not cut.has(s):
				var l: Vector3 = (s.position - p).rotated(Vector3.UP, -yaw)
				var h: Vector2 = Defs.BUILD[kind].get("half", Vector2.ONE)
				if absf(l.x) < h.x + s.length * 0.5 and absf(l.z) < h.y + s.length * 0.5 and s.edge_distance(p) < h.length():
					return "A planned wall is in the way"
	return ""

func bridge_cost(pa: Vector3, pb: Vector3) -> int:
	return int(ceil(float(Defs.BUILD["bridge"]["per_m"]) * Vector2(pb.x - pa.x, pb.z - pa.z).length()))

func place_bridge(a: Dictionary, b: Dictionary, built: bool = false) -> Building:
	if a.is_empty() or b.is_empty():
		return null
	var cost := bridge_cost(a["pos"], b["pos"])
	if not built and not G.main.spend(cost):
		return null
	var br := RoofBridge.new()
	add_child(br)
	br.setup_bridge(a["pos"], b["pos"], a["ref"], b["ref"], not built)
	_order += 1
	br.order = _order
	br.paid = 0 if built else cost
	list.append(br)
	if not built:
		G.workers.add_job(br)
		last_placed = br
	changed.emit()
	return br

func place_rect(kind: String, p: Vector3, yaw: float, built: bool = false, cut: Array = []) -> Building:
	if check_rect(kind, p, yaw, null, cut) != "":
		return null
	var cost := cost_of(kind)
	if not built and not G.main.spend(cost):
		return null
	_order += 1
	var fp := rect_of(kind, p, yaw)
	G.grid.clear_clutter(fp["nav"])
	var b := _make(kind)
	add_child(b)
	for c in fp["cells"]:
		var i: int = G.grid.idx(c)
		if G.grid.occ[i] == null:
			G.grid.occ[i] = b
		if G.main.decor:
			G.main.decor.clear_cell(c)
	b.init_rect(kind, p, yaw, Defs.BUILD[kind], not built, fp)
	b.order = _order
	b.paid = 0 if built else cost
	list.append(b)
	if not built:
		G.workers.add_job(b)
		last_placed = b
	changed.emit()
	return b

func move_cost(b) -> int:
	return maxi(10, int(round(cost_of(b.kind) * Defs.MOVE_COST)))

func move_building(b, p: Vector3, yaw: float) -> String:
	if b == null or not is_instance_valid(b) or b.state != Building.BUILT:
		return "Can't move that"
	if b.moving_to != null:
		return "Already moving"
	var cost := move_cost(b)
	var nb: Building = null
	if b.rect:
		var why := check_rect(b.kind, p, yaw, b)
		if why != "":
			return why
		if not G.main.spend(cost):
			return "Moving costs %d" % cost
		var fp := rect_of(b.kind, p, yaw)
		nb = _make(b.kind)
		add_child(nb)
		for c in fp["cells"]:
			var i: int = G.grid.idx(c)
			if G.grid.occ[i] == null:
				G.grid.occ[i] = nb
		nb.move_from = b
		nb.init_rect(b.kind, p, yaw, b.def, true, fp)
	else:
		var c := origin_for(b.kind, p)
		var why2 := check(b.kind, c, b)
		if why2 != "":
			return why2
		if c == b.cell:
			b.set_rest(yaw)
			return ""
		if not G.main.spend(cost):
			return "Moving costs %d" % cost
		nb = _make(b.kind)
		nb.rest_yaw = yaw
		add_child(nb)
		for cc in _footprint(b.kind, c):
			G.grid.occ[G.grid.idx(cc)] = nb
		nb.move_from = b
		nb.init_building(b.kind, c, b.def, true)
	_order += 1
	nb.order = _order
	nb.paid = b.paid
	b.moving_to = nb
	list.append(nb)
	G.workers.add_job(nb)
	last_placed = nb
	changed.emit()
	return ""

func mount(host, i: int, kind: String, pay: bool = true, built: bool = false) -> Building:
	if host == null or not is_instance_valid(host) or i < 0 or i >= host.mounted.size():
		return null
	if host.mounted[i] != null and is_instance_valid(host.mounted[i]) and host.mounted[i].state != Building.DEAD:
		return null
	if unlock_why(kind) != "":
		return null
	var cost := cost_of(kind)
	if pay and not G.main.spend(cost):
		return null
	_order += 1
	var b := _make(kind)
	add_child(b)
	b.init_mounted(kind, host, i, Defs.BUILD[kind], not built)
	b.order = _order
	b.paid = cost if pay else 0
	list.append(b)
	if not built:
		G.workers.add_job(b)
		last_placed = b
	changed.emit()
	return b

func mounted_guns() -> Array:
	var out := []
	for b in list:
		if is_instance_valid(b) and b.host != null and b.state != Building.DEAD:
			out.append(b)
	return out

func register_linear(s: LinearStructure, as_job: bool) -> void:
	_order += 1
	s.order = _order
	list.append(s)
	if as_job and G.workers:
		G.workers.add_job(s)
	changed.emit()

func removable_at(c: Vector2i):
	if not G.grid.inb(c):
		return null
	var i: int = G.grid.idx(c)
	if G.grid.digs[i] != null:
		return G.grid.digs[i]
	var b = G.grid.occ[i]
	if b != null and b != hq and b.state != Building.DEAD:
		return b
	if G.walls:
		var s = G.walls.segment_at(Defs.cell_center(c), 1.0)
		if s != null:
			return s
	return null

func refund_of(thing) -> int:
	if thing is DigMark:
		return thing.paid
	if thing is Building:
		if thing.state == Building.BLUEPRINT:
			return thing.paid if thing.move_from == null else move_cost(thing.move_from)
		return int(round(thing.paid * Defs.REFUND_BUILT))
	return 0

func remove_at(c: Vector2i) -> bool:
	return remove_thing(removable_at(c))

func remove_thing(t) -> bool:
	if t == null or t == hq or not is_instance_valid(t):
		return false
	var refund := refund_of(t)
	if t is DigMark:
		G.workers.remove_job(t)
		digs.erase(t)
		t.cancel()
	else:
		G.workers.remove_job(t)
		var p: Vector3 = t.position
		if t.move_from != null and is_instance_valid(t.move_from):
			t.move_from.moving_to = null
			t.move_from = null
		t.destroy(false)
		if G.fx:
			G.fx.dust(p + Vector3(0, 0.3, 0), 0.7)
	G.main.add_supplies(refund)
	changed.emit()
	return true

func undo_thing(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var started := false
	if t is DigMark:
		started = t.progress > 0.0 or t.done
	elif t is Building:
		started = t.state != Building.BLUEPRINT or t.progress > 0.0
	if started:
		return false
	return remove_thing(t)

func on_removed(b: Building) -> void:
	list.erase(b)
	for c in b.cells():
		var i: int = G.grid.idx(c)
		if G.grid.occ[i] == b:
			G.grid.occ[i] = null
	if G.workers:
		G.workers.remove_job(b)
	if G.people:
		G.people.on_building_removed(b)
	changed.emit()

func on_dig_removed(m: DigMark) -> void:
	digs.erase(m)
	if G.workers:
		G.workers.remove_job(m)
	changed.emit()

func zone_for(b) -> int:
	if G.zones == null or b == null or not is_instance_valid(b):
		return 0
	if b.host != null and is_instance_valid(b.host):
		return zone_for(b.host)
	if b is LinearStructure:
		return G.zones.zone_of_cells(b.nav_cells)
	if b is WallNest:
		return b.inner_zone()
	return G.zones.zone_of_building(b)

func refresh_zones() -> void:
	if G.zones == null:
		return
	for b in list:
		if is_instance_valid(b) and b.state != Building.DEAD and not (b is LinearStructure):
			b.zone = zone_for(b)

func guns() -> Array:
	var out := []
	for b in list:
		if is_instance_valid(b) and b.state == Building.BUILT and b.mag_size > 0:
			out.append(b)
	return out

func damaged() -> Array:
	var out := []
	for b in list:
		if is_instance_valid(b) and b.needs_repair():
			out.append(b)
	return out

func step(dt: float) -> void:
	var i := 0
	while i < list.size():
		var b: Building = list[i]
		if is_instance_valid(b) and b.state != Building.DEAD:
			b.tick(dt)
		i += 1
	for j in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[j]) or list[j].state == Building.DEAD:
			if list[j] != hq:
				list.remove_at(j)

func count_built(kind: String) -> int:
	var n := 0
	for b in list:
		if is_instance_valid(b) and b.kind == kind and b.state == Building.BUILT:
			n += 1
	return n

func built_of(kind: String) -> Array:
	var out := []
	for b in list:
		if is_instance_valid(b) and b.kind == kind and b.state == Building.BUILT:
			out.append(b)
	return out
