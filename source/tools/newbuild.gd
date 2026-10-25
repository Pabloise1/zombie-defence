extends SceneTree
# Places every new building and decor piece near the HQ and takes a shot.
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
	var placed := []
	for spec in [["car_wreck", Vector3(-12, 0, -4), 0.3], ["van_wreck", Vector3(-12, 0, 4), -0.2], ["bus_wreck", Vector3(12, 0, 0), 0.0],
			["greenhouse", Vector3(-4, 0, -10), 0.0], ["clinic", Vector3(5, 0, -10), 0.0]]:
		var b = m.buildings.place_rect(spec[0], c + spec[1], spec[2], true)
		placed.append("%s:%s" % [spec[0], "ok" if b else m.buildings.check_rect(spec[0], c + spec[1], spec[2], null, [])])
	for spec in [["decoy", Vector3(-6, 0, 9)], ["lamp", Vector3(-2, 0, 8)], ["bench", Vector3(0, 0, 8)], ["tree", Vector3(3, 0, 10)],
			["bush", Vector3(6, 0, 8)], ["swings", Vector3(-9, 0, 12)], ["trampoline", Vector3(9, 0, 12)]]:
		var b2 = m.buildings.place_built(spec[0], Defs.world_to_cell(c + spec[1]))
		placed.append("%s:%s" % [spec[0], "ok" if b2 else m.buildings.check(spec[0], Defs.world_to_cell(c + spec[1]))])
	print("NEW ", " ".join(placed))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.cam.focus(c + Vector3(0, 0, 1), 34.0)
	m.cam.snap()
	for i in 10:
		await process_frame
	if OS.get_environment("SHOT") != "":
		await m._shot(OS.get_environment("SHOT"))
	for tab in ["supply", "build"]:
		if OS.get_environment("SHEET") != "":
			m.hud._sheet_open = true
			m.hud.set_tab(tab)
			for i in 30:
				await process_frame
			await m._shot(OS.get_environment("SHEET") + "_" + tab + ".png")
	quit()
