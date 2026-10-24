class_name MeshKit
extends RefCounted
var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var inds := PackedInt32Array()

func add_mesh(m: PrimitiveMesh, xf: Transform3D, col: Color, tag: float = 1.0) -> void:
	var arr := m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv = arr[Mesh.ARRAY_TEX_UV]
	var ind = arr[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	var c := Color(col.r, col.g, col.b, tag)
	var has_uv: bool = uv != null and uv is PackedVector2Array and (uv as PackedVector2Array).size() == v.size()
	for i in v.size():
		verts.append(xf * v[i])
		norms.append((nb * n[i]).normalized())
		cols.append(c)
		uvs.append(uv[i] if has_uv else Vector2.ZERO)
	if ind != null and ind is PackedInt32Array and (ind as PackedInt32Array).size() > 0:
		for i in (ind as PackedInt32Array).size():
			inds.append(base + ind[i])
	else:
		for i in v.size():
			inds.append(base + i)

static func xf_at(pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot) * Basis.from_scale(scl)
	return Transform3D(b, pos)

func box(size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, tag: float = 1.0) -> void:
	var m := BoxMesh.new()
	m.size = size
	add_mesh(m, xf_at(pos, rot), col, tag)

func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, segs: int = 10, tag: float = 1.0) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	add_mesh(m, xf_at(pos, rot), col, tag)

func sphere(r: float, pos: Vector3, col: Color, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, segs: int = 10, rings: int = 6, tag: float = 1.0, hemi: bool = false) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * (1.0 if hemi else 2.0)
	m.radial_segments = segs
	m.rings = rings
	m.is_hemisphere = hemi
	add_mesh(m, xf_at(pos, rot, scl), col, tag)

func capsule(r: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, tag: float = 1.0) -> void:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 2
	add_mesh(m, xf_at(pos, rot, scl), col, tag)

func prism(size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, left_to_right: float = 0.5, tag: float = 1.0) -> void:
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = left_to_right
	add_mesh(m, xf_at(pos, rot), col, tag)

func is_empty() -> bool:
	return verts.is_empty()

func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = inds
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am
