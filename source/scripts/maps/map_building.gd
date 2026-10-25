class_name MapBuilding
extends PrefabBuilding
var claimed := false
var claiming := false
# Houses aren't claimed any more: workers knock them down for supplies.
var cleared := false
var contents := {}
var exploded := false
var fp_off := Vector3.ZERO
var map = null

func setup_map(k: String, lot_pos: Vector3, y: float, m) -> void:
	map = m
	kind = k
	def = Defs.MAP_BUILDINGS[k]
	var fp: Dictionary = Art.footprint("suburb/" + k)
	fp_off = fp["off"]
	var h: Vector2 = fp["half"]
	rect = true
	half = h
	yaw = y
	var center := lot_pos + Basis(Vector3.UP, y) * fp_off
	var fpr: Dictionary = G.grid.rect_footprint(center, y, h.x, h.y)
	nav_list = fpr["nav"]
	cell_list = fpr["cells"]
	cell = cell_list[0] if not cell_list.is_empty() else Defs.world_to_cell(center)
	size = 1
	max_hp = float(def.get("hp", 3000.0))
	hp = max_hp
	position = Vector3(center.x, 0, center.z)
	rotation.y = y
	model = Art.model("suburb/" + k)
	model.position = -fp_off
	add_child(model)
	for i in slot_count():
		mounted.append(null)
	state = BUILT
	progress = 1.0

func marker_world(n: String) -> Vector3:
	var mk := model.find_child(n, true, false) as Node3D if model else null
	return mk.global_position if mk else Vector3.INF

func is_wallish() -> bool:
	return claimed

func blocks_now() -> bool:
	return claimed and state == BUILT

func has_health() -> bool:
	return claimed

func entry_point() -> Vector3:
	var d := marker_world("Door1")
	if d != Vector3.INF:
		return Vector3(d.x, 0, d.z)
	return super.entry_point()

func access_goals() -> Dictionary:
	var goals: Dictionary = G.grid.point_goals(entry_point(), 1)
	if goals.is_empty():
		goals = G.grid.ring_goals(nav_list)
	return goals

func job_goals() -> Dictionary:
	return access_goals()

func capacity() -> int:
	return int(def.get("capacity", 0)) if claimed else 0

func claim_cost() -> int:
	return int(def.get("claim", 120))

func clear_value() -> int:
	return int(def.get("claim", 50))

func start_clear() -> String:
	if cleared or claiming:
		return "Already being cleared"
	claiming = true
	progress = 0.0
	paid = 0
	G.workers.add_job(self)
	return ""

func start_claim() -> String:
	if claimed or claiming:
		return "Already yours"
	if not G.main.spend(claim_cost()):
		return "Claiming costs %d" % claim_cost()
	claiming = true
	progress = 0.0
	paid = claim_cost()
	G.workers.add_job(self)
	return ""

func cancel_claim() -> void:
	if not claiming:
		return
	claiming = false
	G.workers.remove_job(self)
	paid = 0
	progress = 1.0

func job_valid() -> bool:
	return claiming and not claimed and is_inside_tree()

func job_ready() -> bool:
	return true

func work(dt: float) -> bool:
	if not claiming:
		return true
	progress += dt / maxf(0.5, float(def.get("claim_time", 18.0)))
	if G.fx and randf() < dt * 1.2:
		G.fx.dust(position + Vector3(randf_range(-2, 2), 0.6, randf_range(-2, 2)), 1.0)
	if progress >= 1.0:
		_cleared()
		return true
	return false

func _cleared(quiet: bool = false) -> void:
	claiming = false
	cleared = true
	state = DEAD
	visible = false
	map.unblock(nav_list, self)
	for c in cell_list:
		var i: int = G.grid.idx(c)
		if G.grid.occ[i] == self:
			G.grid.occ[i] = null
	G.grid.notify_paths_changed()
	if quiet:
		return
	if G.fx:
		G.fx.dust(position + Vector3(0, 0.8, 0), 3.0)
		G.fx.debris(position + Vector3(0, 1.0, 0), 3)
	if G.sfx:
		G.sfx.play("build", position)
	G.main.add_supplies(clear_value())
	var found := ""
	if contents.has("survivors"):
		var n := mini(int(contents["survivors"]), maxi(1, G.people.room()))
		for i in n:
			G.people.spawn_civilian(position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), false)
		found = "  ·  %d survivor%s were hiding" % [n, "" if n == 1 else "s"]
	elif contents.has("supplies"):
		G.main.add_supplies(int(contents["supplies"]))
		found = "  ·  found %d more" % int(contents["supplies"])
	elif contents.has("crates"):
		var got: int = G.logi.add_crates(int(contents["crates"]), position)
		found = "  ·  found %d ammo crate%s" % [got, "" if got == 1 else "s"]
	contents = {}
	if G.hud:
		G.hud.toast("Cleared +%d supplies%s" % [clear_value(), found])

func _claimed(quiet: bool = false) -> void:
	claiming = false
	claimed = true
	progress = 1.0
	hp = max_hp
	map.unblock(nav_list, self)
	for c in cell_list:
		G.grid.occ[G.grid.idx(c)] = self
	G.grid.mark_nav(nav_list, Grid.N_BUILD, self)
	G.buildings.list.append(self)
	G.buildings.refresh_zones()
	G.grid.notify_paths_changed()
	if quiet:
		return
	_pop = 1.0
	if G.fx:
		G.fx.dust(position + Vector3(0, 0.4, 0), 2.0)
	if G.sfx:
		G.sfx.play("build", position)
	_reveal()

func _reveal() -> void:
	var msg := "Claimed. Nothing inside"
	if contents.has("survivors"):
		var n := mini(int(contents["survivors"]), maxi(1, G.people.room()))
		var door := entry_point()
		for i in n:
			G.people.spawn_civilian(door + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), true)
		msg = "%d survivor%s were hiding inside" % [n, "" if n == 1 else "s"]
	elif contents.has("supplies"):
		G.main.add_supplies(int(contents["supplies"]))
		msg = "Found %d supplies inside" % int(contents["supplies"])
	elif contents.has("crates"):
		var got: int = G.logi.add_crates(int(contents["crates"]), position)
		msg = "Found %d ammo crate%s inside" % [got, "" if got == 1 else "s"]
	contents = {}
	if G.hud:
		G.hud.toast(msg)

func explode() -> void:
	if exploded:
		return
	exploded = true
	var c := position
	var pu := marker_world("PumpArea")
	if pu != Vector3.INF:
		c = Vector3(pu.x, 0, pu.z)
	var p := c + Vector3(0, 1.0, 0)
	if G.fx:
		G.fx.explosion(p, 3.2)
		G.fx.explosion(p + Vector3(2, 0.5, 1), 2.4)
		G.fx.debris(p, 4)
		for k in 5:
			var a := TAU * k / 5.0 + randf() * 0.6
			G.fx.fire_patch(c + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 7.0), randf_range(1.8, 2.8), randf_range(10.0, 16.0))
		G.fx.smoke(p + Vector3(0, 2.0, 0), 20.0, 2.6)
	if G.cam:
		G.cam.shake(1.4)
	if G.sfx:
		G.sfx.play("mine_explosion", p)
		G.sfx.play("boom", p)
	G.zombies.damage_radius(p, 14.0, 500.0)
	for b in G.buildings.list.duplicate():
		if is_instance_valid(b) and b != self and b.state == BUILT and b.has_health() and b.host == null:
			if b.edge_distance(c) < 10.0:
				b.take_damage(900.0)
	for q in G.people.all_people():
		if is_instance_valid(q) and not q.dead and q.exposed() and q.position.distance_to(c) < 8.0:
			q.take_damage(500.0)
	if claimed:
		destroy(false)
	else:
		claimed = false
		def = def.duplicate()
		def["claim"] = 0
		model.scale = Vector3(1, 0.7, 1)

func take_damage(amount: float, from = null) -> void:
	super.take_damage(amount, from)
	if kind == "petrol_station" and claimed and not exploded and hp < max_hp * 0.3 and state == BUILT:
		explode()

func long_name() -> String:
	return String(def.get("long", kind))

func card_lines() -> Array:
	var out := []
	if not claimed:
		if claiming:
			out.append("Being cleared  %d%%" % int(progress * 100.0))
		else:
			out.append("In the way? Workers can knock it down (~%ds) for +%d supplies" % [int(def.get("claim_time", 18.0)), clear_value()])
			out.append("Might hide survivors or supplies")
		if kind == "petrol_station" and not exploded:
			out.append("Pumps: a shell or blast there sets them off. Big explosion")
		elif exploded:
			out.append("Burnt out")
		return out
	out = super.card_lines()
	var n: int = G.people.sheltered_in(self) if G.people else 0
	out.insert(0, "Safe house  ·  sheltering %d/%d  ·  draws survivors" % [n, G.people.shelter_cap(self) if G.people else 0])
	if kind == "petrol_station" and not exploded:
		out.append("Careful: hits on the pumps blow it up")
	return out

func card_buttons() -> Array:
	if not claimed:
		if exploded:
			return []
		if claiming:
			return [["cancel_claim", "CANCEL", true]]
		return [["clear_house", "CLEAR +%d" % clear_value(), true]]
	var out := []
	if capacity() > 0:
		var idle: int = G.soldiers.idle_count() if G.soldiers else 0
		out.append(["assign", "ASSIGN" if free_slots() > 0 else "FULL", free_slots() > 0 and idle > 0])
	if slot_count() > 0 and free_slot() >= 0:
		out.append(["slot", "ADD GUN", true])
	return out
