class_name Logistics
extends Node3D
var salvage: Array = []
var hq_crates := 0
var crafted := 0
var fetched := 0
var zone_fed := 0

func setup(spots: Array) -> void:
	hq_crates = Defs.START_CRATES
	for p in spots:
		var s := SalvageSpot.new()
		add_child(s)
		s.setup(p["pos"], String(p["model"]), int(p.get("scrap", Defs.SALVAGE_SCRAP)))
		salvage.append(s)

func stores() -> Array:
	var out := []
	var hq = G.buildings.hq if G.buildings else null
	if hq != null and hq.state != Building.DEAD:
		out.append({"node": hq, "crates": hq_crates, "cap": Defs.HQ_STORE, "pos": hq.position})
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state != Building.BUILT:
			continue
		if b.kind == "depot" or b.kind == "ammo_point":
			out.append({"node": b, "crates": b.crates, "cap": b.store_cap(), "pos": b.position})
	return out

func crates_total() -> int:
	var n := 0
	for s in stores():
		n += int(s["crates"])
	return n

func capacity_total() -> int:
	var n := 0
	for s in stores():
		n += int(s["cap"])
	return n

func crates_of(node) -> int:
	if node == G.buildings.hq:
		return hq_crates
	if node != null and is_instance_valid(node) and "crates" in node:
		return node.crates
	return 0

func set_crates(node, n: int) -> void:
	if node == G.buildings.hq:
		hq_crates = n
	elif node != null and is_instance_valid(node) and "crates" in node:
		node.crates = n

func take_crates(n: int) -> int:
	var got := 0
	var ss := stores()
	ss.sort_custom(func(a, b): return int(a["crates"]) > int(b["crates"]))
	for s in ss:
		while got < n and take_crate(s["node"]):
			got += 1
	return got

func take_crate(node) -> bool:
	var n := crates_of(node)
	if n <= 0:
		return false
	set_crates(node, n - 1)
	return true

func add_crates(n: int, near: Vector3 = Vector3.INF) -> int:
	var placed := 0
	var ss := stores()
	ss.sort_custom(func(a, b): return _store_rank(a, near) < _store_rank(b, near))
	for s in ss:
		while placed < n and int(s["crates"]) < int(s["cap"]):
			s["crates"] = int(s["crates"]) + 1
			set_crates(s["node"], int(s["crates"]))
			placed += 1
	return placed

func _store_rank(s: Dictionary, near: Vector3) -> float:
	var node = s["node"]
	var r := 0.0
	if node is SupplyDevice:
		r = 1000.0
	elif node == G.buildings.hq:
		r = 500.0
	if near != Vector3.INF:
		r += (s["pos"] as Vector3).distance_to(near)
	return r

func _zone_stores(zone: int) -> Array:
	var out := []
	for s in stores():
		var node = s["node"]
		if int(s["crates"]) > 0 and is_instance_valid(node) and int(node.zone) == zone:
			out.append(s)
	return out

func zone_has_crates(zone: int) -> bool:
	return zone > 0 and not _zone_stores(zone).is_empty()

func take_zone_crate(zone: int) -> bool:
	if zone <= 0:
		return false
	var ss := _zone_stores(zone)
	if ss.is_empty():
		return false
	ss.sort_custom(func(a, b): return int(a["crates"]) > int(b["crates"]))
	return take_crate(ss[0]["node"])

func nearest_with_crates(p: Vector3, exclude = null):
	var best = null
	var bd := INF
	for s in stores():
		if int(s["crates"]) <= 0 or s["node"] == exclude:
			continue
		var d: float = (s["pos"] as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = s["node"]
	return best

func ammo_point_to_fill():
	for b in G.buildings.list:
		if is_instance_valid(b) and b.kind == "ammo_point" and b.state == Building.BUILT and b.crates < b.store_cap():
			return b
	return null

func has_room() -> bool:
	return crates_total() < capacity_total()

func pop_cap() -> int:
	var n := Defs.POP_BASE
	for b in G.buildings.list:
		if is_instance_valid(b) and b.state == Building.BUILT:
			n += b.pop_bonus()
	return n

func radio_count() -> int:
	return mini(2, G.buildings.count_built("radio"))

func fuel_near(p: Vector3) -> bool:
	for b in G.buildings.list:
		if is_instance_valid(b) and b.kind == "fuel" and b.state == Building.BUILT and b.position.distance_to(p) <= Defs.FUEL_RANGE:
			return true
	return false

func soldier_cost() -> int:
	return Defs.SOLDIER_ARM_COST_BARRACKS if G.buildings.count_built("barracks") > 0 else Defs.SOLDIER_ARM_COST

func pick_salvage(p: Vector3):
	var best = null
	var bs := -INF
	for s in salvage:
		if s.scrap <= 0:
			continue
		if G.zombies and (G.zombies.count_near(s.position, 18.0) > 0 or G.zombies.danger_on_line(p, s.position) > 2.0):
			continue
		var score: float = -s.position.distance_to(p) - s.fetchers * 25.0
		if score > bs:
			bs = score
			best = s
	return best

func on_wave_cleared() -> void:
	for s in salvage:
		s.scrap = mini(s.scrap_max, s.scrap + 20)
		s.refresh()
