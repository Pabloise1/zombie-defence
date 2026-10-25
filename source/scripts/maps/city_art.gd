class_name CityArt
extends RefCounted
# Procedural city blocks. Every tower is a few boxes merged into a handful of
# chunk meshes (one draw call each); windows, shopfronts and grime come from
# one shader that reads metric UVs, so no textures and very few vertices.
# Facade vertices: COLOR.rgb = wall colour, COLOR.a = 1 (windowed),
# UV = (metres along the facade, height), UV2 = (facade length, code) where
# code = style + 4 * seed + 1024 * burnt. Roof bits have COLOR.a = 0.
const ROOFS := [Color(0.55, 0.55, 0.53), Color(0.47, 0.48, 0.49), Color(0.6, 0.57, 0.51), Color(0.42, 0.42, 0.43), Color(0.52, 0.47, 0.42)]
const CONCRETE := Color(0.62, 0.61, 0.58)
const METAL := Color(0.5, 0.52, 0.53)
const TANK := Color(0.56, 0.43, 0.3)
static var _mat: ShaderMaterial
static var _heap: ArrayMesh

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float ground_h = 4.2;
uniform float floor_h = 3.2;
uniform float fill = 0.22;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float band(float x, float a, float b, float w) {
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
void fragment() {
	vec3 col = COLOR.rgb;
	vec3 an = abs(wn);
	vec2 tuv = an.y > 0.5 ? wp.xz : (an.x > 0.5 ? wp.zy : wp.xy);
	float g = texture(grime_tex, tuv * 0.18).r;
	float rough = 0.9;
	float spec = 0.25;
	vec3 emit = vec3(0.0);
	vec3 sheen = vec3(0.0);
	if (COLOR.a > 0.5) {
		float code = UV2.y + 0.5;
		float burnt = floor(code / 1024.0);
		float rem = code - burnt * 1024.0;
		float sd = floor(rem / 4.0);
		float sty = floor(rem - sd * 4.0);
		float L = max(UV2.x, 1.0);
		float u = UV.x;
		float v = UV.y;
		float streak = texture(grime_tex, vec2(u * 0.3 + sd * 0.17, v * 0.035)).r;
		col *= (0.78 + 0.3 * streak) * (0.9 + 0.1 * g);
		col *= mix(0.7, 1.0, smoothstep(0.0, 3.0, v));
		float m = 0.0;
		float h = 0.5;
		if (v < ground_h) {
			float sc = max(1.0, floor(L / 4.6 + 0.5));
			float su = u / (L / sc);
			float sfu = fract(su);
			float sh = hash2(vec2(floor(su) + sd * 3.1, sd + 7.0));
			m = band(sfu, 0.08, 0.92, fwidth(su)) * band(v, 0.35, ground_h - 0.95, fwidth(v));
			if (sty > 0.5 && sh < 0.45) {
				vec3 shutter = vec3(0.46, 0.47, 0.46) * (0.82 + 0.18 * step(0.5, fract(v * 5.0)));
				col = mix(col, shutter, m);
				m = 0.0;
			}
			h = sh;
			col = mix(col, col * 0.55, band(v, ground_h - 0.85, ground_h - 0.3, fwidth(v)));
		} else {
			float pitch = sty < 0.5 ? 1.7 : (sty < 1.5 ? 3.0 : (sty < 2.5 ? 2.7 : 2.3));
			float nc = max(1.0, floor(L / pitch + 0.5));
			float cu = u / (L / nc);
			float ci = floor(cu);
			float fu = fract(cu);
			float fv = (v - ground_h) / floor_h;
			float fl = floor(fv);
			float ff = fract(fv);
			float wu = fwidth(cu);
			float wv = fwidth(fv);
			float avg = 0.3;
			if (sty < 0.5) {
				m = band(fu, 0.07, 0.93, wu) * band(ff, 0.24, 0.95, wv);
				avg = 0.62;
			} else if (sty < 1.5) {
				m = band(fu, 0.3, 0.7, wu) * band(ff, 0.28, 0.82, wv);
				col = mix(col, col * 0.82, band(ff, 0.0, 0.07, wv));
				avg = 0.22;
			} else if (sty < 2.5) {
				m = band(fu, 0.17, 0.83, wu) * band(ff, 0.32, 0.8, wv);
				col = mix(col, col * 0.84, band(ff, 0.0, 0.1, wv));
				avg = 0.32;
			} else {
				m = band(fu, 0.33, 0.67, wu) * band(ff, 0.2, 0.84, wv);
				col = mix(col, col * 1.1, band(ff, 0.0, 0.07, wv));
				avg = 0.22;
			}
			m = mix(m, avg, smoothstep(0.25, 0.6, max(wu, wv)));
			h = hash2(vec2(ci + sd * 13.0, fl + sd * 7.0));
		}
		vec3 sky = mix(vec3(0.26, 0.31, 0.37), vec3(0.5, 0.56, 0.62), fract(v * 0.06 + sd * 0.37));
		vec3 glass = mix(vec3(0.16, 0.18, 0.2), sky, sty < 0.5 ? 0.75 : 0.5);
		if (burnt > 0.5 || h < 0.07) {
			glass = vec3(0.025, 0.022, 0.02);
		} else if (h > 0.95) {
			glass = vec3(0.95, 0.66, 0.32);
			emit = vec3(0.5, 0.28, 0.08) * m;
		} else if (h > 0.87) {
			glass = vec3(0.36, 0.28, 0.19);
		}
		col = mix(col, glass, m);
		sheen = sky * m * (1.0 - burnt) * step(h, 0.87) * step(0.07, h);
		rough = mix(0.9, 0.3, m);
		spec = mix(0.25, 0.55, m);
		if (burnt > 0.5) {
			col *= mix(0.62, 0.85, smoothstep(0.0, 9.0, v) * streak);
		}
	} else if (wn.y > 0.5) {
		// weathered roofing felt / gravel
		float blot = texture(grime_tex, wp.xz * 0.045 + vec2(0.3, 0.7)).r;
		col *= (0.75 + 0.3 * blot) * (0.88 + 0.12 * g);
	} else {
		col *= g;
	}
	ALBEDO = to_linear(col);
	ROUGHNESS = rough;
	SPECULAR = spec;
	// Fill light so walls in the shade of other blocks stay readable, and a
	// fake sky reflection on the glass.
	EMISSION = to_linear(emit) + ALBEDO * fill + to_linear(sheen) * 0.22;
}
"""

static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("grime_tex", Art.grime_tex)
	_mat.set_shader_parameter("ground_h", CityLayout.GROUND_H)
	_mat.set_shader_parameter("floor_h", CityLayout.FLOOR_H)
	return _mat

# Rubble heap for the streets and the collapsed lot (Art.mat_vc).
static func heap_mesh() -> ArrayMesh:
	if _heap:
		return _heap
	var k := MeshKit.new()
	var r := RandomNumberGenerator.new()
	r.seed = 5150
	var conc := Color(0.6, 0.58, 0.54)
	k.sphere(1.9, Vector3(0, -0.2, 0), conc.darkened(0.25), Vector3(1.1, 0.55, 0.9), Vector3.ZERO, 8, 4)
	for i in 14:
		var a := r.randf() * TAU
		var d := r.randf_range(0.2, 1.8)
		var p := Vector3(cos(a) * d, r.randf_range(0.1, 0.8) * (1.6 - d * 0.6), sin(a) * d * 0.8)
		var c := conc.lerp(Color(0.55, 0.36, 0.28), r.randf() * 0.6).darkened(r.randf() * 0.2)
		k.box(Vector3(r.randf_range(0.5, 1.3), r.randf_range(0.2, 0.45), r.randf_range(0.4, 1.0)), p, c, Vector3(r.randf_range(-0.4, 0.4), r.randf() * TAU, r.randf_range(-0.4, 0.4)))
	for i in 4:
		var a2 := r.randf() * TAU
		k.cyl(0.03, 0.03, 1.6, Vector3(cos(a2) * 0.8, 0.9, sin(a2) * 0.6), Color(0.35, 0.22, 0.15), Vector3(r.randf_range(-0.9, 0.9), 0, r.randf_range(-0.9, 0.9)), 4)
	_heap = k.build()
	return _heap

# Collects towers into one mesh (a chunk of the city).
class Batch:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, nrm: Vector3, col: Color, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, u2: Vector2) -> void:
		var base := v.size()
		v.append_array([a, b, cc, d])
		uv.append_array([ua, ub, uc, ud])
		for i in 4:
			n.append(nrm)
			c.append(col)
			uv2.append(u2)
		if (b - a).cross(cc - a).dot(nrm) > 0.0:
			idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		else:
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	# Axis-aligned block with metric facade UVs. windows=false makes a plain
	# (roof-type) box. top=null leaves the lid off.
	func block(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, wall: Color, code: float, windows: bool, top = null) -> void:
		var a := 1.0 if windows else 0.0
		var col := Color(wall.r, wall.g, wall.b, a)
		var lx := x1 - x0
		var lz := z1 - z0
		quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(0, 0, 1), col,
			Vector2(0, y0), Vector2(lx, y0), Vector2(lx, y1), Vector2(0, y1), Vector2(lx, code))
		quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(0, 0, -1), col,
			Vector2(0, y0), Vector2(lx, y0), Vector2(lx, y1), Vector2(0, y1), Vector2(lx, code))
		quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(1, 0, 0), col,
			Vector2(0, y0), Vector2(lz, y0), Vector2(lz, y1), Vector2(0, y1), Vector2(lz, code))
		quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(-1, 0, 0), col,
			Vector2(0, y0), Vector2(lz, y0), Vector2(lz, y1), Vector2(0, y1), Vector2(lz, code))
		if top != null:
			var tc: Color = top
			quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, Color(tc.r, tc.g, tc.b, 0.0),
				Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1), Vector2.ZERO)

	# Low wall round a roof edge: outer, inner and top faces only.
	func parapet(x0: float, z0: float, x1: float, z1: float, y0: float, h: float, t: float, col: Color) -> void:
		var cc := Color(col.r, col.g, col.b, 0.0)
		var y1 := y0 + h
		block(x0, z0, x1, z1, y0, y1, col, 0.0, false)
		var ix0 := x0 + t
		var iz0 := z0 + t
		var ix1 := x1 - t
		var iz1 := z1 - t
		var z := Vector2.ZERO
		quad(Vector3(ix1, y0, iz1), Vector3(ix0, y0, iz1), Vector3(ix0, y1, iz1), Vector3(ix1, y1, iz1), Vector3(0, 0, -1), cc, z, z, z, z, z)
		quad(Vector3(ix0, y0, iz0), Vector3(ix1, y0, iz0), Vector3(ix1, y1, iz0), Vector3(ix0, y1, iz0), Vector3(0, 0, 1), cc, z, z, z, z, z)
		quad(Vector3(ix1, y0, iz0), Vector3(ix1, y0, iz1), Vector3(ix1, y1, iz1), Vector3(ix1, y1, iz0), Vector3(-1, 0, 0), cc, z, z, z, z, z)
		quad(Vector3(ix0, y0, iz1), Vector3(ix0, y0, iz0), Vector3(ix0, y1, iz0), Vector3(ix0, y1, iz1), Vector3(1, 0, 0), cc, z, z, z, z, z)
		var top := cc.lightened(0.08)
		quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, iz0), Vector3(x0, y1, iz0), Vector3.UP, top, z, z, z, z, z)
		quad(Vector3(x0, y1, iz1), Vector3(x1, y1, iz1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, top, z, z, z, z, z)
		quad(Vector3(x0, y1, iz0), Vector3(ix0, y1, iz0), Vector3(ix0, y1, iz1), Vector3(x0, y1, iz1), Vector3.UP, top, z, z, z, z, z)
		quad(Vector3(ix1, y1, iz0), Vector3(x1, y1, iz0), Vector3(x1, y1, iz1), Vector3(ix1, y1, iz1), Vector3.UP, top, z, z, z, z, z)

	func kit(k: MeshKit) -> void:
		var base := v.size()
		v.append_array(k.verts)
		n.append_array(k.norms)
		uv.append_array(k.uvs)
		for col in k.cols:
			c.append(Color(col.r, col.g, col.b, 0.0))
			uv2.append(Vector2.ZERO)
		for i in k.inds:
			idx.append(base + i)

	func is_empty() -> bool:
		return v.is_empty()

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return am

static func tower_height(floors: int) -> float:
	return CityLayout.GROUND_H + (floors - 1) * CityLayout.FLOOR_H

# One tower: body, maybe a set-back top, parapet and roof clutter.
static func add_tower(b: Batch, t: Dictionary) -> void:
	var r: Rect2 = t["r"]
	var floors := int(t["floors"])
	var style := int(t["style"])
	var sd := int(t["seed"])
	var burnt := bool(t["burnt"])
	var out := bool(t["out"])
	var wall: Color = t["col"]
	if burnt:
		wall = wall.darkened(0.15)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 7919 + floors * 31 + int(r.position.x * 13.0) + int(r.position.y * 7.0)
	var code := float(style + 4 * sd + (1024 if burnt else 0))
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var h := tower_height(floors)
	var roof: Color = ROOFS[(sd + style) % ROOFS.size()]
	if burnt:
		roof = roof.darkened(0.3)
	var trim := wall.darkened(0.28) if style != 3 else wall.lightened(0.12)
	var inset := 2.0
	var tier := floors >= 7 and minf(r.size.x, r.size.y) >= 12.0 and rng.randf() < 0.55
	if tier:
		var lower := floors - rng.randi_range(2, 3)
		var h1 := tower_height(lower)
		b.block(x0, z0, x1, z1, 0.0, h1, wall, code, true, roof)
		b.block(x0 - 0.25, z0 - 0.25, x1 + 0.25, z1 + 0.25, h1, h1 + 0.45, trim, 0.0, false, trim)
		x0 += inset
		z0 += inset
		x1 -= inset
		z1 -= inset
		b.block(x0, z0, x1, z1, h1 + 0.45, h, wall, code, true, roof)
	else:
		b.block(x0, z0, x1, z1, 0.0, h, wall, code, true, roof)
	var over := 0.35 if style == 3 else 0.15
	b.parapet(x0 - over, z0 - over, x1 + over, z1 + over, h, 0.75 if style != 0 else 0.5, 0.35, trim)
	if out and floors < 9:
		return
	# Roof clutter: lift housing, AC units, the odd water tank or mast.
	var k := MeshKit.new()
	var w := x1 - x0
	var dd := z1 - z0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var sx := rng.randf_range(-0.25, 0.25) * w
	var sz := rng.randf_range(-0.25, 0.25) * dd
	k.box(Vector3(minf(3.0, w * 0.3), 2.4, minf(2.6, dd * 0.3)), Vector3(cx + sx, h + 1.2, cz + sz), CONCRETE.darkened(rng.randf() * 0.2), Vector3.ZERO, 0.0)
	if not out:
		for i in rng.randi_range(1, 3):
			var p := Vector3(cx + rng.randf_range(-0.35, 0.35) * w, h + 0.5, cz + rng.randf_range(-0.35, 0.35) * dd)
			k.box(Vector3(1.5, 1.0, 1.1), p, METAL.lightened(rng.randf() * 0.2), Vector3(0, PI * 0.5 * rng.randi_range(0, 1), 0), 0.0)
		if w > 9.0 and dd > 9.0:
			var sp := Vector3(cx - sx * 0.6, h + 0.2, cz + sz * 0.3 - dd * 0.15)
			k.box(Vector3(2.6, 0.45, 1.6), sp, Color(0.3, 0.36, 0.42), Vector3.ZERO, 0.0)
	if style != 0 and floors >= 5 and rng.randf() < 0.45:
		var tp := Vector3(cx - sx * 0.8, h, cz - sz * 0.8)
		k.box(Vector3(2.4, 1.3, 2.4), tp + Vector3(0, 0.65, 0), Color(0.24, 0.23, 0.22), Vector3.ZERO, 0.0)
		k.cyl(1.15, 1.15, 2.3, tp + Vector3(0, 2.45, 0), TANK.darkened(rng.randf() * 0.15), Vector3.ZERO, 8, 0.0)
		k.cyl(0.0, 1.3, 0.8, tp + Vector3(0, 4.0, 0), TANK.darkened(0.3), Vector3.ZERO, 8, 0.0)
	elif style == 0 and floors >= 8:
		k.cyl(0.08, 0.14, 7.0, Vector3(cx + sx, h + 2.6 + 3.5, cz + sz), METAL, Vector3.ZERO, 4, 0.0)
	b.kit(k)
