extends SceneTree
# City: wall only the street mouths and alleys round the plaza and check the
# plaza becomes a safe zone (towers close it off), and what the player-facing
# wall check says about those segments.
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
	var segs := [
		[Vector3(-6.6, 0, -24), Vector3(6.6, 0, -24)], [Vector3(-6.6, 0, 24), Vector3(6.6, 0, 24)],
		[Vector3(27, 0, -6.6), Vector3(27, 0, 6.6)], [Vector3(-27, 0, -6.6), Vector3(-27, 0, 6.6)],
		[Vector3(19.4, 0, -24), Vector3(22.6, 0, -24)], [Vector3(-22.6, 0, 24), Vector3(-19.4, 0, 24)],
		[Vector3(-27, 0, -16.6), Vector3(-27, 0, -13.4)],
	]
	var n_open := int(OS.get_environment("OPEN")) if OS.get_environment("OPEN") != "" else 0
	for i in segs.size():
		var s: Array = segs[i]
		print("CHECK seg %d: '%s'" % [i, m.walls.check_segment(s[0], s[1])])
		if i >= n_open:
			m.walls.lay("wall", s[0], s[1], 0, true)
	m.walls.refresh_posts()
	var cell := func(x: float, z: float) -> Vector2i: return Vector2i(floori((x + 97.0) / 2.0), floori((z + 97.0) / 2.0))
	print("BUILDCHECK turret on tower: '%s' | turret on lawn: '%s' | dig on road: '%s' | dig on lawn: '%s' | wall into tower: '%s'" % [
		m.buildings.check("turret", cell.call(12, -30)), m.buildings.check("turret", cell.call(14, 8)),
		m.buildings.check("dig", cell.call(-1, -68)), m.buildings.check("dig", cell.call(-10, 8)),
		m.walls.check_segment(Vector3(10, 0, -18), Vector3(10, 0, -30))])
	m.zones.compute_now()
	print("ZONE walls=%d open_gaps=%d zone_count=%d zone_cells=%d plaza_zone=%d hq_zone=%d" % [m.walls.live().size(), n_open, m.zones.zone_count, m.zones.zone_cells,
		m.zones.zone_at(Vector3(10, 0, 10)), m.people.hq_zone()])
	quit()
