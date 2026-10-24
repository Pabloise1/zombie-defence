class_name Terrain
extends Node3D
const CH := 16
const SKIRT := 420.0
var grid: Grid
var _chunks := {}
var _nx := 0
var _ny := 0

func setup(g: Grid) -> void:
	grid = g
	_nx = ceili(float(Defs.W) / CH)
	_ny = ceili(float(Defs.H) / CH)
	for cy in _ny:
		for cx in _nx:
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cy]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mi)
			_chunks[Vector2i(cx, cy)] = mi
			_rebuild(Vector2i(cx, cy))
	_build_skirt()

func set_grid_alpha(a: float) -> void:
	for m in Art.grid_materials():
		m.set_shader_parameter("grid_alpha", a)

func cell_changed(c: Vector2i) -> void:
	var done := {}
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if not grid.inb(n):
			continue
		var k := Vector2i(n.x / CH, n.y / CH)
		if not done.has(k):
			done[k] = true
			_rebuild(k)

func _rebuild(k: Vector2i) -> void:
	var mi: MeshInstance3D = _chunks[k]
	var x0 := k.x * CH
	var y0 := k.y * CH
	var x1 := mini(x0 + CH, Defs.W)
	var y1 := mini(y0 + CH, Defs.H)
	var cs := Defs.CELL
	var hs := Defs.HALF
	var dep := Defs.TRENCH_DEPTH
	var gv := PackedVector3Array()
	var gn := PackedVector3Array()
	var gi := PackedInt32Array()
	var dv := PackedVector3Array()
	var dn := PackedVector3Array()
	var di := PackedInt32Array()
	for y in range(y0, y1):
		var run_start := -1
		for x in range(x0, x1 + 1):
			var trench := x < x1 and grid.is_trench(Vector2i(x, y))
			var open := x < x1 and not trench
			if open and run_start < 0:
				run_start = x
			if (not open) and run_start >= 0:
				var ax := run_start * cs - hs
				var bx := x * cs - hs
				var az := y * cs - hs
				var bz := (y + 1) * cs - hs
				_quad(gv, gn, gi, Vector3(ax, 0, az), Vector3(bx, 0, az), Vector3(bx, 0, bz), Vector3(ax, 0, bz), Vector3.UP)
				run_start = -1
			if trench:
				var ax2 := x * cs - hs
				var bx2 := (x + 1) * cs - hs
				var az2 := y * cs - hs
				var bz2 := (y + 1) * cs - hs
				_quad(dv, dn, di, Vector3(ax2, -dep, az2), Vector3(bx2, -dep, az2), Vector3(bx2, -dep, bz2), Vector3(ax2, -dep, bz2), Vector3.UP)
				if not grid.is_trench(Vector2i(x, y - 1)):
					_quad(dv, dn, di, Vector3(bx2, 0, az2), Vector3(ax2, 0, az2), Vector3(ax2, -dep, az2), Vector3(bx2, -dep, az2), Vector3(0, 0, 1))
				if not grid.is_trench(Vector2i(x, y + 1)):
					_quad(dv, dn, di, Vector3(ax2, 0, bz2), Vector3(bx2, 0, bz2), Vector3(bx2, -dep, bz2), Vector3(ax2, -dep, bz2), Vector3(0, 0, -1))
				if not grid.is_trench(Vector2i(x - 1, y)):
					_quad(dv, dn, di, Vector3(ax2, 0, az2), Vector3(ax2, 0, bz2), Vector3(ax2, -dep, bz2), Vector3(ax2, -dep, az2), Vector3(1, 0, 0))
				if not grid.is_trench(Vector2i(x + 1, y)):
					_quad(dv, dn, di, Vector3(bx2, 0, bz2), Vector3(bx2, 0, az2), Vector3(bx2, -dep, az2), Vector3(bx2, -dep, bz2), Vector3(-1, 0, 0))
	var am := ArrayMesh.new()
	if gv.size() > 0:
		_add_surface(am, gv, gn, gi)
		am.surface_set_material(am.get_surface_count() - 1, Art.mat_ground)
	if dv.size() > 0:
		_add_surface(am, dv, dn, di)
		am.surface_set_material(am.get_surface_count() - 1, Art.mat_dirt)
	mi.mesh = am

func _quad(v: PackedVector3Array, nrm: PackedVector3Array, ind: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var base := v.size()
	v.append(a)
	v.append(b)
	v.append(c)
	v.append(d)
	for i in 4:
		nrm.append(n)
	var face := (b - a).cross(c - a)
	if face.dot(n) > 0.0:
		ind.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	else:
		ind.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

func _add_surface(am: ArrayMesh, v: PackedVector3Array, n: PackedVector3Array, i: PackedInt32Array) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_INDEX] = i
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _build_skirt() -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ind := PackedInt32Array()
	var h := Defs.HALF
	var s := SKIRT
	var y := -0.002
	_quad(v, n, ind, Vector3(-s, y, -s), Vector3(s, y, -s), Vector3(s, y, -h), Vector3(-s, y, -h), Vector3.UP)
	_quad(v, n, ind, Vector3(-s, y, h), Vector3(s, y, h), Vector3(s, y, s), Vector3(-s, y, s), Vector3.UP)
	_quad(v, n, ind, Vector3(-s, y, -h), Vector3(-h, y, -h), Vector3(-h, y, h), Vector3(-s, y, h), Vector3.UP)
	_quad(v, n, ind, Vector3(h, y, -h), Vector3(s, y, -h), Vector3(s, y, h), Vector3(h, y, h), Vector3.UP)
	var am := ArrayMesh.new()
	_add_surface(am, v, n, ind)
	am.surface_set_material(0, Art.mat_ground)
	var mi := MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
