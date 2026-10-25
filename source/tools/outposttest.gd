extends SceneTree
# Outpost check: walled HQ, an outpost by the scrap site nearest the north
# edge, a wave from the north. Where does the horde go, and what does the
# outpost pay when the wave is cleared?
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false
func _run() -> void:
	seed(5)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	var g = root.get_node("G")
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	m.wave = 3
	m.supplies = 5000
	var c: Vector3 = Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in m.START_RING:
		ring.append(c + q * 1.3)
	m.walls.build_ring("concrete", ring)
	var site = null
	for s in g.logi.salvage:
		if site == null or s.position.z < site.position.z:
			site = s
	var post = null
	for r in range(3, 14):
		for k in 12:
			var p: Vector3 = site.position + Vector3(cos(k * 0.52), 0, sin(k * 0.52)) * r
			if post == null and m.buildings.check_rect("outpost", p, 0.0, null, []) == "":
				post = m.buildings.place_rect("outpost", p, 0.0, true)
	var far_check: String = m.buildings.check_rect("outpost", c + Vector3(0, 0, 20), 0.0, null, [])
	print("OUT site at %s (%d scrap); outpost placed=%s at %.0fm from HQ; placing away from sites says '%s'" % [str(site.position.snapped(Vector3.ONE)), site.scrap, post != null, post.position.distance_to(c) if post else -1.0, far_check])
	if OS.get_environment("DEFEND") == "1" and post:
		var pr: Array[Vector3] = []
		for k in 8:
			pr.append(post.position + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * 7.5)
		m.walls.build_ring("concrete", pr)
		for off in [Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, -4.5)]:
			m.buildings.place_built("turret", Defs.world_to_cell(post.position + off))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()
	m._edges = [0]
	var s_before: int = m.supplies
	var scrap0: int = site.scrap
	m.start_wave()
	var hit_post := 0.0
	var wall_hp0 := 0.0
	for s in m.walls.live():
		wall_hp0 += s.hp
	var t := 0
	while m.phase == "wave" and t < 30 * 240:
		m.sim_step(1.0 / 30.0)
		t += 1
		if post != null and is_instance_valid(post) and post.state == 1:
			hit_post = post.max_hp - post.hp
		if t % 120 == 0:
			await process_frame
	var wall_now := 0.0
	for s in m.walls.live():
		wall_now += s.hp
	print("OUT income this wave %+d (wave bonus %d), site scrap %d -> %d" % [m.supplies - s_before, m.wave_bonus(), scrap0, site.scrap])
	print("OUT wave over=%s after %.0fs: outpost %s (damage %.0f), HQ walls damage=%.0f" % [m.phase != "wave", t / 30.0,
		"standing" if post != null and is_instance_valid(post) and post.state == 1 else "DESTROYED", hit_post, wall_hp0 - wall_now])
	quit()
