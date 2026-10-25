extends SceneTree
# Module fort scenario: ring of fort modules round the HQ, raise it with
# workers, guns and soldiers, a wave against it, then a save round trip.
var started := false
var m = null
var g = null
var SG = null
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false

func _mods() -> Array:
	return m.buildings.list.filter(func(b): return is_instance_valid(b) and b.kind.begins_with("fort_") and b.state != 2)

func _levels() -> Dictionary:
	var d := {}
	for b in _mods():
		d[b.levels] = int(d.get(b.levels, 0)) + 1
	return d

func _run() -> void:
	g = root.get_node("G")
	SG = load("res://scripts/save_game.gd")
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	m.wave = 4
	m.zombies.wave = 4
	m.supplies = 20000
	var o: Vector2i = Defs.HQ_ORIGIN
	var placed := 0
	var failed := []
	for y in range(o.y - 5, o.y + 8):
		for x in range(o.x - 5, o.x + 8):
			var edge := x == o.x - 5 or x == o.x + 7 or y == o.y - 5 or y == o.y + 7
			if not edge:
				continue
			var k := "fort_concrete" if x == o.x + 7 else "fort_wood"
			if m.buildings.place_built(k, Vector2i(x, y)):
				placed += 1
			else:
				failed.append("%s" % [m.buildings.check(k, Vector2i(x, y))])
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()
	print("FORT placed=%d failed=%s hq_zone=%d" % [placed, str(failed), m.people.hq_zone()])
	var corner = null
	for b in _mods():
		if b.cell == Vector2i(o.x - 5, o.y - 5):
			corner = b
	var s0: int = m.supplies
	var why: String = corner.raise_group()
	print("FORT raise all: '%s' cost=%d jobs=%d" % [why, s0 - m.supplies, g.workers.pending_count()])
	for i in 6:
		m.people.add_job("worker")
	var t := 0
	while g.workers.pending_count() > 0 and t < 30 * 600:
		m.sim_step(1.0 / 30.0)
		t += 1
		if t % 120 == 0:
			await process_frame
	print("FORT after %.0fs of work: levels=%s" % [t / 30.0, str(_levels())])
	var n := 0
	for b in _mods():
		if b.cell.x in [o.x - 5, o.x + 7] and b.cell.y in [o.y - 5, o.y + 7]:
			m.buildings.mount(b, 0, "turret", false, true)
			n += 1
	for i in 6:
		m.people.spawn_civilian(Defs.hq_center() + Vector3(0, 0, 4), true)
	for i in 4:
		m.people.add_job("soldier")
	var posted := 0
	for s in g.soldiers.idle_soldiers():
		var mm = _mods()[posted * 7]
		if s.assign(mm):
			posted += 1
	for i in 300:
		m.sim_step(1.0 / 30.0)
	var occ := 0
	for b in _mods():
		occ += b.occupants.size()
	print("FORT guns=%d soldiers posted=%d inside=%d corner range=%.1f slot_bonus=%.2f ports=%d cap=%d" % [n, posted, occ, corner.mounted[0].gun_range() if corner.mounted[0] else 0.0, corner.slot_bonus(), corner.port_points().size(), corner.capacity()])
	m.zones.compute_now()
	m.buildings.refresh_zones()
	m.flow.compute_now()
	m._edges = [0, 1]
	m.start_wave()
	for i in 30 * 90:
		m.sim_step(1.0 / 30.0)
		if i % 120 == 0:
			await process_frame
	var dmg := 0.0
	var dead := 0
	for b in m.buildings.list:
		if is_instance_valid(b) and b.kind.begins_with("fort_"):
			if b.state == 2:
				dead += 1
			else:
				dmg += b.max_hp - b.hp
	print("FORT after 90s of wave 4: kills=%d alive=%d module damage=%.0f destroyed=%d hq=%.0f%%" % [m.zombies.kills, m.zombies.alive_count, dmg, dead, 100.0 * m.buildings.hq.hp / m.buildings.hq.max_hp])
	for z in m.zombies.alive_list.duplicate():
		z.vanish()
	m._queue.clear()
	if OS.get_environment("SHOT") != "":
		m.cam.focus(Defs.hq_center() + Vector3(0, 0, 2), 40.0)
		m.cam.snap()
		for i in 10:
			await process_frame
		await m._shot(OS.get_environment("SHOT"))
	var before := _levels()
	m.phase = "build"
	SG.write(m)
	g.resume = SG.read()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	m = current_scene
	print("FORT reload: levels before=%s after=%s hq_zone=%d guns=%d" % [str(before), str(_levels()), m.people.hq_zone(), m.buildings.mounted_guns().size()])
	SG.clear()
	quit()
