class_name SurfaceBuilder
extends RefCounted
var st := SurfaceTool.new()
var _any := false

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func _tri(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, n: Vector3) -> void:
	var face := (b - a).cross(c - a)
	if face.dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	st.set_normal(n)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(uc)
	st.add_vertex(c)
	_any = true

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3) -> void:
	_tri(a, b, c, ua, ub, uc, n)
	_tri(a, c, d, ua, uc, ud, n)

func strip(a: Vector3, b: Vector3, w: float, y: float, u0: float, u1: float, _tile: float) -> void:
	var l := a.distance_to(b)
	if l < 0.01:
		return
	var d := (b - a) / l
	var s := Vector3(-d.z, 0, d.x) * (w * 0.5)
	var A := Vector3(a.x, y, a.z) - s
	var B := Vector3(b.x, y, b.z) - s
	var C := Vector3(b.x, y, b.z) + s
	var D := Vector3(a.x, y, a.z) + s
	_quad(A, B, C, D, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, w), Vector2(u0, w), Vector3.UP)

func square(c: Vector3, half: float, y: float, _tile: float) -> void:
	var A := Vector3(c.x - half, y, c.z - half)
	var B := Vector3(c.x + half, y, c.z - half)
	var C := Vector3(c.x + half, y, c.z + half)
	var D := Vector3(c.x - half, y, c.z + half)
	_quad(A, B, C, D, Vector2(A.x, A.z), Vector2(B.x, B.z), Vector2(C.x, C.z), Vector2(D.x, D.z), Vector3.UP)

func disk(c: Vector3, r: float, y: float, _tile: float, segs: int = 40) -> void:
	var cc := Vector3(c.x, y, c.z)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := cc + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := cc + Vector3(cos(a1), 0, sin(a1)) * r
		_tri(cc, p0, p1, Vector2(cc.x, cc.z), Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector3.UP)

func ring(c: Vector3, r0: float, r1: float, y: float, _tile: float, gap_at: float = 0.0, gap: float = 0.0, segs: int = 48) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var mid := (a0 + a1) * 0.5
		if gap > 0.0 and absf(wrapf(mid - gap_at, -PI, PI)) < gap:
			continue
		var i0 := Vector3(c.x + cos(a0) * r0, y, c.z + sin(a0) * r0)
		var o0 := Vector3(c.x + cos(a0) * r1, y, c.z + sin(a0) * r1)
		var i1 := Vector3(c.x + cos(a1) * r0, y, c.z + sin(a1) * r0)
		var o1 := Vector3(c.x + cos(a1) * r1, y, c.z + sin(a1) * r1)
		_quad(i0, o0, o1, i1, Vector2(i0.x, i0.z), Vector2(o0.x, o0.z), Vector2(o1.x, o1.z), Vector2(i1.x, i1.z), Vector3.UP)

func kerb(a: Vector3, b: Vector3, out: Vector3, y0: float, y1: float, top_w: float) -> void:
	var l := a.distance_to(b)
	if l < 0.01:
		return
	var A0 := Vector3(a.x, y0, a.z)
	var B0 := Vector3(b.x, y0, b.z)
	var A1 := Vector3(a.x, y1 + 0.004, a.z)
	var B1 := Vector3(b.x, y1 + 0.004, b.z)
	_quad(A0, B0, B1, A1, Vector2(0, 0), Vector2(l, 0), Vector2(l, 0.36), Vector2(0, 0.36), -out)
	var A2 := A1 + out * top_w
	var B2 := B1 + out * top_w
	_quad(A1, B1, B2, A2, Vector2(0, 0.36), Vector2(l, 0.36), Vector2(l, 1.0), Vector2(0, 1.0), Vector3.UP)

func ring_kerb(c: Vector3, r: float, y0: float, y1: float, top_w: float, gap_at: float = 0.0, gap: float = 0.0, segs: int = 48) -> void:
	var u := 0.0
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var mid := (a0 + a1) * 0.5
		if gap > 0.0 and absf(wrapf(mid - gap_at, -PI, PI)) < gap:
			continue
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := Vector3(c.x, 0, c.z) + d0 * r
		var p1 := Vector3(c.x, 0, c.z) + d1 * r
		var seg_l := p0.distance_to(p1)
		var A0 := Vector3(p0.x, y0, p0.z)
		var B0 := Vector3(p1.x, y0, p1.z)
		var A1 := Vector3(p0.x, y1 + 0.004, p0.z)
		var B1 := Vector3(p1.x, y1 + 0.004, p1.z)
		var n := -((d0 + d1) * 0.5).normalized()
		_quad(A0, B0, B1, A1, Vector2(u, 0), Vector2(u + seg_l, 0), Vector2(u + seg_l, 0.36), Vector2(u, 0.36), n)
		var A2 := A1 + d0 * top_w
		var B2 := B1 + d1 * top_w
		_quad(A1, B1, B2, A2, Vector2(u, 0.36), Vector2(u + seg_l, 0.36), Vector2(u + seg_l, 1.0), Vector2(u, 1.0), Vector3.UP)
		u += seg_l

func commit() -> Mesh:
	if not _any:
		return null
	st.generate_tangents()
	return st.commit()
