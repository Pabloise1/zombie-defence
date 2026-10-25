class_name Decor
extends Node3D
var grid: Grid
var ruins: Array[Vector3] = []
var wrecks: Array = []
var _bush_mm: MultiMesh
var _bush_cells := {}
# Build cell index -> [is_tree, variant, instance] for the scattered rocks and
# trees near the base, which are cleared when something is built on them.
var _clutter := {}
var _tree_mms: Array = []
var _rock_mms: Array = []

func setup(g: Grid, seed_: int, open_field: bool = true) -> void:
	grid = g
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var tree_xf := [[], [], []]
	var rock_xf := [[], [], []]
	var hq := Defs.HQ_ORIGIN + Vector2i(1, 1)
	if open_field:
		_place_ruins(r)
		_place_wrecks(r)
	var placed := 0
	var tries := 0
	while open_field and placed < 90 and tries < 3000:
		tries += 1
		var c := Vector2i(r.randi_range(3, Defs.W - 4), r.randi_range(3, Defs.H - 4))
		if maxi(absi(c.x - hq.x), absi(c.y - hq.y)) < 10:
			continue
		var i := grid.idx(c)
		if grid.terrain[i] != Defs.T_GROUND:
			continue
		var crowded := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := c + Vector2i(dx, dy)
				if grid.inb(n) and grid.terrain[grid.idx(n)] == Defs.T_ROCK:
					crowded = true
		if crowded:
			continue
		grid.set_rock(c)
		var p := Defs.cell_center(c)
		var jitter := Vector3(r.randf_range(-0.2, 0.2), 0, r.randf_range(-0.2, 0.2))
		if placed % 2 == 0:
			var v := r.randi_range(0, 2)
			var s := r.randf_range(0.75, 1.0)
			rock_xf[v].append(Transform3D(Basis.from_euler(Vector3(0, r.randf() * TAU, 0)).scaled(Vector3(s, s * r.randf_range(0.8, 1.2), s)), p + jitter))
			_clutter[i] = [false, v, rock_xf[v].size() - 1]
		else:
			var v := 2 if r.randf() < 0.3 else r.randi_range(0, 1)
			var s := r.randf_range(0.85, 1.25)
			tree_xf[v].append(Transform3D(Basis.from_euler(Vector3(0, r.randf() * TAU, 0)).scaled(Vector3(s, s, s)), p + jitter))
			_clutter[i] = [true, v, tree_xf[v].size() - 1]
		for n in grid.build_to_nav_cells(c):
			grid.clutter_nav[grid.nidx(n)] = self
		placed += 1
	var h := Defs.HALF
	for i in 900:
		var side := r.randi_range(0, 3)
		var along := r.randf_range(-h - 40.0, h + 40.0)
		var out := 3.0 + pow(r.randf(), 1.6) * 80.0
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(along, 0, -h - out)
			1: p = Vector3(along, 0, h + out)
			2: p = Vector3(-h - out, 0, along)
			_: p = Vector3(h + out, 0, along)
		if r.randf() < 0.12:
			var v := r.randi_range(0, 2)
			var s := r.randf_range(0.8, 2.2)
			rock_xf[v].append(Transform3D(Basis.from_euler(Vector3(0, r.randf() * TAU, 0)).scaled(Vector3(s, s * 0.8, s)), p))
		else:
			var v := 2 if r.randf() < 0.12 else r.randi_range(0, 1)
			var s := r.randf_range(0.9, 1.7)
			tree_xf[v].append(Transform3D(Basis.from_euler(Vector3(0, r.randf() * TAU, 0)).scaled(Vector3(s, s * r.randf_range(0.9, 1.25), s)), p))
	for v in 3:
		_tree_mms.append(_mm(Art.tree_mesh(v), tree_xf[v], true))
		_rock_mms.append(_mm(Art.rock_mesh(v), rock_xf[v], true))
	var bush_xf := []
	var bush_cell := []
	for i in 1400:
		var p := Vector3(r.randf_range(-h - 30, h + 30), 0, r.randf_range(-h - 30, h + 30))
		var c := Defs.world_to_cell(p)
		if grid.inb(c):
			if not open_field:
				continue
			if maxi(absi(c.x - hq.x), absi(c.y - hq.y)) < 6:
				continue
			if grid.terrain[grid.idx(c)] != Defs.T_GROUND:
				continue
		var s := r.randf_range(0.5, 1.1)
		bush_xf.append(Transform3D(Basis.from_euler(Vector3(0, r.randf() * TAU, 0)).scaled(Vector3(s, s * 0.8, s)), p))
		bush_cell.append(grid.idx(c) if grid.inb(c) else -1)
	_bush_mm = _mm(_bush_mesh(), bush_xf, false)
	for i in bush_cell.size():
		var ci: int = bush_cell[i]
		if ci >= 0:
			if not _bush_cells.has(ci):
				_bush_cells[ci] = []
			_bush_cells[ci].append(i)

func _place_wrecks(r: RandomNumberGenerator) -> void:
	var tries := 0
	while wrecks.size() < 8 and tries < 600:
		tries += 1
		var a := r.randf() * TAU
		var d := r.randf_range(24.0, 76.0)
		var p := Vector3(sin(a) * d, 0, -cos(a) * d)
		var c := Defs.world_to_cell(p)
		if not grid.inb(c) or grid.terrain[grid.idx(c)] != Defs.T_GROUND:
			continue
		var close := false
		for w in wrecks:
			if (w["pos"] as Vector3).distance_to(p) < 16.0:
				close = true
		for q in ruins:
			if q.distance_to(p) < 16.0:
				close = true
		if close:
			continue
		grid.set_rock(c)
		wrecks.append({"pos": Defs.cell_center(c), "model": "salvage_wreck_a" if wrecks.size() % 2 == 0 else "salvage_wreck_b"})

func salvage_spots() -> Array:
	var out := []
	for w in wrecks:
		out.append({"pos": w["pos"], "model": w["model"], "scrap": Defs.SALVAGE_SCRAP})
	for q in ruins:
		out.append({"pos": q, "model": "", "scrap": Defs.SALVAGE_SCRAP + 40})
	return out

func _place_ruins(r: RandomNumberGenerator) -> void:
	var start := r.randf() * TAU
	for i in 5:
		var a := start + i * TAU / 5.0 + r.randf_range(-0.3, 0.3)
		var dist := Defs.HALF * r.randf_range(0.72, 0.84)
		var p := Vector3(sin(a) * dist, 0, -cos(a) * dist)
		var c := Defs.world_to_cell(p)
		p = Defs.cell_center(c)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if grid.inb(n):
					grid.set_rock(n)
		var mi := MeshInstance3D.new()
		mi.mesh = Art.ruin_mesh(i % 3)
		mi.material_override = Art.mat_vc
		mi.position = p
		mi.rotation.y = r.randf() * TAU
		add_child(mi)
		ruins.append(p - p.normalized() * 6.0)

func clear_clutter(ni: int) -> void:
	var c := Defs.nav_to_build(grid.ncell_of(ni))
	var i := grid.idx(c)
	for n in grid.build_to_nav_cells(c):
		grid.clutter_nav.erase(grid.nidx(n))
	if not _clutter.has(i):
		return
	var e: Array = _clutter[i]
	_clutter.erase(i)
	var mm: MultiMesh = (_tree_mms if e[0] else _rock_mms)[e[1]]
	mm.set_instance_transform(e[2], Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0)))
	grid.terrain[i] = Defs.T_GROUND
	for n in grid.build_to_nav_cells(c):
		var k := grid.nidx(n)
		if grid.nblk[k] == Grid.N_ROCK:
			grid.nblk[k] = Grid.N_OPEN
	if G.fx:
		G.fx.dust(Defs.cell_center(c) + Vector3(0, 0.4, 0), 0.8)

func clear_cell(c: Vector2i) -> void:
	var ci := grid.idx(c)
	if not _bush_cells.has(ci):
		return
	for i in _bush_cells[ci]:
		_bush_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0)))
	_bush_cells.erase(ci)

func _mm(mesh: Mesh, xfs: Array, shadows: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Art.mat_vc
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm

func _bush_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var g := Color(0.24, 0.31, 0.15)
	k.sphere(0.45, Vector3(0, 0.2, 0), g, Vector3(1, 0.7, 1), Vector3.ZERO, 7, 4)
	k.sphere(0.32, Vector3(0.35, 0.15, 0.1), g.lightened(0.08), Vector3(1, 0.75, 1), Vector3.ZERO, 7, 4)
	k.sphere(0.3, Vector3(-0.3, 0.13, -0.15), g.darkened(0.1), Vector3(1, 0.75, 1), Vector3.ZERO, 7, 4)
	return k.build()
