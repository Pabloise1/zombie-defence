class_name SuburbLayout
extends RefCounted
const ROAD_W := 8.0
const PAVE_W := 2.5
const FRONT := 3.0
const LOT_D := 8.0
const BACK := 9.0
const FACE_S := PI
const FACE_N := 0.0
const FACE_E := -PI * 0.5
const FACE_W := PI * 0.5

static func data() -> Dictionary:
	var d := {
		"id": "suburb",
		"hq": Vector3.ZERO,
		"wave_mult": 1.15,
		"roads": [],
		"junctions": [],
		"bulbs": [],
		"lots": [],
		"buildings": [],
		"trees": [],
		"props": [],
		"wrecks": [],
		"fences": [],
		"drives": [],
		"park": Rect2(-24.0, -20.0, 52.0, 44.0),
		"entries": {
			0: [-70.0, -30.0, 38.0, 70.0],
			1: [-60.0, -30.0, 34.0, 75.0],
			2: [-60.0, 0.0, 38.0, 70.0],
			3: [-70.0, -30.0, 34.0, 75.0],
		},
	}
	_roads(d)
	_central_block(d)
	_streets(d)
	_street_furniture(d)
	_wrecks(d)
	_wild(d)
	return d

static func _roads(d: Dictionary) -> void:
	var R: Array = d["roads"]
	R.append({"a": Vector3(-104, 0, 34), "b": Vector3(104, 0, 34)})
	R.append({"a": Vector3(38, 0, -104), "b": Vector3(38, 0, 104)})
	R.append({"a": Vector3(-104, 0, -30), "b": Vector3(38, 0, -30)})
	R.append({"a": Vector3(-34, 0, -30), "b": Vector3(-34, 0, 34)})
	R.append({"a": Vector3(0, 0, 34), "b": Vector3(0, 0, 63)})
	d["junctions"] = [Vector3(38, 0, 34), Vector3(38, 0, -30), Vector3(-34, 0, -30), Vector3(-34, 0, 34), Vector3(0, 0, 34)]
	d["bulbs"] = [{"c": Vector3(0, 0, 70), "r": 9.0}]

static func _central_block(d: Dictionary) -> void:
	var B: Array = d["buildings"]
	B.append({"pos": Vector3(-18, 0, -14.5), "yaw": FACE_N, "model": "house_bungalow"})
	B.append({"pos": Vector3(21, 0, -14.5), "yaw": FACE_N, "model": "house_modern"})
	B.append({"pos": Vector3(-18, 0, 20.5), "yaw": FACE_S, "model": "house_two_storey"})
	B.append({"pos": Vector3(25.5, 0, 21), "yaw": FACE_E, "model": "corner_shop"})
	B.append({"pos": Vector3(51.5, 0, 12), "yaw": FACE_W, "model": "petrol_station"})
	var T: Array = d["trees"]
	var ring := [[-22, -2, "tree_oak"], [-21, 9, "tree_birch"], [-8, -21, "tree_birch"], [6, -21, "tree_oak"],
		[24, -2, "tree_oak"], [26, 8, "tree_birch"], [-6, 25, "tree_oak"], [8, 25, "tree_birch"],
		[-23, -21, "tree_pine"], [29, -22, "tree_pine"], [13, -22, "tree_birch"], [-2, 26, "tree_pine"]]
	for t in ring:
		T.append({"pos": Vector3(t[0], 0, t[1]), "model": t[2], "s": 0.95})
	var P: Array = d["props"]
	P.append({"pos": Vector3(13, 0, 14), "yaw": 0.3, "model": "playground_swings"})
	P.append({"pos": Vector3(-14, 0, 6), "yaw": FACE_E, "model": "bench"})
	P.append({"pos": Vector3(-14, 0, -4), "yaw": FACE_E, "model": "bench"})
	P.append({"pos": Vector3(17, 0, 2), "yaw": FACE_W, "model": "bench"})
	for b in [[-15, 13], [16, -9], [-10, -16], [4, 18]]:
		P.append({"pos": Vector3(b[0], 0, b[1]), "yaw": float(b[0]) * 0.3, "model": "bush_b" if int(b[0]) % 2 == 0 else "bush_a"})

static func _streets(d: Dictionary) -> void:
	var elm_n := ["house_two_storey", "house_bungalow", "house_modern", "house_two_storey", "house_bungalow", "house_modern", "house_two_storey"]
	var xs := [-84, -70, -56, -42, -28, -14, 0]
	var fronts := ["hedge", "picket", "brick", "picket", "hedge", "brick", "picket"]
	for i in xs.size():
		_lot(d, Vector3(xs[i], 0, -30 - ROAD_W * 0.5 - PAVE_W - FRONT - LOT_D * 0.5), FACE_S, elm_n[i], fronts[i], i)
	_lot(d, Vector3(-84, 0, -30 + ROAD_W * 0.5 + PAVE_W + FRONT + LOT_D * 0.5), FACE_N, "house_modern", "hedge", 10)
	_lot(d, Vector3(-58, 0, -30 + ROAD_W * 0.5 + PAVE_W + FRONT + LOT_D * 0.5), FACE_N, "house_two_storey", "brick", 11)
	_lot(d, Vector3(-34 - ROAD_W * 0.5 - PAVE_W - FRONT - LOT_D * 0.5, 0, 6), FACE_E, "house_bungalow", "picket", 12)
	_lot(d, Vector3(-34 - ROAD_W * 0.5 - PAVE_W - FRONT - LOT_D * 0.5, 0, 19), FACE_E, "house_two_storey", "hedge", 13)
	_lot(d, Vector3(-82, 0, 34 - ROAD_W * 0.5 - PAVE_W - FRONT - LOT_D * 0.5), FACE_S, "house_bungalow", "brick", 14)
	var r1 := [[-84, "house_two_storey", "picket"], [-62, "house_modern", "hedge"], [-44, "house_bungalow", "brick"],
		[-28, "house_two_storey", "hedge"], [-14, "house_bungalow", "picket"], [14, "house_modern", "brick"],
		[54, "house_two_storey", "hedge"], [78, "house_bungalow", "picket"]]
	for i in r1.size():
		_lot(d, Vector3(r1[i][0], 0, 34 + ROAD_W * 0.5 + PAVE_W + FRONT + LOT_D * 0.5), FACE_N, r1[i][1], r1[i][2], 20 + i)
	_lot(d, Vector3(-(ROAD_W * 0.5 + PAVE_W + FRONT + LOT_D * 0.5), 0, 68), FACE_E, "house_modern", "hedge", 30)
	_lot(d, Vector3(ROAD_W * 0.5 + PAVE_W + FRONT + LOT_D * 0.5, 0, 68), FACE_W, "house_two_storey", "picket", 31)
	_lot(d, Vector3(0, 0, 70 + 9.0 + PAVE_W + FRONT + LOT_D * 0.5), FACE_N, "house_bungalow", "brick", 32)
	var r2 := [[-84, "house_bungalow", "hedge"], [-58, "house_two_storey", "picket"], [-16, "house_modern", "brick"]]
	for i in r2.size():
		_lot(d, Vector3(38 + ROAD_W * 0.5 + PAVE_W + FRONT + LOT_D * 0.5, 0, r2[i][0]), FACE_W, r2[i][1], r2[i][2], 40 + i)
	_lot(d, Vector3(38 - ROAD_W * 0.5 - PAVE_W - FRONT - LOT_D * 0.5, 0, -72), FACE_E, "house_two_storey", "hedge", 45)

static func _lot(d: Dictionary, c: Vector3, yaw: float, model: String, front: String, seed_i: int) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var L := func(x: float, z: float) -> Vector3: return c + basis * Vector3(x, 0, z)
	d["lots"].append({"pos": c, "yaw": yaw, "model": model})
	var fz := -LOT_D * 0.5 - FRONT + 0.4
	if front != "none":
		d["fences"].append({"kind": front, "pts": [L.call(-6.0, fz), L.call(-1.2, fz)]})
		d["fences"].append({"kind": front, "pts": [L.call(4.2, fz), L.call(6.0, fz)]})
	var back_kind := "wood" if seed_i % 4 != 3 else "brick"
	var bz := LOT_D * 0.5 + BACK
	d["fences"].append({"kind": back_kind, "pts": [L.call(-5.6, 0.5), L.call(-5.6, bz), L.call(5.6, bz), L.call(5.6, 0.5)]})
	d["drives"].append({"a": L.call(2.7, fz - 0.4), "b": L.call(2.7, -LOT_D * 0.5 + 0.6), "w": 3.0})
	var P: Array = d["props"]
	P.append({"pos": L.call(4.6, -LOT_D * 0.5 - 1.2), "yaw": yaw + PI * 0.5, "model": "bins"})
	P.append({"pos": L.call(-1.8, fz - 0.3), "yaw": yaw, "model": "mailbox"})
	match seed_i % 5:
		0:
			P.append({"pos": L.call(-1.5, LOT_D * 0.5 + 4.5), "yaw": yaw + 0.4, "model": "trampoline"})
		1:
			d["trees"].append({"pos": L.call(-3.5, LOT_D * 0.5 + 6.5), "model": "tree_birch", "s": 0.8})
		2:
			d["trees"].append({"pos": L.call(3.0, LOT_D * 0.5 + 6.0), "model": "tree_oak", "s": 0.75})
			P.append({"pos": L.call(-3.5, -LOT_D * 0.5 - 1.5), "yaw": yaw, "model": "bush_a"})
		3:
			P.append({"pos": L.call(2.4, LOT_D * 0.5 + 5.5), "yaw": yaw + PI, "model": "garage_detached"})
		_:
			P.append({"pos": L.call(-3.0, -LOT_D * 0.5 - 1.6), "yaw": yaw + 1.0, "model": "bush_b"})

static func _street_furniture(d: Dictionary) -> void:
	var P: Array = d["props"]
	var off := ROAD_W * 0.5 + 0.9
	for x in range(-88, 96, 24):
		var side := 1.0 if (x / 24) % 2 == 0 else -1.0
		if absf(x - 38) < 8 or absf(x) < 6 or absf(x + 34) < 8:
			continue
		P.append({"pos": Vector3(x, 0, 34 + side * off), "yaw": 0.0 if side > 0 else PI, "model": "streetlight"})
	for z in range(-88, 96, 24):
		var side2 := 1.0 if (z / 24) % 2 == 0 else -1.0
		if absf(z - 34) < 8 or absf(z + 30) < 8:
			continue
		P.append({"pos": Vector3(38 + side2 * off, 0, z), "yaw": -PI * 0.5 if side2 > 0 else PI * 0.5, "model": "streetlight"})
	for x in range(-80, 30, 26):
		P.append({"pos": Vector3(x, 0, -30 + off), "yaw": 0.0, "model": "streetlight"})
	for z in [-14, 10]:
		P.append({"pos": Vector3(-34 + off, 0, z), "yaw": -PI * 0.5, "model": "streetlight"})
	P.append({"pos": Vector3(off, 0, 50), "yaw": -PI * 0.5, "model": "streetlight"})
	for x in range(-92, 96, 30):
		if absf(x - 38) < 8:
			continue
		P.append({"pos": Vector3(x + 7, 0, 34 - off - 0.6), "yaw": 0.0, "model": "power_pole"})
	for z in range(-90, 96, 30):
		if absf(z - 34) < 8 or absf(z + 30) < 8:
			continue
		P.append({"pos": Vector3(38 - off - 0.6, 0, z + 7), "yaw": PI * 0.5, "model": "power_pole"})

static func _wrecks(d: Dictionary) -> void:
	var W: Array = d["wrecks"]
	W.append({"pos": Vector3(-63, 0, -30.5), "yaw": deg_to_rad(68.0), "model": "school_bus_wreck"})
	W.append({"pos": Vector3(-22, 0, 32.2), "yaw": deg_to_rad(96.0), "model": "car_sedan_wreck"})
	W.append({"pos": Vector3(36.4, 0, -52), "yaw": deg_to_rad(8.0), "model": "car_hatch_wreck"})
	W.append({"pos": Vector3(62, 0, 35.5), "yaw": deg_to_rad(82.0), "model": "van_wreck"})
	W.append({"pos": Vector3(39.5, 0, 66), "yaw": deg_to_rad(-12.0), "model": "car_sedan_wreck"})
	W.append({"pos": Vector3(-36, 0, 2), "yaw": deg_to_rad(4.0), "model": "car_hatch_wreck"})
	W.append({"pos": Vector3(2.5, 0, 54), "yaw": deg_to_rad(-20.0), "model": "van_wreck"})
	W.append({"pos": Vector3(-8, 0, -31), "yaw": deg_to_rad(100.0), "model": "car_sedan_wreck"})
	W.append({"pos": Vector3(82, 0, 32.5), "yaw": deg_to_rad(-80.0), "model": "car_hatch_wreck"})
	W.append({"pos": Vector3(37, 0, -84), "yaw": deg_to_rad(175.0), "model": "van_wreck"})

static func _wild(d: Dictionary) -> void:
	var T: Array = d["trees"]
	var r := RandomNumberGenerator.new()
	r.seed = 4417
	var tries := 0
	var placed := 0
	while placed < 46 and tries < 900:
		tries += 1
		var p := Vector3(r.randf_range(-92, 92), 0, r.randf_range(-92, 92))
		var wild := p.z < -63.0 or (p.x > 60.0 and p.z > 42.0 and p.z < 90.0) or (p.x < -60.0 and p.z > 62.0)
		if not wild:
			continue
		if absf(p.x - 38) < 9 or absf(p.z - 34) < 9:
			continue
		var close := false
		for t in T:
			if (t["pos"] as Vector3).distance_to(p) < 6.5:
				close = true
		for l in d["lots"]:
			if (l["pos"] as Vector3).distance_to(p) < 13.0:
				close = true
		if close:
			continue
		var m := "tree_pine" if r.randf() < 0.5 else ("tree_oak" if r.randf() < 0.5 else "tree_birch")
		T.append({"pos": p, "model": m, "s": r.randf_range(0.85, 1.15)})
		placed += 1
