extends SceneTree
# Two guns of one kind (GUN=turret|cannon) against the same crowd with
# brutes, walking at them from 30 m. Prints kills and damage done.
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false
func _run() -> void:
	seed(7)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	m.wave = 7
	m.zombies.wave = 7
	var kind := OS.get_environment("GUN")
	var c: Vector3 = Defs.hq_center()
	var guns := []
	for dx in [-3, 3]:
		guns.append(m.buildings.place_built(kind, Defs.HQ_ORIGIN + Vector2i(dx, -4)))
	m.flow.compute_now()
	var hp0 := 0.0
	for i in 40:
		var z = m.zombies.spawn(2 if i % 10 == 0 else 0, c + Vector3(-10 + (i % 10) * 2.0, 0, -30 - (i / 10) * 2.0))
		hp0 += z.max_hp
	var secs := 45 if OS.get_environment("SHOT") == "" else 6
	for t in 30 * secs:
		m.sim_step(1.0 / 30.0)
		if t % 120 == 0:
			await process_frame
	var left := 0.0
	var brutes := 0
	for z in m.zombies.alive_list:
		left += z.hp
		if z.kind == 2:
			brutes += 1
	var alive_guns := guns.filter(func(x): return is_instance_valid(x) and x.state == 1)
	print("GUN %-7s 2 guns, 45s: kills=%d/40  brutes left=%d/4  damage done=%.0f of %.0f  guns standing=%d/2" % [kind, m.zombies.kills, brutes, hp0 - left, hp0, alive_guns.size()])
	if OS.get_environment("SHOT") != "":
		m.cam.focus(Defs.hq_center() + Vector3(0, 0, -8), 9.0)
		m.cam.snap()
		for i in 10:
			await process_frame
		await m._shot(OS.get_environment("SHOT"))
	quit()
