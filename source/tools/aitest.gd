extends SceneTree
# Zombie AI checks. Ring of WALL (wood|concrete) round the HQ, an empty house
# and an MG out to the side, a wave of N zombies from the north. Reports what
# got hit and how many zombies climbed over into the base.
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false
func _run() -> void:
	seed(11)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	var g = root.get_node("G")
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	m.wave = 5
	m.zombies.wave = 5
	var c: Vector3 = Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in m.START_RING:
		ring.append(c + q * 1.3)
	var wk := OS.get_environment("WALL") if OS.get_environment("WALL") != "" else "wall"
	m.walls.build_ring(wk, ring)
	var house = m.buildings.place_rect("house", c + Vector3(30, 0, -6), 0.0, true)
	var mg = m.buildings.place_built("turret", Defs.world_to_cell(c + Vector3(-30, 0, -4)))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 120
	for i in n:
		var z = m.zombies.spawn(0 if i % 8 != 0 else 1, c + Vector3(-16 + (i % 16) * 2.0, 0, -60 - (i / 16) * 2.0))
		z.hp = 100000.0
		z.max_hp = 100000.0
	var vaults := 0
	var first_in := -1.0
	var peak_press := 0
	for t in 30 * 120:
		m.sim_step(1.0 / 30.0)
		for z in m.zombies.alive_list:
			if z.st == 5 and "vault_t" in z and z.vault_t <= 1.0 / 30.0 + 0.0001:
				vaults += 1
				if first_in < 0.0:
					first_in = t / 30.0
		for s in m.walls.segments:
			if is_instance_valid(s):
				peak_press = maxi(peak_press, s.press if "press" in s else 0)
		if t % 120 == 0:
			await process_frame
		if OS.get_environment("SHOT") != "" and t == int(float(OS.get_environment("AT")) * 30.0):
			var best = null
			for s in m.walls.segments:
				if is_instance_valid(s) and (best == null or s.press > best.press):
					best = s
			m.cam.focus(best.position + Vector3(0, 0, 3), 16.0)
			m.cam.snap()
			for i in 12:
				m.sim_step(1.0 / 30.0)
				await process_frame
			await m._shot(OS.get_environment("SHOT"))
			quit()
			return
	var inside := 0
	for z in m.zombies.alive_list:
		if m.zones.zone_at(z.position) > 0:
			inside += 1
	var wall_dmg := 0.0
	for s in m.walls.live():
		wall_dmg += s.max_hp - s.hp
	print("AI %s ring, %d zombies, 120s: house dmg=%.0f  side MG dmg=%.0f  wall dmg=%.0f  walls broken=%d  climbed over=%d (first at %.0fs)  inside now=%d  peak pile=%d (need %d)  hq=%.0f%%" % [
		wk, n, house.max_hp - house.hp if is_instance_valid(house) else -1.0, mg.max_hp - mg.hp if is_instance_valid(mg) else -1.0,
		wall_dmg, m.walls.rubble.size(), vaults, first_in, inside, peak_press, (m.walls.segments[0].call("pile_need") if m.walls.segments[0].has_method("pile_need") else 0), 100.0 * m.buildings.hq.hp / m.buildings.hq.max_hp])
	if OS.get_environment("SHOT") != "":
		quit()
	quit()
