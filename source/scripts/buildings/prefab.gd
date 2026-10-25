class_name PrefabBuilding
extends Building
var crates := 0
var _heal_t := 0.0

func _on_model_ready() -> void:
	pass

func store_cap() -> int:
	return int(def.get("store", 0)) if state == BUILT else 0

func is_wallish() -> bool:
	return true

func inward() -> Vector3:
	var back := global_transform.basis.z.normalized()
	if G.zones:
		if G.zones.zone_at(position + back * 2.2) > 0:
			return back
		if G.zones.zone_at(position - back * 2.2) > 0:
			return -back
	return back if (Defs.hq_center() - position).dot(back) > 0.0 else -back

func entry_point() -> Vector3:
	if kind.begins_with("bastion"):
		return position + inward() * (half.y + 1.0)
	return super.entry_point()

func access_goals() -> Dictionary:
	if kind.begins_with("bastion"):
		return G.grid.point_goals(entry_point(), 1)
	var door: Node3D = model.find_child("Door", true, false) as Node3D if model else null
	if door:
		var goals: Dictionary = G.grid.point_goals(door.global_position, 1)
		if not goals.is_empty():
			return goals
	return G.grid.ring_goals(G.grid.building_nav_cells(self))

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	port_tick(dt)
	if def.has("heal"):
		_heal_t -= dt
		if _heal_t <= 0.0:
			_heal_t = 1.0
			var r2 := pow(float(def.get("heal_range", 14.0)), 2.0)
			for p in G.people.all_people():
				if is_instance_valid(p) and not p.dead and p.hp < p.max_hp and p.position.distance_squared_to(position) < r2:
					p.hp = minf(p.max_hp, p.hp + float(def["heal"]))
	if kind == "barracks":
		_heal_t -= dt
		if _heal_t <= 0.0:
			_heal_t = 1.0
			for s in G.soldiers.soldiers:
				if s.dead or s.hp >= s.max_hp:
					continue
				if occupants.has(s) or s.position.distance_to(position) < 12.0:
					s.hp = minf(s.max_hp, s.hp + 4.0)

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var out := []
	match kind:
		"house":
			out.append("+%d people  ·  room %d/%d" % [int(def.get("pop", 0)), G.people.population(), G.people.pop_cap()])
		"barracks":
			out.append("+%d people  ·  soldiers heal  ·  arming costs %d" % [int(def.get("pop", 0)), Defs.SOLDIER_ARM_COST_BARRACKS])
		"depot":
			out.append("Ammo crates %d/%d" % [crates, store_cap()])
		"workshop":
			var n: int = G.people.crafters_at(self) if G.people else 0
			out.append("Crafters %d/%d  ·  %d supplies make 1 crate" % [n, Defs.CRAFTERS_PER_WORKSHOP, Defs.CRATE_COST])
		"watchtower":
			out.append("Roof gun +%d%% range" % int(slot_bonus() * 100.0))
		"greenhouse":
			out.append("+%d supplies after every wave it survives" % int(def.get("income", 0)))
		"clinic":
			out.append("Heals people and soldiers within %d m" % int(def.get("heal_range", 14.0)))
		"armory":
			out.append("All soldiers do +25%% damage (%.0f a shot)" % G.soldiers.damage())
		"scrapyard":
			out.append("Fetchers' hauls +50%  ·  scrap piles refill twice as fast")
		_:
			out.append(String(def.get("about", "")))
	var free := 0
	for i in mounted.size():
		if mounted[i] == null or not is_instance_valid(mounted[i]):
			free += 1
	if mounted.size() > 0:
		out.append("Roof slots %d free of %d  ·  +%d%% range up there" % [free, mounted.size(), int(slot_bonus() * 100.0)])
	if capacity() > 0:
		var s := "Soldiers at the %s %d/%d" % ["ports" if kind.begins_with("bastion") else "windows", occupants.size(), capacity()]
		if not incoming.is_empty():
			s += "  (+%d coming)" % incoming.size()
		out.append(s)
	if moving_to != null:
		out.append("Moving: workers are building the new spot")
	return out
