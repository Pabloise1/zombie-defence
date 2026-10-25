extends SceneTree
# Places the new fortress pieces and buildings, mounts guns, posts soldiers,
# checks the effects, and takes a shot.
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false
func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 999.0
	m.wave = 6
	m.supplies = 9999
	var c: Vector3 = Defs.hq_center()
	var out := []
	var made := {}
	for spec in [["water_tower", Vector3(-9, 0, -6), 0.0], ["container", Vector3(9, 0, -7), 0.0], ["container", Vector3(9, 0, -3.5), 0.0],
			["pillbox", Vector3(-9, 0, 6), 0.0], ["armory", Vector3(0, 0, -11), 0.0], ["scrapyard", Vector3(9, 0, 7), 0.0]]:
		var b = m.buildings.place_rect(spec[0], c + spec[1], spec[2], true)
		out.append("%s:%s" % [spec[0], "ok" if b else m.buildings.check_rect(spec[0], c + spec[1], spec[2], null, [])])
		if b and not made.has(spec[0]):
			made[spec[0]] = b
	var wt = made.get("water_tower")
	var g1 = m.buildings.mount(wt, 0, "sniper", false, true) if wt else null
	var g2 = m.buildings.mount(made.get("container"), 0, "turret", false, true) if made.has("container") else null
	print("FORT ", " ".join(out))
	print("FORT tower slots=%d sniper range=%.0f (base %.0f)  container turret range=%.0f  pillbox capacity=%d ports=%d" % [wt.slot_count(), g1.gun_range(), Defs.SNIPER_RANGE, g2.gun_range(), made["pillbox"].capacity(), made["pillbox"].port_points().size()])
	print("FORT soldier damage with armory=%.2f" % m.soldiers.damage())
	for i in 5:
		m.people.spawn_civilian(c + Vector3(0, 0, 5), true)
	for i in 3:
		m.people.add_job("soldier")
	for s in m.soldiers.idle_soldiers():
		s.assign(made["pillbox"])
	for i in 400:
		m.sim_step(1.0 / 30.0)
	print("FORT pillbox occupants=%d" % made["pillbox"].occupants.size())
	m.cam.focus(c + Vector3(0, 0, 0), 34.0)
	m.cam.snap()
	for i in 10:
		await process_frame
	if OS.get_environment("SHOT") != "":
		await m._shot(OS.get_environment("SHOT"))
	quit()
