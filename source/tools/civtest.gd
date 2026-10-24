extends SceneTree
# Scenario checks for rescues, safe houses and room block gun slots.
# TEST=rescue|shelter|block   (shelter needs the suburb map: -- --map=suburb)
var started := false
var m = null
var g = null
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false

func _sim(sec: float) -> void:
	var n := int(sec * 30.0)
	for i in n:
		m.sim_step(1.0 / 30.0)
		if i % 60 == 0:
			await process_frame

func _base() -> void:
	var c: Vector3 = Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in m.START_RING:
		ring.append(c + q)
	m.walls.build_ring("wall", ring)
	m.walls.build_gate_now(c + Vector3(0, 0, 12.0))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()

func _place(kind: String, near: Vector3):
	for r in range(0, 30, 3):
		for k in 8:
			var p: Vector3 = near + Vector3(cos(k * 0.785), 0, sin(k * 0.785)) * r
			if m.buildings.check_rect(kind, p, 0.0, null, []) == "":
				return m.buildings.place_rect(kind, p, 0.0, true)
	print("CIV could not place ", kind, ": ", m.buildings.check_rect(kind, near, 0.0, null, []))
	quit()
	return null

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			root.get_node("G").map_id = a.substr(6)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	g = root.get_node("G")
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	m.supplies = 5000
	m.wave = 8 if OS.get_environment("TEST") == "block" else 3
	var test := OS.get_environment("TEST")
	var c: Vector3 = Defs.hq_center()
	if test == "rescue":
		_base()
		for i in 2:
			m.people.add_job("fetcher")
		await _sim(3.0)
		var far: Vector3 = c + Vector3(40, 0, -45)
		var grp = m.people.spawn_stranded(far, 4)
		print("CIV fetchers=%d stranded=%d pop=%d" % [m.people.fetchers.size(), m.people.stranded_count(), m.people.population()])
		m.start_wave()
		for t in 16:
			await _sim(5.0)
			var modes := []
			for f in m.people.fetchers:
				modes.append(["IDLE", "GO", "SEARCH", "CARRY", "FLEE", "RESCUE", "LEAD"][f.mode])
			print("CIV t=%3ds fetchers %s  stranded=%d  arriving=%d  pop=%d  saved=%d lost=%d zombies=%d" % [(t + 1) * 5, str(modes), m.people.stranded_count(), m.people._arriving(), m.people.population(), m.people.saved_wave, m.people.lost_wave, m.zombies.alive_count])
	elif test == "shelter":
		_base()
		var houses: Array = g.map.buildings.filter(func(b): return b.kind.begins_with("house") and b.position.distance_to(c) > 35.0)
		houses.sort_custom(func(a, b): return a.position.distance_to(c) > b.position.distance_to(c))
		var h = houses[0]
		h._claimed()
		print("CIV house %s at %.0fm from HQ, cap %d, safe houses %d" % [h.kind, h.position.distance_to(c), m.people.shelter_cap(h), m.people.safe_houses().size()])
		var e: Vector3 = h.entry_point()
		var away: Vector3 = (e - c).normalized()
		m.people.spawn_group(e + away * 8.0, 3)
		await _sim(12.0)
		print("CIV build phase, 12s: sheltered=%d (expect 0)" % m.people.sheltered_in(h))
		m.start_wave()
		m.people.spawn_group(e + away * 8.0, 3)
		await _sim(12.0)
		print("CIV in wave: sheltered=%d visible sheltered=%d" % [m.people.sheltered_in(h), m.people.civilians.filter(func(x): return x.shelter == h and x.visible).size()])
		if OS.get_environment("BREAK") == "1":
			h.take_damage(1.0e9)
			await _sim(1.0)
			print("CIV house destroyed: sheltered=%d running=%d" % [m.people.sheltered_in(h), m.people.civilians.filter(func(x): return not x.dead and x.mode == 0).size()])
			await _sim(30.0)
			print("CIV 30s later: pop=%d arriving=%d lost=%d" % [m.people.population(), m.people.civilians.filter(func(x): return not x.dead and x.mode == 0).size(), m.people.lost_wave])
		else:
			for z in m.zombies.alive_list.duplicate():
				z.vanish()
			m._queue.clear()
			await _sim(2.0)
			print("CIV wave over (phase %s): sheltered=%d heading in=%d" % [m.phase, m.people.sheltered_in(h), m.people.civilians.filter(func(x): return not x.dead and x.mode == 0).size()])
			await _sim(40.0)
			print("CIV 40s later: home=%d still out=%d" % [m.people.civilians.filter(func(x): return not x.dead and x.mode == 1).size(), m.people.civilians.filter(func(x): return not x.dead and x.mode != 1).size()])
	elif test == "block":
		var b = _place("room_block", c + Vector3(-20.0, 0, -6.0))
		print("CIV block slots=%d mounted=%d" % [b.slot_count(), b.mounted.size()])
		b.finish_floor()
		b.finish_floor()
		b.finish_floor()
		print("CIV 4 storeys: slots=%d mounted=%d" % [b.slot_count(), b.mounted.size()])
		for i in b.slot_count():
			m.buildings.mount(b, i, "turret", false, true)
		for i in b.slot_count():
			var gun = b.mounted[i]
			print("CIV slot %d: %s at %s yaw %.0f" % [i, gun.kind if gun else "none", str(b.slot_xform(i).origin.snapped(Vector3(0.01, 0.01, 0.01))), rad_to_deg(b.slot_xform(i).basis.get_euler().y)])
		var moved = _place("room_block", c + Vector3(-20.0, 0, 14.0))
		moved._take_over(b)
		var guns := 0
		for x in moved.mounted:
			if x != null and is_instance_valid(x):
				guns += 1
		print("CIV after move: storeys=%d slots=%d guns kept=%d" % [moved.storeys, moved.slot_count(), guns])
		m.cam.focus(moved.position, 22.0)
		m.cam.snap()
		for i in 10:
			await process_frame
		if OS.get_environment("SHOT") != "":
			await m._shot(OS.get_environment("SHOT"))
	quit()
