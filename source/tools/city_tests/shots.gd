extends SceneTree
# SHOTS="x,z,dist,yaw,name;..." OUT=dir TAG=prefix
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
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	for i in 20:
		m.sim_step(1.0 / 30.0)
		await process_frame
	var out := OS.get_environment("OUT")
	var tag := OS.get_environment("TAG")
	for s in OS.get_environment("SHOTS").split(";"):
		var p := s.split(",")
		m.cam._t_yaw = deg_to_rad(float(p[3]))
		m.cam.focus(Vector3(float(p[0]), 0, float(p[1])), float(p[2]))
		m.cam.snap()
		for i in 8:
			m.sim_step(1.0 / 30.0)
			await process_frame
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var ob := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("DRAW %s %s calls=%d objects=%d prims=%d" % [tag, p[4], dc, ob, pr])
		await m._shot(out + "/" + tag + "_" + p[4] + ".png")
	quit()
