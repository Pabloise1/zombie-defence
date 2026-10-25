class_name CityLayout
extends RefCounted
# Downtown: a plaza in the middle walled in by low blocks, a ring avenue round
# that, and cross streets running out to every edge. The horde comes in at the
# street ends, so the streets and the plaza mouths are the chokepoints.
# Block edges sit on odd metres so they line up with the 2 m build grid.
const AVE_W := 12.0
const ST_W := 8.0
const PAVE_W := 3.0
const EXT := 150.0
const RING := 46.0
const OUTER := 76.0
const PLAZA := Rect2(-26.0, -23.0, 52.0, 46.0)
const PROM := 3.0
const GROUND_H := 4.2
const FLOOR_H := 3.2
const FACE_S := PI
const FACE_N := 0.0
const FACE_E := -PI * 0.5
const FACE_W := PI * 0.5
const LINES := [-EXT, -OUTER, -RING, 0.0, RING, OUTER, EXT]
const PALETTES := [
	[Color(0.56, 0.58, 0.6), Color(0.44, 0.47, 0.52), Color(0.62, 0.6, 0.55), Color(0.36, 0.4, 0.42)],
	[Color(0.55, 0.3, 0.22), Color(0.62, 0.38, 0.27), Color(0.47, 0.31, 0.25), Color(0.6, 0.46, 0.36)],
	[Color(0.7, 0.68, 0.62), Color(0.62, 0.62, 0.6), Color(0.72, 0.63, 0.5), Color(0.58, 0.6, 0.56)],
	[Color(0.8, 0.74, 0.62), Color(0.74, 0.68, 0.56), Color(0.66, 0.62, 0.58), Color(0.77, 0.66, 0.52)],
]

static func data() -> Dictionary:
	var d := {
		"id": "city",
		"hq": Vector3.ZERO,
		"wave_mult": 1.2,
		"roads": [],
		"junctions": [],
		"bulbs": [],
		"lots": [],
		"buildings": [],
		"trees": [],
		"props": [],
		"wrecks": [],
		"dead_cars": [],
		"fences": [],
		"drives": [],
		"towers": [],
		"grounds": [],
		"ruins": [],
		"heaps": [],
		"spots": [],
		"park": PLAZA,
		"lawn": PLAZA.grow(-PROM),
		"entries": {},
	}
	var r := RandomNumberGenerator.new()
	r.seed = 7781
	_roads(d)
	_blocks(d, r)
	_plaza(d)
	_lots(d)
	_street_furniture(d, r)
	_wrecks(d)
	_spots(d)
	return d

static func road_w(c: float) -> float:
	return AVE_W if absf(absf(c) - RING) < 0.1 else ST_W

static func _roads(d: Dictionary) -> void:
	var R: Array = d["roads"]
	for c in [-OUTER, -RING, RING, OUTER]:
		R.append({"a": Vector3(-EXT, 0, c), "b": Vector3(EXT, 0, c), "w": road_w(c)})
		R.append({"a": Vector3(c, 0, -EXT), "b": Vector3(c, 0, EXT), "w": road_w(c)})
	R.append({"a": Vector3(-EXT, 0, 0), "b": Vector3(PLAZA.position.x, 0, 0), "w": ST_W})
	R.append({"a": Vector3(PLAZA.end.x, 0, 0), "b": Vector3(EXT, 0, 0), "w": ST_W})
	R.append({"a": Vector3(0, 0, -EXT), "b": Vector3(0, 0, PLAZA.position.y), "w": ST_W})
	R.append({"a": Vector3(0, 0, PLAZA.end.y), "b": Vector3(0, 0, EXT), "w": ST_W})
	var along: Array = []
	for c in [-OUTER, -RING, 0.0, RING, OUTER]:
		along.append([c, road_w(c) * 0.5 + PAVE_W])
	for edge in 4:
		d["entries"][edge] = along.duplicate(true)

# Block interiors between road centrelines, minus road and pavement.
static func _span(i: int) -> Vector2:
	var a: float = LINES[i]
	var b: float = LINES[i + 1]
	var a_in := 0.0 if absf(a) >= EXT else road_w(a) * 0.5 + PAVE_W
	var b_in := 0.0 if absf(b) >= EXT else road_w(b) * 0.5 + PAVE_W
	return Vector2(a + a_in, b - b_in)

static func _special(i: int, j: int) -> String:
	var key := Vector2i(i, j)
	var specials := {
		Vector2i(4, 3): "carpark", Vector2i(1, 2): "carpark", Vector2i(3, 1): "rubble",
		Vector2i(2, 4): "petrol", Vector2i(4, 1): "shop", Vector2i(1, 4): "shop",
	}
	return specials.get(key, "")

static func _blocks(d: Dictionary, r: RandomNumberGenerator) -> void:
	var h := Defs.HALF
	for j in 6:
		for i in 6:
			var sx := _span(i)
			var sz := _span(j)
			var blk := Rect2(sx.x, sz.x, sx.y - sx.x, sz.y - sz.x)
			if i in [2, 3] and j in [2, 3]:
				_inner_quadrant(d, blk, r)
				continue
			if _special(i, j) != "":
				continue
			var edge := i == 0 or i == 5 or j == 0 or j == 5
			if not edge:
				d["grounds"].append({"r": blk, "kind": "pavement"})
				_fill(d, blk, 1, false, r, true)
				continue
			# The part inside the map is solid blocks right up to the edge;
			# the rest is skyline, drawn but not on the nav grid.
			var inner := Rect2(Vector2(maxf(blk.position.x, -h), maxf(blk.position.y, -h)), Vector2.ZERO)
			inner.end = Vector2(minf(blk.end.x, h), minf(blk.end.y, h))
			d["grounds"].append({"r": blk, "kind": "pavement"})
			if inner.size.x > 4.0 and inner.size.y > 4.0:
				_fill(d, inner, 2, false, r, false)
			var outs: Array = []
			if blk.end.x > h:
				outs.append(Rect2(h, blk.position.y, blk.end.x - h, blk.size.y))
			if blk.position.x < -h:
				outs.append(Rect2(blk.position.x, blk.position.y, -h - blk.position.x, blk.size.y))
			var x0 := maxf(blk.position.x, -h)
			var x1 := minf(blk.end.x, h)
			if blk.end.y > h:
				outs.append(Rect2(x0, h, x1 - x0, blk.end.y - h))
			if blk.position.y < -h:
				outs.append(Rect2(x0, blk.position.y, x1 - x0, -h - blk.position.y))
			for o in outs:
				_fill(d, o, 3, true, r, false)

# The quarter of the ring round the plaza: an L of low blocks, with an alley
# through it in some quarters.
static func _inner_quadrant(d: Dictionary, q: Rect2, r: RandomNumberGenerator) -> void:
	var north := q.position.y < 0.0
	var east := q.position.x > 0.0
	var front := Rect2(q.position.x, q.position.y if north else PLAZA.end.y, q.size.x, 0.0)
	front.size.y = (PLAZA.position.y - q.position.y) if north else (q.end.y - PLAZA.end.y)
	var side := Rect2(PLAZA.end.x if east else q.position.x, PLAZA.position.y if north else q.position.y, 0.0, 0.0)
	side.size.x = (q.end.x - PLAZA.end.x) if east else (PLAZA.position.x - q.position.x)
	side.size.y = (q.end.y - PLAZA.position.y) if north else (PLAZA.end.y - q.position.y)
	d["grounds"].append({"r": front, "kind": "pavement"})
	d["grounds"].append({"r": side, "kind": "pavement"})
	# Alleys: NE runs north out of the plaza, SW south, NW west.
	var cuts_front: Array = []
	var cuts_side: Array = []
	if north and east:
		cuts_front.append(Vector2(19, 23))
	elif not north and not east:
		cuts_front.append(Vector2(-23, -19))
	elif north and not east:
		cuts_side.append(Vector2(-17, -13))
	for piece in _cut(front, cuts_front, true):
		_fill(d, piece, 0, false, r, false)
	for piece in _cut(side, cuts_side, false):
		_fill(d, piece, 0, false, r, false)

static func _cut(rect: Rect2, cuts: Array, along_x: bool) -> Array:
	var out: Array = []
	var a := rect.position.x if along_x else rect.position.y
	var e := rect.end.x if along_x else rect.end.y
	for c in cuts:
		if c.x > a:
			out.append(_sub(rect, a, c.x, along_x))
		a = c.y
	if e > a:
		out.append(_sub(rect, a, e, along_x))
	return out

static func _sub(rect: Rect2, a: float, b: float, along_x: bool) -> Rect2:
	if along_x:
		return Rect2(a, rect.position.y, b - a, rect.size.y)
	return Rect2(rect.position.x, a, rect.size.x, b - a)

# Split a block into buildings: frontages of 10-18 m along its long side,
# two deep when the block is deep, sometimes a through-alley between.
static func _fill(d: Dictionary, rect: Rect2, tier: int, out: bool, r: RandomNumberGenerator, alleys: bool) -> void:
	var horiz := rect.size.x >= rect.size.y
	var L := rect.size.x if horiz else rect.size.y
	var D := rect.size.y if horiz else rect.size.x
	var rows := 2 if D >= 24.0 else 1
	var t := 0.0
	var pieces: Array = []
	while L - t > 0.5:
		var w := float(r.randi_range(5, 9) * 2) if not out else float(r.randi_range(8, 13) * 2)
		if L - t - w < 8.0:
			w = L - t
		pieces.append(Vector2(t, t + w))
		t += w
		if alleys and L - t > 12.0 and r.randf() < 0.25:
			t += 4.0
	for p in pieces:
		var split := D
		if rows == 2:
			split = float(int(D * r.randf_range(0.4, 0.6) / 2.0) * 2)
		for row in rows:
			var d0 := 0.0 if row == 0 else split
			var d1 := split if row == 0 else D
			var b: Rect2
			if horiz:
				b = Rect2(rect.position.x + p.x, rect.position.y + d0, p.y - p.x, d1 - d0)
			else:
				b = Rect2(rect.position.x + d0, rect.position.y + p.x, d1 - d0, p.y - p.x)
			_tower(d, b, tier, out, r)

static func _tower(d: Dictionary, b: Rect2, tier: int, out: bool, r: RandomNumberGenerator, floors: int = 0, burnt: int = -1) -> void:
	var lo: int = [3, 4, 5, 6][tier]
	var hi: int = [4, 7, 9, 12][tier]
	if floors <= 0:
		floors = r.randi_range(lo, hi)
		if minf(b.size.x, b.size.y) < 9.0:
			floors = mini(floors, lo + 1)
	var style := r.randi() % 4
	var pal: Array = PALETTES[style]
	var col: Color = (pal[r.randi() % pal.size()] as Color).darkened(r.randf_range(0.0, 0.12))
	var is_burnt := r.randf() < 0.1 if burnt < 0 else burnt == 1
	d["towers"].append({"r": b, "floors": floors, "style": style, "col": col, "seed": r.randi() % 256, "burnt": is_burnt, "out": out})

static func _plaza(d: Dictionary) -> void:
	var p := PLAZA
	var g: Array = d["grounds"]
	g.append({"r": Rect2(p.position.x, p.position.y, p.size.x, PROM), "kind": "pavement"})
	g.append({"r": Rect2(p.position.x, p.end.y - PROM, p.size.x, PROM), "kind": "pavement"})
	g.append({"r": Rect2(p.position.x, p.position.y + PROM, PROM, p.size.y - PROM * 2.0), "kind": "pavement"})
	g.append({"r": Rect2(p.end.x - PROM, p.position.y + PROM, PROM, p.size.y - PROM * 2.0), "kind": "pavement"})
	var T: Array = d["trees"]
	var ring := [[-19, -16, "tree_oak"], [-8, -17, "tree_birch"], [9, -17, "tree_oak"], [19, -15, "tree_pine"],
		[20, -4, "tree_birch"], [20, 9, "tree_oak"], [18, 17, "tree_birch"], [7, 17, "tree_pine"],
		[-9, 17, "tree_oak"], [-19, 16, "tree_birch"], [-20, 5, "tree_oak"], [-20, -6, "tree_pine"]]
	for t in ring:
		T.append({"pos": Vector3(t[0], 0, t[1]), "model": t[2], "s": 0.9})
	var P: Array = d["props"]
	for b in [[-15, -12, 0.6], [15, -12, -0.6], [-15, 12, 2.5], [15, 12, -2.5], [-17, 0, FACE_E], [17, 0, FACE_W]]:
		P.append({"pos": Vector3(b[0], 0, b[1]), "yaw": b[2], "model": "bench"})
	for b in [[-13, -18], [13, 18], [-21, 11], [21, -10]]:
		P.append({"pos": Vector3(b[0], 0, b[1]), "yaw": float(b[0]) * 0.3, "model": "bush_b" if int(b[0]) % 2 == 0 else "bush_a"})

static func _lots(d: Dictionary) -> void:
	var g: Array = d["grounds"]
	for j in 6:
		for i in 6:
			var kind := _special(i, j)
			if kind == "":
				continue
			var sx := _span(i)
			var sz := _span(j)
			var blk := Rect2(sx.x, sz.x, sx.y - sx.x, sz.y - sz.x)
			match kind:
				"carpark":
					g.append({"r": blk, "kind": "asphalt"})
				"rubble":
					g.append({"r": blk, "kind": "gravel"})
				_:
					g.append({"r": blk, "kind": "pavement" if kind == "shop" else "asphalt"})
	var B: Array = d["buildings"]
	B.append({"pos": Vector3(-22, 0, 62), "yaw": FACE_N, "model": "petrol_station"})
	B.append({"pos": Vector3(62, 0, -62.5), "yaw": FACE_S, "model": "corner_shop"})
	B.append({"pos": Vector3(-62, 0, 62.5), "yaw": FACE_N, "model": "corner_shop"})
	# The rubble lot: a burnt-out stump, collapsed walls and heaps to pick through.
	var r := RandomNumberGenerator.new()
	r.seed = 12
	_tower(d, Rect2(31, -69, 6, 14), 0, false, r, 2, 1)
	d["ruins"].append({"pos": Vector3(13, 0, -63), "yaw": 0.3, "v": 0})
	d["ruins"].append({"pos": Vector3(24, 0, -61), "yaw": 2.6, "v": 1})
	var H: Array = d["heaps"]
	H.append({"pos": Vector3(19, 0, -66.5), "yaw": 0.4, "scrap": Defs.SALVAGE_SCRAP + 40})
	H.append({"pos": Vector3(27, 0, -57.5), "yaw": 1.9, "scrap": Defs.SALVAGE_SCRAP + 40})
	# Rubble spilt into the streets: they narrow a lane, never close one.
	H.append({"pos": Vector3(-59, 0, -77.5), "yaw": 0.1, "scrap": Defs.SALVAGE_SCRAP})
	H.append({"pos": Vector3(77.5, 0, 31), "yaw": 1.5, "scrap": Defs.SALVAGE_SCRAP})
	H.append({"pos": Vector3(-30, 0, 78), "yaw": 3.0, "scrap": Defs.SALVAGE_SCRAP})
	H.append({"pos": Vector3(-77.5, 0, -24), "yaw": 1.7, "scrap": Defs.SALVAGE_SCRAP})
	var P: Array = d["props"]
	for b in [[57, -57, 0.0], [67, -67, PI], [-57, 57, 0.0], [-67, 67, PI]]:
		P.append({"pos": Vector3(b[0], 0, b[1]), "yaw": b[2], "model": "bins"})

static func _street_furniture(d: Dictionary, r: RandomNumberGenerator) -> void:
	var P: Array = d["props"]
	var h := Defs.HALF
	for rd in d["roads"]:
		var a: Vector3 = rd["a"]
		var b: Vector3 = rd["b"]
		var w := float(rd["w"])
		var along := (b - a).normalized()
		var across := Vector3(-along.z, 0, along.x)
		var l := a.distance_to(b)
		var k := 0
		var t := 10.0
		while t < l:
			var p := a + along * t
			t += 22.0
			if absf(p.x) > h - 6.0 or absf(p.z) > h - 6.0:
				continue
			var at: float = p.x if absf(along.x) > 0.5 else p.z
			var near_x := false
			for c in [-OUTER, -RING, 0.0, RING, OUTER]:
				if absf(at - c) < 11.0:
					near_x = true
			if near_x:
				continue
			k += 1
			var side := 1.0 if k % 2 == 0 else -1.0
			var lp := p + across * side * (w * 0.5 + 0.9)
			# The lamp arm points along local -z: turn it to hang over the road.
			var to_road := -across * side
			P.append({"pos": lp, "yaw": atan2(-to_road.x, -to_road.z), "model": "streetlight"})
			if r.randf() < 0.35:
				P.append({"pos": p + across * -side * (w * 0.5 + 1.2) + along * 3.0, "yaw": atan2(-along.x, -along.z), "model": "bins"})

static func _wrecks(d: Dictionary) -> void:
	var W: Array = d["wrecks"]
	var w := [
		[22, -45, 84, "school_bus_wreck"], [-30, -47.5, 100, "car_sedan_wreck"], [-46.5, -20, 8, "car_hatch_wreck"],
		[45, 22, -10, "van_wreck"], [60, 46.5, 95, "car_hatch_wreck"], [0.5, -60, 5, "car_sedan_wreck"],
		[-75, 30, 172, "van_wreck"], [-20, 76.5, 92, "school_bus_wreck"], [36, -1, -84, "car_sedan_wreck"],
		[59, 15, 0, "car_sedan_wreck"], [65, 24, 190, "car_hatch_wreck"], [-60, -15, 0, "car_sedan_wreck"],
		[-11, 60, 12, "car_hatch_wreck"],
	]
	for e in w:
		W.append({"pos": Vector3(e[0], 0, e[1]), "yaw": deg_to_rad(float(e[2])), "model": e[3]})
	var C: Array = d["dead_cars"]
	var c := [
		[47.8, 28, 22, "car_sedan_wreck"], [43.5, 31, -35, "car_hatch_wreck"], [76.5, -20, -6, "car_sedan_wreck"],
		[-38, 0.8, 88, "car_hatch_wreck"], [30, 75, 75, "car_sedan_wreck"], [1.5, 34, -15, "car_hatch_wreck"],
		[-60, 45, 80, "van_wreck"], [-46, 60, 176, "car_sedan_wreck"], [62, -76.5, 98, "van_wreck"],
		[-65, -28, 186, "car_hatch_wreck"], [64, 30, 4, "van_wreck"], [-1.5, 61, 170, "car_sedan_wreck"],
		[-62, -46.5, 263, "car_sedan_wreck"], [76, 62, 8, "car_hatch_wreck"],
	]
	for e in c:
		C.append({"pos": Vector3(e[0], 0, e[1]), "yaw": deg_to_rad(float(e[2])), "model": e[3]})

static func _spots(d: Dictionary) -> void:
	var S: Array = d["spots"]
	for p in [[62, 20], [-62, -22], [10, -57], [-12, 52], [0, -66], [66, 0], [0, 64], [-66, 0],
			[52, -76], [-60, 76], [76, 52], [-76, -60], [30, -46], [-46, 30], [62, -52], [-62, 52]]:
		S.append(Vector3(p[0], 0, p[1]))
