class_name CityBuilder
extends MapBuilder
# Builds the City from CityLayout data. MapBuilder does the shops, props, plaza
# trees and salvage wrecks; this adds the streets (several widths), the tall
# blocks and rubble. Towers are permanent rock on the nav grid: zombies and
# people go round them, nothing can be built on them, they can't be cleared,
# and (unlike houses) they close off a safe zone, so walling the street
# mouths round the plaza makes it safe.
const CHUNK := 120.0
var spots: Array[Vector3] = []
var sealed := 0
var _extra := {}

func build(d: Dictionary, seed_: int) -> void:
	layout = d
	rng.seed = seed_
	_city_surfaces()
	_towers()
	_rubble()
	_buildings()
	_props()
	_trees()
	_dead_cars()
	_wrecks()
	_seal_pockets()
	_entries()
	_flush_multimeshes()
	_flush_extra()
	_hide_outer_decor()
	spots.assign(layout["spots"])
	# A higher sun than the fields: long evening shadows would bury the
	# streets between the blocks.
	if G.main and G.main.get("sun") != null:
		G.main.sun.rotation_degrees.x = -50.0
	for m in Art.grid_materials():
		m.set_shader_parameter("zone_tex", G.zones.mask_tex)
	G.grid.notify_paths_changed()

# --- ground -----------------------------------------------------------------

func _city_surfaces() -> void:
	var by_w := {}
	var plain := SurfaceBuilder.new()
	var pave := SurfaceBuilder.new()
	var kerb := SurfaceBuilder.new()
	var grounds := {}
	var pw := CityLayout.PAVE_W
	var roads: Array = layout["roads"]
	for r in roads:
		var a: Vector3 = r["a"]
		var b: Vector3 = r["b"]
		var w := float(r["w"])
		var along := (b - a).normalized()
		var across := Vector3(-along.z, 0, along.x)
		var l := a.distance_to(b)
		var x_road := absf(along.x) > 0.5
		if not by_w.has(w):
			by_w[w] = SurfaceBuilder.new()
		(by_w[w] as SurfaceBuilder).strip(a, b, w, ROAD_Y, 0.0, l, w)
		_mark_paved(a, b, w + pw * 2.0)
		var cuts_k: Array = []
		var cuts_p: Array = []
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
			if minf(e0, e1) > w * 0.5 + 0.1 or maxf(e0, e1) < -w * 0.5 - 0.1:
				continue
			var t := (oa - a).dot(along)
			if t < -1.0 or t > l + 1.0:
				continue
			var ow := float(o["w"]) * 0.5
			cuts_k.append(Vector2(t - ow, t + ow))
			# x-roads keep their pavement through the corners; z-roads stop short.
			cuts_p.append(Vector2(t - ow, t + ow) if x_road else Vector2(t - ow - pw, t + ow + pw))
			if x_road:
				var c := a + along * t
				plain.strip(c - Vector3(ow, 0, 0), c + Vector3(ow, 0, 0), w, ROAD_Y + 0.004, 0.0, ow * 2.0, 8.0)
		for side in [-1.0, 1.0]:
			for sp in _spans(cuts_p, l):
				var off: Vector3 = across * side * (w * 0.5 + pw * 0.5)
				pave.strip(a + along * sp.x + off, a + along * sp.y + off, pw, PAVE_Y, sp.x, sp.y, 4.0)
			for sp in _spans(cuts_k, l):
				var ko: Vector3 = across * side * (w * 0.5)
				kerb.kerb(a + along * sp.x + ko, a + along * sp.y + ko, across * side, ROAD_Y, PAVE_Y, 0.25)
		# Streets that stop at the plaza get a kerb across the end.
		for end in [[a, -along], [b, along]]:
			var e: Vector3 = end[0]
			if absf(e.x) < CityLayout.EXT - 1.0 and absf(e.z) < CityLayout.EXT - 1.0:
				kerb.kerb(e - across * w * 0.5, e + across * w * 0.5, end[1], ROAD_Y, PAVE_Y, 0.25)
	for g in layout["grounds"]:
		var kind := String(g["kind"])
		if not grounds.has(kind):
			grounds[kind] = SurfaceBuilder.new()
		_rect(grounds[kind], g["r"], PAVE_Y - (0.002 if kind == "pavement" else 0.0))
		_pave_rect(g["r"])
	var lawn: Rect2 = layout["lawn"]
	var corners := [Vector3(lawn.position.x, 0, lawn.position.y), Vector3(lawn.end.x, 0, lawn.position.y),
		Vector3(lawn.end.x, 0, lawn.end.y), Vector3(lawn.position.x, 0, lawn.end.y)]
	var mid := Vector3(lawn.get_center().x, 0, lawn.get_center().y)
	for i in 4:
		var k0: Vector3 = corners[i]
		var k1: Vector3 = corners[(i + 1) % 4]
		var outward := (((k0 + k1) * 0.5) - mid)
		outward = Vector3(signf(outward.x) if absf(outward.x) > absf(outward.z) else 0.0, 0, signf(outward.z) if absf(outward.z) >= absf(outward.x) else 0.0)
		kerb.kerb(k0, k1, outward, 0.0, PAVE_Y, 0.2)
	for w in by_w:
		_add_mesh("Roads_%d" % int(w), (by_w[w] as SurfaceBuilder).commit(), Art.surface_mat("asphalt_road", float(w)))
	_add_mesh("Junctions", plain.commit(), Art.surface_mat("asphalt", 8.0))
	_add_mesh("Pavements", pave.commit(), Art.surface_mat("pavement", 4.0))
	_add_mesh("Kerbs", kerb.commit(), Art.surface_mat("kerb", 1.0))
	for kind in grounds:
		_add_mesh("Ground_" + kind, (grounds[kind] as SurfaceBuilder).commit(), Art.surface_mat(kind, 4.0 if kind != "asphalt" else 8.0))

func _spans(cuts: Array, l: float) -> Array:
	cuts.sort_custom(func(x, y): return x.x < y.x)
	var out: Array = []
	var from := 0.0
	for c in cuts:
		if c.x > from:
			out.append(Vector2(from, minf(c.x, l)))
		from = maxf(from, c.y)
	if from < l:
		out.append(Vector2(from, l))
	return out

func _rect(sb: SurfaceBuilder, r: Rect2, y: float) -> void:
	var A := Vector3(r.position.x, y, r.position.y)
	var B := Vector3(r.end.x, y, r.position.y)
	var C := Vector3(r.end.x, y, r.end.y)
	var D := Vector3(r.position.x, y, r.end.y)
	sb._quad(A, B, C, D, Vector2(A.x, A.z), Vector2(B.x, B.z), Vector2(C.x, C.z), Vector2(D.x, D.z), Vector3.UP)

func _pave_rect(r: Rect2) -> void:
	var c0 := Defs.world_to_cell(Vector3(r.position.x + 0.01, 0, r.position.y + 0.01))
	var c1 := Defs.world_to_cell(Vector3(r.end.x - 0.01, 0, r.end.y - 0.01))
	for y in range(maxi(0, c0.y), mini(Defs.H - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(Defs.W - 1, c1.x) + 1):
			paved[G.grid.idx(Vector2i(x, y))] = true

# --- towers -----------------------------------------------------------------

func _towers() -> void:
	var batches := {}
	for t in layout["towers"]:
		var r: Rect2 = t["r"]
		var c := r.get_center()
		var key := Vector2i(floori(c.x / CHUNK + 0.5), floori(c.y / CHUNK + 0.5))
		if not batches.has(key):
			batches[key] = CityArt.Batch.new()
		CityArt.add_tower(batches[key], t)
		if not bool(t["out"]):
			_rock_rect(r)
	for key in batches:
		var mi := MeshInstance3D.new()
		mi.name = "Towers_%d_%d" % [key.x, key.y]
		mi.mesh = (batches[key] as CityArt.Batch).commit()
		mi.material_override = CityArt.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)

# Permanent blocker: rock on the nav grid, "Blocked" for building.
func _rock_rect(r: Rect2) -> void:
	var g: Grid = G.grid
	var n0 := Defs.world_to_nav(Vector3(r.position.x + 0.05, 0, r.position.y + 0.05))
	var n1 := Defs.world_to_nav(Vector3(r.end.x - 0.05, 0, r.end.y - 0.05))
	for y in range(maxi(0, n0.y), mini(Defs.NH - 1, n1.y) + 1):
		for x in range(maxi(0, n0.x), mini(Defs.NW - 1, n1.x) + 1):
			var n := Vector2i(x, y)
			var i := g.nidx(n)
			g.nblk[i] = Grid.N_ROCK
			g.nown[i] = self
			g.terrain[g.idx(Defs.nav_to_build(n))] = Defs.T_ROCK

# Open cells that nothing can reach from the map edge (a yard shut in by
# towers) would read as a safe zone: fill them in.
func _seal_pockets() -> void:
	var g: Grid = G.grid
	var nw := Defs.NW
	var nh := Defs.NH
	var total := nw * nh
	var seen := PackedByteArray()
	seen.resize(total)
	var q := PackedInt32Array()
	q.resize(total)
	var qt := 0
	for x in nw:
		for y in [0, nh - 1]:
			var i: int = y * nw + x
			if seen[i] == 0 and g.nblk[i] != Grid.N_ROCK:
				seen[i] = 1
				q[qt] = i
				qt += 1
	for y in nh:
		for x in [0, nw - 1]:
			var i2: int = y * nw + x
			if seen[i2] == 0 and g.nblk[i2] != Grid.N_ROCK:
				seen[i2] = 1
				q[qt] = i2
				qt += 1
	var qh := 0
	while qh < qt:
		var u := q[qh]
		qh += 1
		var ux := u % nw
		var uy := u / nw
		for v in [u - 1 if ux > 0 else -1, u + 1 if ux < nw - 1 else -1, u - nw if uy > 0 else -1, u + nw if uy < nh - 1 else -1]:
			if v >= 0 and seen[v] == 0 and g.nblk[v] != Grid.N_ROCK:
				seen[v] = 1
				q[qt] = v
				qt += 1
	for i3 in total:
		if seen[i3] == 0 and g.nblk[i3] != Grid.N_ROCK:
			g.nblk[i3] = Grid.N_ROCK
			g.nown[i3] = self
			sealed += 1

# --- clutter ----------------------------------------------------------------

func _rubble() -> void:
	for ru in layout["ruins"]:
		var pos: Vector3 = ru["pos"]
		var yaw := float(ru["yaw"])
		var v := int(ru["v"])
		_extra_add("ruin%d" % v, Art.ruin_mesh(v), Transform3D(Basis(Vector3.UP, yaw), pos))
		var c := pos + Basis(Vector3.UP, yaw) * Vector3(1.3, 0, 0)
		_block(G.grid.rect_footprint(c, yaw, 4.2, 2.8)["nav"], Grid.N_STATIC, self)
	for hp in layout["heaps"]:
		var pos2: Vector3 = hp["pos"]
		var yaw2 := float(hp["yaw"])
		_extra_add("heap", CityArt.heap_mesh(), Transform3D(Basis(Vector3.UP, yaw2), pos2))
		_block(G.grid.rect_footprint(pos2, yaw2, 1.7, 1.3)["nav"], Grid.N_STATIC, self)
		var s := SalvageSpot.new()
		add_child(s)
		s.setup(pos2, "", int(hp["scrap"]))
		wrecks.append(s)

# Wrecks with nothing left in them: one MultiMesh per model.
func _dead_cars() -> void:
	for w in layout["dead_cars"]:
		var kind := SUBURB + String(w["model"])
		var pos: Vector3 = w["pos"]
		var yaw := float(w["yaw"])
		_mm_add(kind, Transform3D(Basis(Vector3.UP, yaw), pos))
		var fp: Dictionary = Art.footprint(kind)
		var h: Vector2 = fp["half"]
		var c: Vector3 = pos + Basis(Vector3.UP, yaw) * (fp["off"] as Vector3)
		_block(G.grid.rect_footprint(c, yaw, maxf(0.6, h.x), maxf(0.6, h.y))["nav"], Grid.N_STATIC, self)

func _extra_add(key: String, mesh: Mesh, xf: Transform3D) -> void:
	if not _extra.has(key):
		_extra[key] = {"mesh": mesh, "xforms": []}
	_extra[key]["xforms"].append(xf)

func _flush_extra() -> void:
	for key in _extra:
		var e: Dictionary = _extra[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e["mesh"]
		var xs: Array = e["xforms"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + key
		mmi.multimesh = mm
		mmi.material_override = Art.mat_vc
		add_child(mmi)

# The trees and rocks Decor scatters past the edge would stand inside the
# skyline here.
func _hide_outer_decor() -> void:
	var decor := get_parent().get_node_or_null("Decor") if get_parent() else null
	if decor == null:
		return
	for ch in decor.get_children():
		if ch is MultiMeshInstance3D:
			(ch as MultiMeshInstance3D).visible = false

# --- spawning and survivors --------------------------------------------------

# Spawn lanes are the street ends; keep the spread inside the street.
func _entries() -> void:
	var e: Dictionary = layout["entries"]
	for edge in e:
		var opts: Array = (e[edge] as Array).duplicate()
		opts.shuffle()
		var n := rng.randi_range(2, mini(3, opts.size()))
		entries[edge] = opts.slice(0, n)

func spawn_point(edge: int, r: RandomNumberGenerator) -> Vector3:
	var h := Defs.HALF
	var list: Array = entries.get(edge, [])
	var along := 0.0
	if not list.is_empty():
		var en: Array = list[r.randi() % list.size()]
		along = float(en[0]) + r.randf_range(-1.0, 1.0) * maxf(0.0, float(en[1]) - 3.5)
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

func survivor_points() -> Array[Vector3]:
	var out: Array[Vector3] = super()
	var g: Grid = G.grid
	for p in spots:
		var n := Defs.world_to_nav(p)
		if g.ninb(n) and g.nblk[g.nidx(n)] == Grid.N_OPEN:
			out.append(p)
	return out
