extends SceneTree
# Loads the suburb map, builds the showcase fortress, renders a few frames
# and prints GPU memory use (needs a real renderer, e.g. under xvfb-run).
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false

func _run() -> void:
	root.get_node("G").map_id = "suburb"
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	m.hud.show_title(false)
	m.phase = "build"
	m.wave = 9
	m.build_fortress()
	for i in 20:
		await process_frame
	print("TEXMEM textures %.0f MB  video total %.0f MB  static RAM %.0f MB" % [
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	if OS.get_environment("SHOT") != "":
		m.cam.focus(Defs.hq_center() + Vector3(-6, 0, -4), float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 30.0)
		m.cam.snap()
		for i in 10:
			await process_frame
		await m._shot(OS.get_environment("SHOT"))
	quit()
