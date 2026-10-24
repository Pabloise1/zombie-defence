extends SceneTree
# Plays a layout through waves with the real economy and reports, per wave:
# rounds fired (in crate-equivalents), crates fed/crafted, income, HQ hp.
# LAYOUT=square  : concrete ring + 3 MG + 1 mortar (the "square base")
# LAYOUT=mixed   : same ring + workshop/crafters + depot + wire/mines outside
var started := false
var m = null
var g = null
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false

func _guns() -> Array:
	return m.buildings.guns()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	g = root.get_node("G")
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	var layout := OS.get_environment("LAYOUT")
	var waves := int(OS.get_environment("WAVES")) if OS.get_environment("WAVES") != "" else 12
	var c: Vector3 = Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in m.START_RING:
		ring.append(c + q * 1.4)
	m.walls.build_ring("concrete", ring)
	var H: Vector2i = Defs.HQ_ORIGIN
	m.buildings.place_built("turret", H + Vector2i(-4, -4))
	m.buildings.place_built("turret", H + Vector2i(5, -4))
	m.buildings.place_built("turret", H + Vector2i(5, 5))
	m.buildings.place_built("mortar", H + Vector2i(-4, 5))
	for i in 8:
		m.people.spawn_civilian(c + Vector3(-3 + i, 0, 5), true)
	for i in 3:
		m.people.add_job("soldier")
	for i in 2:
		m.people.add_job("loader")
	if layout == "mixed":
		for spot in [Vector3(-8.0, 0, -9.0), Vector3(-9.0, 0, 0.0), Vector3(0.0, 0, -10.0), Vector3(-6, 0, 9)]:
			var why: String = m.buildings.check_rect("workshop", c + spot, 0.0, null, [])
			print("AUDIT workshop at ", spot, ": ", why if why != "" else "ok")
			if why == "":
				m.buildings.place_rect("workshop", c + spot, 0.0, true)
				break
		for spot in [Vector3(8.0, 0, -9.0), Vector3(9.0, 0, 0.0), Vector3(6, 0, 9)]:
			var why2: String = m.buildings.check_rect("depot", c + spot, 0.0, null, [])
			print("AUDIT depot at ", spot, ": ", why2 if why2 != "" else "ok")
			if why2 == "":
				m.buildings.place_rect("depot", c + spot, 0.0, true)
				break
		for i in 2:
			m.people.add_job("crafter")
		for k in 8:
			var a := TAU * k / 8.0
			m.buildings.place_built("mine", Defs.world_to_cell(c + Vector3(cos(a), 0, sin(a)) * 24.0))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()
	m.supplies = 600
	var dt := 1.0 / 30.0
	for i in 300:
		m.sim_step(dt)
	print("AUDIT layout=%s hq_zone=%d supplies=%d workshops=%d crafters=%d cap=%d" % [layout, m.people.hq_zone(), m.supplies, m.buildings.count_built("workshop"), m.people.crafters.size(), m.logi.capacity_total()])
	for w in waves:
		m.phase = "build"
		m.phase_t = 0.01
		var s0: int = m.supplies
		var r0: int = m.repair_spent if "repair_spent" in m else 0
		var crafted0: int = m.logi.crafted
		var fed0: int = m.logi.zone_fed if "zone_fed" in m.logi else 0
		var used := {}
		var last := {}
		for gun in _guns():
			last[gun] = gun.mag + gun.reserve
		m.sim_step(dt)
		var steps := 0
		while m.phase == "wave" and steps < 30 * 600:
			m.sim_step(dt)
			steps += 1
			for gun in _guns():
				var now: int = gun.mag + gun.reserve
				var was: int = last.get(gun, now)
				if now < was:
					used[gun.kind] = float(used.get(gun.kind, 0.0)) + float(was - now) / float(gun.mag_size + gun.reserve_max)
				last[gun] = now
			# the original rules never drain reserve in a zone: count mag use too
			if steps % 30 == 0:
				await process_frame
		var hq = m.buildings.hq
		var dry := 0
		for gun in _guns():
			if gun.out_of_ammo():
				dry += 1
		var u := ""
		for k in used:
			u += " %s=%.1f" % [k, used[k]]
		print("AUDIT wave %d %s: %.0fs, crates-worth fired:%s | fed %d crafted %d store %d | income %+d -> %d | repairs %d | hq %.0f%% dry %d" % [m.wave - (0 if m.phase == "over" else 1),
			"LOST" if m.phase == "over" else "ok", steps / 30.0, u, (m.logi.zone_fed if "zone_fed" in m.logi else 0) - fed0,
			m.logi.crafted - crafted0, m.logi.crates_total(), m.supplies - s0, m.supplies, (m.repair_spent if "repair_spent" in m else 0) - r0, 100.0 * hq.hp / hq.max_hp if hq else 0.0, dry])
		if m.phase == "over":
			break
		for i in 30 * 20:
			m.sim_step(dt)
	quit()
