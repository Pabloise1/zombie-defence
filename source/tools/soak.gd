extends SceneTree
# Plays waves headless with a pre-built fortress and an unkillable HQ,
# printing object/node/memory counts after each wave to catch leaks.
var started := false
var m = null
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false

func _stat(tag: String) -> void:
	var z = m.zombies
	print("%s wave=%d objs=%d nodes=%d orphans=%d mem=%.1fMB zpool=%d rubble=%d buildings=%d sim=%.0fs" % [tag, m.wave,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		z.all.size(), m.walls.rubble.size() if "rubble" in m.walls else -1, m.buildings.list.size(), root.get_node("G").sim_time])

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.supplies = 99999
	var waves := int(OS.get_environment("WAVES")) if OS.get_environment("WAVES") != "" else 10
	m.build_fortress()
	var dt := 1.0 / 30.0
	for i in 300:
		m.sim_step(dt)
	_stat("start")
	for w in waves:
		m.phase = "build"
		m.start_wave()
		var steps := 0
		var t0 := Time.get_ticks_msec()
		while m.phase == "wave" and steps < 30 * 600:
			var hq = m.buildings.hq
			if hq:
				hq.hp = hq.max_hp
			m.sim_step(dt)
			steps += 1
			if steps % 30 == 0:
				await process_frame
		_stat("cleared(%.1fs real, %d steps)" % [(Time.get_ticks_msec() - t0) / 1000.0, steps])
		for i in 90:
			m.sim_step(dt)
	quit()
