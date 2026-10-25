extends SceneTree
# Save round trip: build a varied base, save, reload the scene from the
# save, and compare what's there. Prints SAVE lines; "SAVE MATCH" at the end.
var started := false
var m = null
var g = null
var SG = null
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false

func _place(kind: String, near: Vector3, built := true):
	for r in range(0, 40, 2):
		for k in 12:
			var p: Vector3 = near + Vector3(cos(k * 0.5236), 0, sin(k * 0.5236)) * r
			if m.buildings.check_rect(kind, p, 0.0, null, []) == "":
				return m.buildings.place_rect(kind, p, 0.0, built)
	return null

func _ground(kind: String, near: Vector3, built := true):
	for r in range(0, 30, 2):
		for k in 12:
			var c: Vector2i = Defs.world_to_cell(near + Vector3(cos(k * 0.5236), 0, sin(k * 0.5236)) * r)
			if m.buildings.check(kind, c) == "":
				if built:
					return m.buildings.place_built(kind, c)
				m.buildings.place(kind, c)
				return m.buildings.last_placed
	return null

func _summary() -> Dictionary:
	var s := {}
	for b in m.buildings.list:
		if not is_instance_valid(b) or b.state == 2:
			continue
		var k := "%s/%s" % [b.kind, ["bp", "built"][b.state]]
		if b.host != null:
			k = "mounted:" + k
		s[k] = int(s.get(k, 0)) + 1
		if b.kind == "room_block":
			s["storeys"] = b.storeys
		if not b.occupants.is_empty():
			s["posted:" + b.kind] = int(s.get("posted:" + b.kind, 0)) + b.occupants.size()
		if "crates" in b and b.crates > 0:
			s["crates:" + b.kind] = b.crates
	var trench := 0
	for t in m.grid.terrain:
		if t == 1:
			trench += 1
	s["trench"] = trench
	for j in Defs.JOBS:
		s["job:" + j] = m.people.count_job(j)
	s["idle"] = m.people.owned_civilians().size()
	s["supplies"] = m.supplies
	s["wave"] = m.wave
	s["hq_crates"] = m.logi.hq_crates
	s["helis"] = g.helis.list.size()
	s["fences_claimed"] = g.map.fences.filter(func(f): return f.claimed).size() if g.map else 0
	s["hq_zone"] = m.people.hq_zone()
	return s

func _run() -> void:
	g = root.get_node("G")
	SG = load("res://scripts/save_game.gd")
	g.map_id = "suburb"
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 999.0
	m.wave = 8
	m.zombies.wave = 8
	m.supplies = 20000
	var c: Vector3 = Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in m.START_RING:
		ring.append(c + q * 1.3)
	m.walls.build_ring("concrete", ring)
	m.walls.build_gate_now(c + Vector3(0, 0, 12.0 * 1.3))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	var t1 = _ground("turret", c + Vector3(-6, 0, -6))
	_ground("turret", c + Vector3(6, 0, -6))
	_ground("mortar", c + Vector3(6, 0, 6))
	_ground("turret", c + Vector3(-7, 0, 7), false)
	var rb = _place("room_block", c + Vector3(-9, 0, 0))
	rb.finish_floor()
	rb.finish_floor()
	m.buildings.mount(rb, 0, "turret", false, true)
	m.buildings.mount(rb, 3, "sniper", false, true)
	_place("workshop", c + Vector3(0, 0, -9))
	_place("depot", c + Vector3(9, 0, 0))
	var gar = _ground("garrison", c + Vector3(0, 0, 8))
	var seg = m.walls.segments.filter(func(x): return x.kind == "concrete" and x.state == 1 and x.length > 2.0)[0]
	m.walls.add_nest(seg, seg.position, "turret")
	for b in m.buildings.list:
		if b.kind == "nest":
			b._finish(true)
			for x in b.mounted:
				if x:
					x._finish(true)
	for k in 6:
		var tc: Vector2i = Defs.world_to_cell(c + Vector3(-26 + k * 2.0, 0, -26))
		m.grid.set_trench(tc)
		m.terrain.cell_changed(tc)
	var houses: Array = g.map.buildings.filter(func(b): return b.kind.begins_with("house"))
	houses[0]._claimed()
	m.buildings.mount(houses[0], 0, "turret", false, true)
	g.map.fences[0].claim()
	var pad = _place("helipad", c + Vector3(24, 0, 24))
	if pad:
		pad.heli = g.helis.add_heli("huey", pad)
		pad.heli.park_now()
	for i in 14:
		m.people.spawn_civilian(c + Vector3(0, 0, 5), true)
	for i in 3:
		m.people.add_job("soldier")
	for i in 2:
		m.people.add_job("crafter")
	m.people.add_job("loader")
	m.people.add_job("fetcher")
	for i in 30:
		m.sim_step(1.0 / 30.0)
	if gar:
		for s in g.soldiers.idle_soldiers().slice(0, 2):
			s.assign(gar)
	for i in 300:
		m.sim_step(1.0 / 30.0)
	m.logi.hq_crates = 7
	var before := _summary()
	SG.write(m)
	var info = SG.summary()
	print("SAVE wrote: ", info)
	g.resume = SG.read()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	for i in 300:
		m.sim_step(1.0 / 30.0)
	var after := _summary()
	var bad := 0
	var keys := before.keys()
	for k in after.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	for k in keys:
		var same: bool = before.get(k) == after.get(k)
		if not same:
			bad += 1
		print("SAVE %s %-28s before=%s after=%s" % ["  " if same else "!!", k, str(before.get(k)), str(after.get(k))])
	print("SAVE phase=%s phase_t=%.0f title=%s" % [m.phase, m.phase_t, m.hud.title_card.visible])
	print("SAVE MATCH" if bad == 0 else "SAVE DIFF %d" % bad)
	SG.clear()
	quit()
