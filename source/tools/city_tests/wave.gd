extends SceneTree
# Map smoke test: map facts, flow reachability from the street ends, then a
# wave with an unkillable HQ. Tracks every zombie life: where it spawned,
# whether it got near the HQ, whether it vanished (lost) or got stuck.
# WAVE=n (default 1)  SECS=n (default 120)
var started := false
var killed := {}
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
	var g = root.get_node("G")
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	var map = g.map
	var id: String = g.map_id
	var half: float = g.grid.NW * 0.5
	print("MAP %s map_node=%s" % [id, map.get_class() if map else "none"])
	if map:
		print("MAP %s towers=%d sealed_cells=%d map_buildings=%d wrecks+heaps=%d survivor_points=%d entries=%s" % [id,
			(map.layout.get("towers", []) as Array).size(), map.get("sealed") if map.get("sealed") != null else -1,
			map.buildings.size(), map.wrecks.size(), map.survivor_points().size(), str(map.entries)])
	print("MAP %s people.ruins=%d logi.salvage=%d wave_mult=%.2f" % [id, m.people.ruins.size(), g.logi.salvage.size(), float(map.layout.get("wave_mult", 1.0)) if map else 1.0])
	# Flow reachability of every open border cell, and of the survivor points.
	var nw: int = g.grid.NW
	var open_border := 0
	var unreach := 0
	for k in nw:
		for c in [Vector2i(k, 0), Vector2i(k, nw - 1), Vector2i(0, k), Vector2i(nw - 1, k)]:
			var i: int = c.y * nw + c.x
			if g.grid.nblk[i] == 0:
				open_border += 1
				if g.flow.dist[i] >= 1.0e19:
					unreach += 1
	var sp_bad := 0
	for p in m.people.ruins:
		var n := Vector2i(floori(p.x + half), floori(p.z + half))
		if g.flow.dist[n.y * nw + n.x] >= 1.0e19:
			sp_bad += 1
	var open_cells := 0
	var unreach_open := 0
	for i in g.grid.nblk.size():
		if g.grid.nblk[i] == 0:
			open_cells += 1
			if g.flow.dist[i] >= 1.0e19:
				unreach_open += 1
	print("FLOW %s open_border_cells=%d unreachable=%d | open cells=%d unreachable=%d | survivor pts unreachable=%d | zones=%d zone_cells=%d" % [id, open_border, unreach, open_cells, unreach_open, sp_bad, m.zones.zone_count, m.zones.zone_cells])
	var hq = m.buildings.hq
	hq.max_hp = 1.0e9
	hq.hp = 1.0e9
	m.zombies.killed.connect(func(z): killed[z] = true)
	var w := int(OS.get_environment("WAVE")) if OS.get_environment("WAVE") != "" else 1
	m.wave = w
	m._plan_edges()
	m.phase = "build"
	m.start_wave()
	print("WAVE %s wave=%d size=%d edges=%s" % [id, w, m.wave_size(w), str(m._edges)])
	var lives := {}
	var ended: Array = []
	var secs := int(OS.get_environment("SECS")) if OS.get_environment("SECS") != "" else 120
	var c0: Vector3 = m.buildings.hq.position
	for t in secs * 30:
		m.sim_step(1.0 / 30.0)
		for z in lives.keys():
			if not z.alive:
				var rec: Dictionary = lives[z]
				rec["vanished"] = not killed.has(z)
				ended.append(rec)
				lives.erase(z)
				killed.erase(z)
		for z in m.zombies.alive_list:
			if not z.alive:
				continue
			if not lives.has(z):
				lives[z] = {"spawn": z.position, "t0": t / 30.0, "min_d": 1.0e9, "last_p": z.position, "still": 0.0, "reach_t": -1.0}
			var rec2: Dictionary = lives[z]
			var d := Vector2(z.position.x - c0.x, z.position.z - c0.z).length()
			if d < rec2["min_d"]:
				rec2["min_d"] = d
			if d < 16.0 and rec2["reach_t"] < 0.0:
				rec2["reach_t"] = t / 30.0 - rec2["t0"]
			if z.position.distance_to(rec2["last_p"]) > 0.03:
				rec2["still"] = 0.0
				rec2["last_p"] = z.position
			else:
				rec2["still"] += 1.0 / 30.0
		if t % 300 == 0:
			await process_frame
		if (t + 1) % (30 * 30) == 0:
			var near := 0
			for z in lives:
				if lives[z]["min_d"] < 16.0:
					near += 1
			print("T+%ds alive=%d tracked=%d near_hq_ever=%d ended=%d queue=%d" % [(t + 1) / 30, m.zombies.alive_count, lives.size(), near, ended.size(), m._queue.size()])
	var all: Array = ended.duplicate()
	for z in lives:
		all.append(lives[z])
	var spawned := all.size()
	var reached := 0
	var vanished := 0
	var stuck := 0
	var bad_spawn := 0
	var reach_ts: Array = []
	var streets := [-76.0, -46.0, 0.0, 46.0, 76.0]
	var spawn_xs := {}
	for rec in all:
		if rec["min_d"] < 16.0:
			reached += 1
			reach_ts.append(rec["reach_t"])
		if rec.get("vanished", false):
			vanished += 1
		if lives.values().has(rec) and rec["still"] > 10.0 and rec["min_d"] >= 16.0:
			stuck += 1
		var p: Vector3 = rec["spawn"]
		var along: float = p.x if absf(p.z) > absf(p.x) else p.z
		var key := int(round(along))
		spawn_xs[key] = spawn_xs.get(key, 0) + 1
		if id == "city":
			var best := 1.0e9
			for s in streets:
				best = minf(best, absf(along - s))
			if best > 9.0:
				bad_spawn += 1
				print("OFFSTREET spawn at (%.1f, %.1f) t0=%.1f" % [p.x, p.z, rec["t0"]])
	reach_ts.sort()
	var med: float = reach_ts[reach_ts.size() / 2] if not reach_ts.is_empty() else -1.0
	print("RESULT %s spawned=%d reached_hq_area=%d vanished=%d stuck_far=%d spawned_off_street=%d median_time_to_hq=%.1fs" % [id, spawned, reached, vanished, stuck, bad_spawn, med])
	var far: Array = []
	for z in lives:
		var rec3: Dictionary = lives[z]
		if rec3["min_d"] >= 16.0:
			far.append("(%.0f,%.0f d=%.0f still=%.0fs)" % [z.position.x, z.position.z, rec3["min_d"], rec3["still"]])
	print("FAR %s %s" % [id, " ".join(far.slice(0, 12))])
	quit()
