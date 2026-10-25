extends SceneTree
# Same walled base and wave, with and without a decoy out in front: where do
# the zombies go? Prints how much damage the walls and the decoy took.
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
	m.wave = 4
	m.supplies = 9999
	var c: Vector3 = Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in m.START_RING:
		ring.append(c + q * 1.3)
	m.walls.build_ring("concrete", ring)
	var decoy = null
	if OS.get_environment("DECOY") == "1":
		decoy = m.buildings.place_built("decoy", Defs.world_to_cell(c + Vector3(0, 0, -34)))
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()
	m._edges = [0]
	m.phase = "build"
	m.start_wave()
	var wall_hp0 := 0.0
	for s in m.walls.live():
		wall_hp0 += s.hp
	var near_decoy := 0
	for t in 60 * 30:
		m.sim_step(1.0 / 30.0)
		if t % 30 == 0 and decoy:
			near_decoy = maxi(near_decoy, m.zombies.count_near(decoy.position, 4.0))
		if t % 60 == 0:
			await process_frame
	var wall_dmg := 0.0
	for s in m.walls.live():
		wall_dmg += s.max_hp - s.hp
	wall_dmg += float(m.walls.rubble.size()) * 3200.0
	print("DECOY=%s after 60s: alive=%d  most near decoy=%d  decoy hp=%s  wall damage=%.0f" % [OS.get_environment("DECOY"), m.zombies.alive_count, near_decoy,
		("%.0f/%.0f" % [decoy.hp, decoy.max_hp]) if decoy and is_instance_valid(decoy) and decoy.state == 1 else ("destroyed" if decoy else "-"), wall_dmg])
	quit()
