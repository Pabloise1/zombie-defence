class_name MapBuilder
extends Node3D
const SUBURB := "suburb/"
const PAVE_Y := 0.08
const ROAD_Y := 0.02
var layout: Dictionary = {}
var rng := RandomNumberGenerator.new()
var buildings: Array = []
var fences: Array = []
var wrecks: Array = []
var entries := {}
var pumps: Array = []
var paved := {}
var _base := {}
var _mm := {}
var _fence_mm := {}
var _tree_refs := {}

func build(d: Dictionary, seed_: int) -> void:
	layout = d
	rng.seed = seed_
	_surfaces()
	_fences()
	_buildings()
	_props()
	_trees()
	_wrecks()
	_entries()
	_flush_multimeshes()
	for m in Art.grid_materials():
		m.set_shader_parameter("zone_tex", G.zones.mask_tex)
	G.grid.notify_paths_changed()

func _surfaces() -> void:
	var road := SurfaceBuilder.new()
	var plain := SurfaceBuilder.new()
	var pave := SurfaceBuilder.new()
	var kerb := SurfaceBuilder.new()
	var gravel := SurfaceBuilder.new()
	var rw := SuburbLayout.ROAD_W
	var pw := SuburbLayout.PAVE_W
	var roads: Array = layout["roads"]
	var junctions: Array = layout["junctions"]
	for r in roads:
		var a: Vector3 = r["a"]
		var b: Vector3 = r["b"]
		var along := (b - a).normalized()
		var across := Vector3(-along.z, 0, along.x)
		var l := a.distance_to(b)
		road.strip(a, b, rw, ROAD_Y, 0.0, l, 8.0)
		_mark_paved(a, b, rw + pw * 2.0)
		var l_pave := l
		var l_kerb := l
		for bl in layout["bulbs"]:
			var bc: Vector3 = bl["c"]
			var br: float = bl["r"]
			if bc.distance_to(b) < br:
				var tb := (bc - a).dot(along)
				l_pave = tb - sqrt(maxf(0.0, pow(br + pw, 2) - pow(rw * 0.5 + pw * 0.5, 2)))
				l_kerb = tb - sqrt(maxf(0.0, br * br - pow(rw * 0.5, 2)))
		for side in [-1.0, 1.0]:
			var edge_off: float = side * rw * 0.5
			var cuts := []
			for o in roads:
				if o == r:
					continue
				var oa: Vector3 = o["a"]
				var ob: Vector3 = o["b"]
				var od := (ob - oa).normalized()
				if absf(od.dot(along)) > 0.5:
					continue
				var e0 := (oa - a).dot(across)
				var e1 := (ob - a).dot(across)
				var lo := minf(e0, e1)
				var hi := maxf(e0, e1)
				if hi < -rw * 0.5 - 0.1 or lo > rw * 0.5 + 0.1:
					continue
				var reaches: bool = (side < 0.0 and lo <= edge_off + 0.1) or (side > 0.0 and hi >= edge_off - 0.1)
				if not reaches:
					continue
				var t := (oa - a).dot(along)
				cuts.append(Vector2(t - rw * 0.5, t + rw * 0.5))
			cuts.sort_custom(func(x, y): return x.x < y.x)
			var from := 0.0
			var spans := []
			for c in cuts:
				if c.x > from:
					spans.append(Vector2(from, c.x))
				from = maxf(from, c.y)
			if from < l:
				spans.append(Vector2(from, l))
			for sp in spans:
				var pe := minf(sp.y, l_pave)
				var ke := minf(sp.y, l_kerb)
				if pe > sp.x:
					var p0: Vector3 = a + along * sp.x + across * side * (rw * 0.5 + pw * 0.5)
					var p1: Vector3 = a + along * pe + across * side * (rw * 0.5 + pw * 0.5)
					pave.strip(p0, p1, pw, PAVE_Y, sp.x, pe, 4.0)
				if ke > sp.x:
					var k0: Vector3 = a + along * sp.x + across * side * (rw * 0.5)
					var k1: Vector3 = a + along * ke + across * side * (rw * 0.5)
					kerb.kerb(k0, k1, across * side, ROAD_Y, PAVE_Y, 0.25)
	for j in junctions:
		plain.square(j, rw * 0.5 + 0.02, ROAD_Y + 0.004, 8.0)
	for bl in layout["bulbs"]:
		var c: Vector3 = bl["c"]
		var rr: float = bl["r"]
		plain.disk(c, rr, ROAD_Y + 0.004, 8.0)
		var gap := asin(clampf(rw * 0.5 / rr, 0.0, 1.0)) + 0.04
		pave.ring(c, rr, rr + pw, PAVE_Y, 4.0, -PI * 0.5, gap)
		kerb.ring_kerb(c, rr, ROAD_Y, PAVE_Y, 0.25, -PI * 0.5, gap)
		_mark_paved(c - Vector3(rr + pw, 0, 0), c + Vector3(rr + pw, 0, 0), (rr + pw) * 2.0)
	for dr in layout["drives"]:
		gravel.strip(dr["a"], dr["b"], float(dr["w"]), ROAD_Y + 0.01, 0.0, (dr["a"] as Vector3).distance_to(dr["b"]), 4.0)
	_add_mesh("Roads", road.commit(), Art.surface_mat("asphalt_road", 8.0))
	_add_mesh("Junctions", plain.commit(), Art.surface_mat("asphalt", 8.0))
	_add_mesh("Pavements", pave.commit(), Art.surface_mat("pavement", 4.0))
	_add_mesh("Kerbs", kerb.commit(), Art.surface_mat("kerb", 1.0))
	_add_mesh("Drives", gravel.commit(), Art.surface_mat("gravel", 4.0))

func _add_mesh(n: String, mesh: Mesh, mat: Material) -> void:
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _mark_paved(a: Vector3, b: Vector3, w: float) -> void:
	var lo := Vector3(minf(a.x, b.x), 0, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), 0, maxf(a.z, b.z))
	var horiz := absf(b.x - a.x) > absf(b.z - a.z)
	if horiz:
		lo.z -= w * 0.5
		hi.z += w * 0.5
	else:
		lo.x -= w * 0.5
		hi.x += w * 0.5
	var c0 := Defs.world_to_cell(lo)
	var c1 := Defs.world_to_cell(hi)
	for y in range(maxi(0, c0.y), mini(Defs.H - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(Defs.W - 1, c1.x) + 1):
			paved[G.grid.idx(Vector2i(x, y))] = true

func is_paved(c: Vector2i) -> bool:
	return paved.has(G.grid.idx(c)) if G.grid.inb(c) else false

func _block(cells: PackedInt32Array, code: int, owner) -> void:
	var g: Grid = G.grid
	for i in cells:
		if g.nblk[i] == Grid.N_ROCK:
			continue
		if g.nblk[i] == Grid.N_STATIC and code == Grid.N_SLOW:
			continue
		g.nblk[i] = code
		g.nown[i] = owner
		_base[i] = [code, owner]

func unblock(cells: PackedInt32Array, owner) -> void:
	var g: Grid = G.grid
	for i in cells:
		if _base.has(i) and _base[i][1] == owner:
			_base.erase(i)
		if g.nown[i] == owner and (g.nblk[i] == Grid.N_SLOW or g.nblk[i] == Grid.N_STATIC):
			g.nblk[i] = Grid.N_OPEN
			g.nown[i] = null

func heal(cs: Dictionary) -> void:
	var g: Grid = G.grid
	for i in cs:
		if g.nblk[i] == Grid.N_OPEN and _base.has(i):
			g.nblk[i] = _base[i][0]
			g.nown[i] = _base[i][1]

func _fences() -> void:
	for f in layout["fences"]:
		var run := FenceRun.new()
		run.kind = String(f["kind"])
		run.pts = f["pts"]
		run.map = self
		fences.append(run)
		for i in run.pts.size() - 1:
			var a: Vector3 = run.pts[i]
			var b: Vector3 = run.pts[i + 1]
			var cells: PackedInt32Array = G.grid.supercover(a, b)
			run.cells.append_array(cells)
			_block(cells, Grid.N_SLOW, run)
			var l := a.distance_to(b)
			var n := maxi(1, roundi(l / 2.0))
			var pl := l / n
			var d := (b - a) / l
			var ang := atan2(-d.z, d.x)
			for k in n:
				var p := a + d * (pl * (k + 0.5))
				var xf := Transform3D(Basis(Vector3.UP, ang).scaled(Vector3(pl / 2.0, 1, 1)), p)
				run.pieces.append(_mm_add(FenceRun.model_of(run.kind), xf))

# A tree that something is being built on: hide it and free the cell.
func clear_clutter(ni: int) -> void:
	G.grid.clutter_nav.erase(ni)
	if not _tree_refs.has(ni):
		return
	var ref: Array = _tree_refs[ni]
	_tree_refs.erase(ni)
	_hide_ref(ref)
	unblock(PackedInt32Array([ni]), self)
	if G.fx:
		G.fx.dust(Defs.nav_center(G.grid.ncell_of(ni)) + Vector3(0, 0.5, 0), 0.9)

func _hide_ref(ref: Array) -> void:
	var mm: Dictionary = _mm[ref[0]]
	var xf: Transform3D = mm["xforms"][ref[1]]
	mm["xforms"][ref[1]] = Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), xf.origin - Vector3(0, 50, 0))
	if mm.has("mmi"):
		(mm["mmi"] as MultiMeshInstance3D).multimesh.set_instance_transform(ref[1], mm["xforms"][ref[1]] * mm["base"])

func hide_run(run) -> void:
	for ref in run.pieces:
		var mm: Dictionary = _mm[ref[0]]
		var xf: Transform3D = mm["xforms"][ref[1]]
		mm["xforms"][ref[1]] = Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), xf.origin - Vector3(0, 50, 0))
		if mm.has("mmi"):
			(mm["mmi"] as MultiMeshInstance3D).multimesh.set_instance_transform(ref[1], mm["xforms"][ref[1]] * mm["base"])

func fence_near(p: Vector3, r: float = 1.2):
	var best = null
	var bd := r
	for run in fences:
		if run.claimed:
			continue
		var d: float = run.distance(p)
		if d < bd:
			bd = d
			best = run
	return best

func _buildings() -> void:
	var list: Array = []
	for l in layout["lots"]:
		list.append(l)
	for b in layout["buildings"]:
		list.append(b)
	for p in layout["props"]:
		if String(p["model"]).begins_with("garage"):
			list.append(p)
	for e in list:
		var kind := String(e["model"])
		if not Defs.MAP_BUILDINGS.has(kind):
			continue
		var mb := MapBuilding.new()
		mb.name = "%s_%d" % [kind, buildings.size()]
		add_child(mb)
		mb.setup_map(kind, e["pos"], float(e["yaw"]), self)
		buildings.append(mb)
		_block(mb.nav_list, Grid.N_STATIC, mb)
		for c in mb.cell_list:
			var i: int = G.grid.idx(c)
			if G.grid.occ[i] == null:
				G.grid.occ[i] = mb
		var roll := rng.randf()
		if roll < 0.35:
			mb.contents = {"survivors": rng.randi_range(1, 3)}
		elif roll < 0.62:
			mb.contents = {"supplies": rng.randi_range(4, 12) * 10}
		elif roll < 0.78:
			mb.contents = {"crates": rng.randi_range(2, 4)}
		if kind == "petrol_station":
			for k in ["Pump1", "Pump2"]:
				var mp: Vector3 = mb.marker_world(k)
				if mp != Vector3.INF:
					pumps.append([mp, mb])

func blast_at(p: Vector3, r: float) -> void:
	for pu in pumps.duplicate():
		var mb = pu[1]
		if not is_instance_valid(mb) or mb.exploded or mb.cleared:
			continue
		if Vector2(p.x - pu[0].x, p.z - pu[0].z).length() <= r + 1.5:
			mb.explode()

func survivor_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for mb in buildings:
		if is_instance_valid(mb) and not mb.claimed and mb.state != Building.DEAD:
			out.append(mb.entry_point())
	return out

func _props() -> void:
	for p in layout["props"]:
		var kind := String(p["model"])
		if kind.begins_with("garage"):
			continue
		var pos: Vector3 = p["pos"]
		var yaw := float(p["yaw"])
		if kind == "trampoline" or kind == "bins" or kind.begins_with("bush"):
			if rng.randf() < 0.2:
				continue
			pos += Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			yaw += rng.randf_range(-0.4, 0.4)
		_mm_add(SUBURB + kind, Transform3D(Basis(Vector3.UP, yaw), pos))

func _trees() -> void:
	for t in layout["trees"]:
		var kind := String(t["model"])
		var s := float(t.get("s", 1.0))
		var pos: Vector3 = t["pos"]
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.1), s)), pos)
		var ref := _mm_add(SUBURB + kind, xf)
		var n := Defs.world_to_nav(pos)
		if G.grid.ninb(n):
			var ni: int = G.grid.nidx(n)
			_block(PackedInt32Array([ni]), Grid.N_STATIC, self)
			_tree_refs[ni] = ref
			G.grid.clutter_nav[ni] = self

func _mm_add(kind: String, xf: Transform3D) -> Array:
	if not _mm.has(kind):
		var info: Dictionary = Art.mesh_info(kind)
		_mm[kind] = {"xforms": [], "base": info["xf"], "mesh": info["mesh"]}
	var arr: Array = _mm[kind]["xforms"]
	arr.append(xf)
	return [kind, arr.size() - 1]

func _flush_multimeshes() -> void:
	for kind in _mm:
		var e: Dictionary = _mm[kind]
		if e["mesh"] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e["mesh"]
		var xs: Array = e["xforms"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, (xs[i] as Transform3D) * (e["base"] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + String(kind).replace("/", "_")
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var small: bool = kind.ends_with("mailbox") or kind.ends_with("bins") or kind.ends_with("bench") or kind.ends_with("bush_a") or kind.ends_with("bush_b") or kind.ends_with("trampoline")
		if small:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 110.0
		add_child(mmi)
		e["mmi"] = mmi

func _wrecks() -> void:
	var holding := 0
	for w in layout["wrecks"]:
		var kind := String(w["model"])
		var pos: Vector3 = w["pos"]
		var yaw := float(w["yaw"]) + rng.randf_range(-0.12, 0.12)
		var s := SalvageSpot.new()
		add_child(s)
		var scrap := 0
		if rng.randf() < 0.65 or kind == "school_bus_wreck":
			scrap = Defs.SALVAGE_SCRAP + (60 if kind == "school_bus_wreck" else 0)
			holding += 1
		s.setup(pos, SUBURB + kind, scrap, yaw)
		wrecks.append(s)
		var fp: Dictionary = Art.footprint(SUBURB + kind)
		var c: Vector3 = pos + Basis(Vector3.UP, yaw) * (fp["off"] as Vector3)
		var h: Vector2 = fp["half"]
		var fpr: Dictionary = G.grid.rect_footprint(c, yaw, maxf(0.6, h.x), maxf(0.6, h.y))
		_block(fpr["nav"], Grid.N_STATIC, s)
	G.logi.salvage.append_array(wrecks)

func salvage_spots() -> Array:
	return wrecks

func _entries() -> void:
	var e: Dictionary = layout["entries"]
	for edge in e:
		var opts: Array = (e[edge] as Array).duplicate()
		opts.shuffle()
		var n := rng.randi_range(2, mini(3, opts.size()))
		entries[edge] = []
		for i in n:
			entries[edge].append(float(opts[i]) + rng.randf_range(-6.0, 6.0))

func spawn_point(edge: int, r: RandomNumberGenerator) -> Vector3:
	var h := Defs.HALF
	var list: Array = entries.get(edge, [0.0])
	var along: float = float(list[r.randi() % list.size()]) + r.randf_range(-5.0, 5.0)
	var out := r.randf_range(2.0, 7.0)
	match edge:
		0:
			return Vector3(along, 0, -h - out)
		1:
			return Vector3(h + out, 0, along)
		2:
			return Vector3(along, 0, h + out)
		_:
			return Vector3(-h - out, 0, along)
