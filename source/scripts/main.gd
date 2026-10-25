extends Node3D
signal wave_started(n: int)
signal wave_cleared(n: int)
const EDGE_NAMES := ["north", "east", "south", "west"]
var grid: Grid
var flow: FlowField
var terrain: Terrain
var decor: Decor
var buildings: BuildingManager
var workers: WorkerManager
var soldiers: SoldierManager
var people: PeopleManager
var logi: Logistics
var walls: WallSystem
var zones: ZoneMap
var zombies: ZombieManager
var fx: Fx
var cam: CameraRig
var builder: BuildController
var hud: Hud
var sfx: Node
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var supplies := Defs.START_SUPPLIES
var wave := 1
var phase := "title"
var phase_t := 0.0
var waves_cleared := 0
var repair_spent := 0
var map_seed := 0
# Player difficulty settings (Settings card), kept in settings.cfg.
const SPEED_CHOICES := [0.75, 1.0, 1.25, 1.5]
const HORDE_CHOICES := [0.5, 0.75, 1.0, 1.5, 2.0]
var zombie_speed := 1.0
var horde_mult := 1.0
var _save_t := 0.0
var test_mode := false
var manual_clock := false
var _queue: Array = []
var _spawn_t := 0.0
var _spawn_gap := 1.0
var _edges: Array = []
var _edge_markers: Array[MeshInstance3D] = []
var quality: QualityManager
var _last_ui_size := Vector2i.ZERO
var _ui_ratio := 0.0
var _straggle_t := 0.0
var _stall_t := 0.0
var _stall_n := -1
var _wave_t := 0.0
var _zones_ready := false
var _amb_t := 0.0
const START_RING := [
	Vector3(-9, 0, -11), Vector3(9, 0, -11), Vector3(12, 0, -6), Vector3(12, 0, 8),
	Vector3(8, 0, 12), Vector3(-8, 0, 12), Vector3(-12, 0, 8), Vector3(-12, 0, -6),
]
const GOAL_TEXT := "Wall in your HQ to make a safe zone"

func _ready() -> void:
	G.reset()
	G.main = self
	_load_game_settings()
	if not G.resume.is_empty():
		G.map_id = String(G.resume["map"])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			G.map_id = a.substr(6)
		elif a.begins_with("--uiscale="):
			_ui_ratio = float(a.substr(10))
	G.rng.randomize()
	_setup_world()
	_plan_edges()
	get_viewport().size_changed.connect(_update_ui_scale)
	_update_ui_scale()
	if test_mode:
		phase = "build"
		phase_t = 9999.0
		hud.show_title(false)
	else:
		phase = "title"
		hud.show_title(true)
		cam.focus(Defs.hq_center() + Vector3(0, 0, 6), 46.0)
		cam.snap()
	if not G.resume.is_empty() and not test_mode:
		var d: Dictionary = G.resume
		G.resume = {}
		_continue(d)
	hud.save_info = SaveGame.summary() if not test_mode else {}
	var args := OS.get_cmdline_user_args()
	for a in args:
		_dev_arg(a)
	for a in args:
		if a.begins_with("--shot="):
			_showcase(a.substr(7))
		elif a.begins_with("--quickshot="):
			_quickshot(a.substr(12))
		elif a.begins_with("--mapshot="):
			_mapshot(a.substr(10))
		elif a.begins_with("--uishots="):
			_uishots(a.substr(10))
		elif a == "--bench":
			_bench(300)
		elif a.begins_with("--bench="):
			_bench(int(a.substr(8)))
		elif a.begins_with("--prof="):
			_profile(int(a.substr(7)))
		elif a.begins_with("--fxshots="):
			_fxshots(a.substr(10))
		elif a.begins_with("--heroshot="):
			_heroshot(a.substr(11))
		elif a.begins_with("--fortshot="):
			_fortshot(a.substr(11))

func _dev_arg(a: String) -> void:
	var e: Environment = world_env.environment
	if not a.contains("="):
		return
	var k := a.get_slice("=", 0)
	var v := a.get_slice("=", 1).to_float()
	match k:
		"--glow":
			e.glow_enabled = v > 0.0
		"--adj":
			e.adjustment_enabled = v > 0.0
		"--sun":
			sun.light_energy = v
		"--amb":
			e.ambient_light_energy = v
		"--fog":
			e.fog_density = v
			e.fog_enabled = v > 0.0
		"--tm":
			e.tonemap_mode = int(v)
		"--exp":
			e.tonemap_exposure = v
		"--white":
			e.tonemap_white = v

func _quickshot(path: String) -> void:
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	supplies = 5000
	wave = 6
	var hq := Defs.HQ_ORIGIN
	buildings.place_built("turret", hq + Vector2i(-3, -2))
	buildings.place_built("turret", hq + Vector2i(4, -2))
	buildings.place_built("mortar", hq + Vector2i(-3, 3))
	var plan := [{"pos": Vector3(-30, 0, -20), "type": "", "seg": null}, {"pos": Vector3(-14, 0, -28), "type": "", "seg": null}, {"pos": Vector3(4, 0, -26), "type": "", "seg": null}]
	walls.add_plan("concrete", plan, false)
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	for i in 12:
		zombies.spawn(Defs.Z_WALKER, Defs.hq_center() + Vector3(-12 + i * 2.0, 0, -34))
	people.spawn_group(Defs.hq_center() + Vector3(20, 0, 20), 4)
	for i in 30:
		sim_step(1.0 / 30.0)
	cam.focus(Defs.hq_center() + Vector3(0, 0, -6), 44.0)
	cam.snap()
	builder.select(buildings.hq)
	for i in 8:
		await get_tree().process_frame
	await _shot(path)
	get_tree().quit()

func _mapshot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	supplies = 5000
	for i in 30:
		sim_step(1.0 / 30.0)
		await get_tree().process_frame
	var spots := [["01_park", Vector3(0, 0, 4), 40.0], ["02_crossroads", Vector3(34, 0, 26), 40.0], ["03_elm", Vector3(-50, 0, -36), 40.0],
		["04_close", Vector3(0, 0, 58), 40.0], ["05_petrol", Vector3(46, 0, 12), 30.0], ["06_wide", Vector3(0, 0, 0), 92.0]]
	var c := Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in START_RING:
		ring.append(c + q * 0.85)
	walls.build_ring("wall", ring)
	walls.build_gate_now(c + Vector3(0, 0, 12.0 * 0.85))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(-3, -2))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(4, -2))
	buildings.place_built("mortar", Defs.HQ_ORIGIN + Vector2i(3, 3))
	for mb in G.map.buildings:
		if mb.kind == "house_bungalow" and mb.position.distance_to(c) < 30.0:
			mb._claimed()
			buildings.mount(mb, 0, "turret", false, true)
	for i in 8:
		people.spawn_civilian(c + Vector3(-3 + i * 0.7, 0, 6), true)
	for i in 3:
		people.add_job("loader")
	people.add_job("fetcher")
	people.add_job("fetcher")
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	for i in 600:
		sim_step(1.0 / 30.0)
	_edges = [0, 3]
	start_wave()
	for i in 1500:
		sim_step(1.0 / 30.0)
		if i % 100 == 0:
			await get_tree().process_frame
	spots.append(["07_hero", Vector3(-12, 0, -12), 62.0])
	for sp in spots:
		cam.focus(sp[1], sp[2])
		cam.snap()
		for i in 8:
			await get_tree().process_frame
		if String(sp[0]) == "07_hero":
			hud.hide_card()
		await _shot(dir + "/" + String(sp[0]) + ".png")
	get_tree().quit()

func _bench(n: int) -> void:
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	var c := Defs.hq_center()
	if OS.get_cmdline_user_args().has("--fort"):
		wave = 9
		zombies.wave = 9
		var f := build_fortress()
		for i in 300:
			sim_step(1.0 / 30.0)
		if f["pad"] and f["pad"].heli:
			f["pad"].heli.start_patrol(c + Vector3(0, 0, -30))
	else:
		var ring: Array[Vector3] = []
		for q in START_RING:
			ring.append(c + q * 1.4)
		walls.build_ring("concrete", ring)
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	for i in n:
		var a := TAU * i / n
		var d := 24.0 + (i % 23) * 3.2
		zombies.spawn(Defs.Z_RUNNER if i % 9 == 0 else Defs.Z_WALKER, c + Vector3(cos(a), 0, sin(a)) * d)
	cam.focus(c + Vector3(0, 0, 4), 46.0)
	cam.snap()
	for i in 60:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var zsum := 0
	var ssum := 0.0
	while frames < 300:
		var s0 := Time.get_ticks_usec()
		await get_tree().process_frame
		ssum += 0.0
		zsum += zombies.step_usec
		frames += 1
	var total := (Time.get_ticks_usec() - t0) / 1000.0
	if OS.get_cmdline_user_args().has("--fortdebug"):
		var counts := {}
		for node in [walls, buildings, G.helis, people, zombies, decor, fx]:
			if node:
				counts[node.name] = node.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.is_visible_in_tree()).size()
		print("BENCH visible meshes by group: ", counts)
	print("BENCH map %s: %d frames, %.2f ms a frame (%.0f fps), %d zombies alive (%d in view), zombie update %.2f ms, draw calls %d" % [
		G.map_id, frames, total / frames, 1000.0 * frames / total, zombies.alive_count, zombies.near_count, zsum / 1000.0 / frames,
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])
	get_tree().quit()

func _profile(n: int) -> void:
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	manual_clock = true
	var c := Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in START_RING:
		ring.append(c + q * 1.4)
	walls.build_ring("concrete", ring)
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(-4, -4))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(5, -4))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(5, 5))
	buildings.place_built("mortar", Defs.HQ_ORIGIN + Vector2i(-4, 5))
	for i in 6:
		people.spawn_civilian(c + Vector3(-3 + i, 0, 5), true)
	for i in 4:
		people.add_job("soldier")
	people.add_job("loader")
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	cam.focus(c, 46.0)
	cam.snap()
	for i in n:
		var a := TAU * i / n
		var d := 24.0 + (i % 23) * 3.2
		var z = zombies.spawn(Defs.Z_RUNNER if i % 9 == 0 else Defs.Z_WALKER, c + Vector3(cos(a), 0, sin(a)) * d)
		z.hp = 100000.0
		z.max_hp = 100000.0
	var parts := {"zones": 0, "flow": 0, "zombies": 0, "walls": 0, "buildings": 0, "workers": 0, "soldiers": 0, "people": 0, "fx": 0}
	var dt := 1.0 / 30.0
	for i in 30:
		sim_step(dt)
	zombies.prof = PackedInt64Array([0, 0, 0, 0, 0])
	var steps := 150
	for i in steps:
		G.sim_time += dt
		var t := Time.get_ticks_usec()
		zones.update(3000)
		var t1 := Time.get_ticks_usec()
		parts["zones"] += t1 - t
		flow.update(3000)
		var t2 := Time.get_ticks_usec()
		parts["flow"] += t2 - t1
		zombies.step(dt)
		var t3 := Time.get_ticks_usec()
		parts["zombies"] += t3 - t2
		walls.step(dt)
		var t4 := Time.get_ticks_usec()
		parts["walls"] += t4 - t3
		buildings.step(dt)
		var t5 := Time.get_ticks_usec()
		parts["buildings"] += t5 - t4
		workers.step(dt)
		var t6 := Time.get_ticks_usec()
		parts["workers"] += t6 - t5
		soldiers.step(dt)
		var t7 := Time.get_ticks_usec()
		parts["soldiers"] += t7 - t6
		people.step(dt)
		var t8 := Time.get_ticks_usec()
		parts["people"] += t8 - t7
		fx.step(dt)
		parts["fx"] += Time.get_ticks_usec() - t8
	var total := 0.0
	var line := ""
	for k in parts:
		var ms: float = parts[k] / 1000.0 / steps
		total += ms
		line += "  %s %.2f" % [k, ms]
	print("PROF %d zombies (%d in view, tiers %s): %.2f ms a step |%s" % [zombies.alive_count, zombies.near_count, str(zombies.tier_counts), total, line])
	var zp := zombies.prof
	print("PROF zombies: buckets %.2f  separation %.2f  danger %.2f  steps %.2f  anims %.2f" % [zp[0] / 1000.0 / steps, zp[1] / 1000.0 / steps, zp[2] / 1000.0 / steps, zp[3] / 1000.0 / steps, zp[4] / 1000.0 / steps])
	get_tree().quit()

func build_fortress() -> Dictionary:
	var c := Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in START_RING:
		ring.append(c + q * 1.2)
	walls.build_ring("fortified", ring)
	walls.build_gate_now(c + Vector3(0, 0, 12.0 * 1.2))
	var e0: Vector3 = c + START_RING[7] * 1.2
	var e3: Vector3 = c + START_RING[5] * 1.2
	var e1 := Vector3(c.x - 40.0, 0, e0.z)
	var e2 := Vector3(c.x - 40.0, 0, e3.z)
	for ab in [[e0, e1], [e1, e2], [e2, e3]]:
		walls.lay("concrete", ab[0], ab[1], 0, true)
	walls.refresh_posts()
	walls.build_gate_now(c + Vector3(-14.4, 0, 1.2))
	var big: Helipad = buildings.place_rect("helipad_large", c + Vector3(-28.0, 0, 2.0), 0.0, true)
	var b1: RoomBlock = buildings.place_rect("room_block", c + Vector3(-7.5, 0, -7.2), 0.0, true)
	var b2: RoomBlock = buildings.place_rect("room_block", c + Vector3(7.5, 0, -7.2), 0.0, true)
	if b1:
		b1.finish_floor()
		b1.finish_floor()
	if b2:
		b2.finish_floor()
	var st: Building = buildings.place_rect("stairs", c + Vector3(-1.6, 0, -11.0), 0.0, true)
	var pad: Helipad = buildings.place_rect("helipad", c + Vector3(8.5, 0, 7.5), 0.0, true)
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	G.net.dirty = true
	var br = null
	if b1 and b2:
		var a1: Dictionary = G.net.anchor_near(b1.position, b2.position)
		var a2: Dictionary = G.net.anchor_near(b2.position, b1.position)
		if not a1.is_empty() and not a2.is_empty():
			br = buildings.place_bridge(a1, a2, true)
	G.net.dirty = true
	for b in [b1, b2]:
		if b:
			for i in b.slot_count():
				buildings.mount(b, i, "turret", false, true)
	buildings.place_built("mortar", Defs.HQ_ORIGIN + Vector2i(-4, 4))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(5, 3))
	var forts: Array = walls.live().filter(func(x): return x.kind == "fortified" and x.state == Building.BUILT)
	var k := 0
	for s in forts:
		if k % 3 == 0 and s.length > 3.0:
			walls.add_nest(s, s.position, "turret")
			var n = buildings.last_placed
			if n and n.state != Building.BUILT:
				n._finish(true)
				for g in n.mounted:
					if g and g.state != Building.BUILT:
						g._finish(true)
		k += 1
	for i in 20:
		people.spawn_civilian(c + Vector3(-5 + i * 0.5, 0, 4), true)
	for i in 8:
		people.add_job("soldier")
	for i in 12:
		people.add_job("loader")
	if big:
		big.heli = G.helis.add_heli("mi8", big)
		big.heli.park_now()
		big.heli.rotor = 0.0
		if G.sfx:
			G.sfx.stop_loop(big.heli)
	if pad:
		pad.heli = G.helis.add_heli("huey", pad)
		pad.heli.park_now()
		pad.heli.rotor = 0.0
		if G.sfx:
			G.sfx.stop_loop(pad.heli)
	for s in forts.slice(0, 4):
		soldiers.assign(s)
	return {"b1": b1, "b2": b2, "pad": pad, "big": big, "bridge": br, "stairs": st}

func _fortshot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	supplies = 4000
	wave = 9
	zombies.wave = 9
	var f := build_fortress()
	var c := Defs.hq_center()
	print("FORT zone at HQ door: %d" % people.hq_zone())
	for i in 1500:
		sim_step(1.0 / 30.0)
	if OS.get_cmdline_user_args().has("--fortdebug"):
		for g in buildings.mounted_guns():
			print("DBG gun %s on %s crew_ok %s loader %s occ %d inc %d" % [g.kind, g.host.kind if g.host else "-", str(g.crew_ok()), str(g.loader), g.occupants.size(), g.incoming.size()])
		for l in people.loaders:
			print("DBG loader mode %d gun %s climbing %s climb %s pos %s path %d/%d air %d/%d vis %s" % [l.mode, str(l.gun), str(l._climbing), str(l._climb.keys()), str(l.position.snapped(Vector3(0.1, 0.1, 0.1))), l.path_i, l.path.size(), l.air_i, l.air_pts.size(), str(l.visible)])
			if l._climbing:
				print("DBG   pts ", l.air_pts)
		for sd in soldiers.soldiers:
			print("DBG soldier mode %d post %s pos %s" % [sd.mode, str(sd.post.kind if sd.post else "-"), str(sd.position.snapped(Vector3(0.1, 0.1, 0.1)))])
	hud._toasts.clear()
	print("FORT zones %d, Mi-8 %s" % [zones.zone_count, str(f["big"] != null and f["big"].heli != null)])
	cam.focus(c + Vector3(-6, 0, 4), 70.0)
	cam.snap()
	for i in 20:
		await get_tree().process_frame
	await _shot(dir + "/fortress_v06.png")
	cam.focus(c + Vector3(0, 0, -6), 24.0)
	cam.snap()
	for i in 20:
		await get_tree().process_frame
	await _shot(dir + "/blocks_bridge_v06.png")
	_edges = [0]
	start_wave()
	for i in 900:
		sim_step(1.0 / 30.0)
		if i % 30 == 0:
			await get_tree().process_frame
	var h = f["pad"].heli if f["pad"] else null
	if h:
		h.cooldown = 0.0
		var why_p: String = h.start_patrol(c + Vector3(0, 0, -34))
		print("FORT patrol: '%s' fly %d" % [why_p, h.fly])
	for i in 700:
		sim_step(1.0 / 30.0)
		if i % 30 == 0:
			await get_tree().process_frame
		if h and h.fly == Heli.ORBIT and i > 400:
			break
	hud._banners.clear()
	hud._banner_age = -1.0
	hud.banner.visible = false
	hud._toasts.clear()
	if h:
		print("FORT heli fly %d at %s" % [h.fly, str(h.position)])
		var vp: float = cam.pitch_for(38.0)
		cam.focus(Vector3(h.position.x, 0, h.position.z - h.position.y / tan(vp) + 3.0), 38.0)
		cam.snap()
	for i in 6:
		sim_step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot(dir + "/heli_patrol_v06.png")
	if OS.get_cmdline_user_args().has("--fortdebug") and h:
		cam.focus(Vector3(h.position.x, 0, h.position.z), 16.0)
		cam.snap()
		print("FORT heli model vis %s xf %s" % [str(h.model.is_visible_in_tree()), str(h.global_transform)])
		for mi in Art.mesh_instances(h.model):
			print("FORT  mesh %s vis %s transp %.2f" % [mi.name, str(mi.is_visible_in_tree()), mi.transparency])
		for i in 4:
			await get_tree().process_frame
		await _shot(dir + "/heli_debug.png")
	get_tree().quit()

func _heroshot(path: String) -> void:
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	supplies = 3000
	var c := Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in START_RING:
		ring.append(c + q * 1.05)
	walls.build_ring("wall", ring)
	walls.build_gate_now(c + Vector3(0, 0, 12.0 * 1.05))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(-4, -3))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(5, -3))
	buildings.place_built("mortar", Defs.HQ_ORIGIN + Vector2i(4, 4))
	for mb in G.map.buildings:
		if mb.kind == "house_bungalow" and mb.position.distance_to(c) < 30.0:
			mb._claimed()
			buildings.mount(mb, 0, "turret", false, true)
	for i in 10:
		people.spawn_civilian(c + Vector3(-3 + i * 0.7, 0, 6), true)
	for i in 4:
		people.add_job("soldier")
	people.add_job("loader")
	people.add_job("loader")
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	for i in 300:
		sim_step(1.0 / 30.0)
	wave = 4
	zombies.wave = 4
	_edges = [0]
	start_wave()
	for i in 2050:
		sim_step(1.0 / 30.0)
		if i % 20 == 0:
			await get_tree().process_frame
	hud._banners.clear()
	hud._banner_age = -1.0
	hud.banner.visible = false
	hud._toasts.clear()
	cam.focus(c + Vector3(0, 0, -14), 50.0)
	cam.snap()
	for i in 12:
		sim_step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot(path)
	print("HERO %d zombies alive" % zombies.alive_count)
	get_tree().quit()

func _fxshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	supplies = 9000
	walls.auto_rebuild = false
	var c := Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in START_RING:
		ring.append(c + q)
	walls.build_ring("wall", ring)
	walls.build_gate_now(c + Vector3(0, 0, 12.0))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(-3, -3))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(5, -3))
	for i in 3:
		people.add_job("soldier")
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	for i in 120:
		sim_step(1.0 / 30.0)
	for i in 40:
		var z = zombies.spawn(Defs.Z_WALKER if i % 8 else Defs.Z_RUNNER, c + Vector3(randf_range(-8, 8), 0, -24 - randf_range(0, 8)))
		z.hp = 4000.0
		z.max_hp = 4000.0
	for i in 300:
		sim_step(1.0 / 30.0)
	zombies.damage_radius(c + Vector3(-3, 0, -14), 2.5, 6000.0)
	fx.explosion(c + Vector3(-3, 0.2, -14), 0.8)
	fx.fire_patch(c + Vector3(5, 0, -15), 1.8, 30.0)
	for i in 8:
		sim_step(1.0 / 30.0)
	cam.focus(c + Vector3(0, 0, -11), 24.0)
	cam.snap()
	for i in 20:
		await get_tree().process_frame
	await _shot(dir + "/fx_wall_fight.png")
	zombies.clear_all()
	var segs := walls.live().filter(func(x): return x.kind == "wall" and x.state == Building.BUILT)
	segs.sort_custom(func(a, b): return a.position.x < b.position.x)
	var west: Array = segs.filter(func(x): return x.position.x < c.x - 9.0)
	if west.size() >= 3:
		west[0].take_damage(west[0].max_hp * 0.62)
		west[1].take_damage(west[1].max_hp * 0.85)
		west[2].take_damage(1000000000.0)
	var bp := Defs.HQ_ORIGIN + Vector2i(-4, 3)
	buildings.place("turret", bp)
	var tb = grid.occ[grid.idx(bp)]
	if tb:
		tb.progress = 0.5
		tb.build_look()
	var hs: Building = buildings.place_rect("house", c + Vector3(-22, 0, 4), 0.0, false)
	if hs:
		hs.progress = 0.45
		hs.build_look()
	var nw: Array = walls.lay("concrete", c + Vector3(-26, 0, -6), c + Vector3(-26, 0, 10), 0, false)
	for x in nw:
		x.progress = 0.4
		x.build_look()
	for w in workers.workers:
		w._notice()
		break
	for i in 6:
		sim_step(1.0 / 30.0)
	cam.focus(c + Vector3(-16, 0, 2), 26.0)
	cam.snap()
	for i in 20:
		await get_tree().process_frame
	await _shot(dir + "/fx_build_damage.png")
	get_tree().quit()

func _uishots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var vsz := get_viewport().get_visible_rect().size
	var tag := "portrait" if vsz.y > vsz.x else "landscape"
	for i in 10:
		await get_tree().process_frame
	await _shot(dir + "/ui_%s_title.png" % tag)
	hud.show_title(false)
	phase = "build"
	phase_t = 84.0
	supplies = 1240
	var c := Defs.hq_center()
	var ring: Array[Vector3] = []
	for q in START_RING:
		ring.append(c + q)
	walls.build_ring("wall", ring)
	walls.build_gate_now(c + Vector3(0, 0, 12.0))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(-3, -3))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(5, -3))
	buildings.place_built("mortar", Defs.HQ_ORIGIN + Vector2i(4, 4))
	for i in 6:
		people.spawn_civilian(c + Vector3(-3 + i * 0.8, 0, 6), true)
	people.add_job("soldier")
	people.add_job("soldier")
	people.add_job("loader")
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	for i in 240:
		sim_step(1.0 / 30.0)
	hud._toasts.clear()
	hud._gain = 0
	hud._gain_t = 0.0
	hud._banners.clear()
	hud._banner_age = -1.0
	hud.banner.visible = false
	var dist := 46.0 if tag == "portrait" else 36.0
	cam.focus(c + Vector3(0, 0, 3), dist)
	cam.snap()
	for i in 30:
		await get_tree().process_frame
	await _shot(dir + "/ui_%s_hud.png" % tag)
	hud.set_tab("build")
	hud._sheet_open = true
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/ui_%s_build.png" % tag)
	hud.set_tab("high")
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/ui_%s_fortress.png" % tag)
	hud.close_sheet()
	await get_tree().create_timer(0.4).timeout
	var seg = null
	for s in walls.live():
		if s.kind == "wall" and s.state == Building.BUILT and s.position.z < c.z - 6.0:
			seg = s
			break
	if seg != null:
		builder.sel_point = seg.position
		builder.select(seg)
		await get_tree().create_timer(0.5).timeout
		await _shot(dir + "/ui_%s_wall.png" % tag)
		builder.select(null)
		await get_tree().create_timer(0.4).timeout
	var zp := c + Vector3(7, 0, 7)
	builder.sel_point = zp
	builder.select(CardModels.ZoneInfo.new(zones.zone_at(zp)))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/ui_%s_zone.png" % tag)
	builder.select(null)
	await get_tree().create_timer(0.4).timeout
	builder.sel_point = buildings.hq.position
	builder.select(buildings.hq)
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/ui_%s_hq.png" % tag)
	builder.select(null)
	await get_tree().create_timer(0.4).timeout
	builder.select(CardModels.Settings.new())
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/ui_%s_settings.png" % tag)
	builder.select(null)
	await get_tree().create_timer(0.4).timeout
	_on_tool_pressed("wall")
	builder.tap(cam.cam.unproject_position(c + Vector3(-16, 0, -14)))
	builder.tap(cam.cam.unproject_position(c + Vector3(-4, 0, -20)))
	await get_tree().create_timer(0.5).timeout
	await _shot(dir + "/ui_%s_tool.png" % tag)
	get_tree().quit()

func _setup_world() -> void:
	_setup_env()
	grid = Grid.new()
	G.grid = grid
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	decor = Decor.new()
	decor.name = "Decor"
	add_child(decor)
	decor.setup(grid, 1337, G.map_id == "fields")
	Art.use_lawn(G.map_id == "suburb")
	terrain.setup(grid)
	G.terrain = terrain
	flow = FlowField.new(grid)
	if test_mode:
		flow.fixed_pops = 3000
	G.flow = flow
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	G.fx = fx
	sfx = Sfx
	G.sfx = sfx
	buildings = BuildingManager.new()
	buildings.name = "Buildings"
	add_child(buildings)
	G.buildings = buildings
	buildings.spawn_hq()
	zones = ZoneMap.new(grid)
	if test_mode:
		zones.fixed_work = 12000
	G.zones = zones
	Art.mat_ground.set_shader_parameter("zone_tex", zones.mask_tex)
	zones.updated.connect(_on_zones_updated)
	walls = WallSystem.new()
	walls.name = "Walls"
	add_child(walls)
	G.walls = walls
	var net := ElevatedNet.new()
	net.name = "Net"
	add_child(net)
	G.net = net
	var helis := HeliManager.new()
	helis.name = "Helis"
	add_child(helis)
	G.helis = helis
	grid.heal = walls.heal
	zombies = ZombieManager.new()
	zombies.name = "Zombies"
	add_child(zombies)
	G.zombies = zombies
	zombies.prewarm(12)
	zombies.killed.connect(_on_zombie_killed)
	quality = QualityManager.new()
	quality.name = "Quality"
	add_child(quality)
	workers = WorkerManager.new()
	workers.name = "Workers"
	add_child(workers)
	G.workers = workers
	soldiers = SoldierManager.new()
	soldiers.name = "Soldiers"
	add_child(soldiers)
	G.soldiers = soldiers
	people = PeopleManager.new()
	people.name = "People"
	add_child(people)
	G.people = people
	people.ruins = decor.ruins
	logi = Logistics.new()
	logi.name = "Logistics"
	add_child(logi)
	G.logi = logi
	logi.setup(decor.salvage_spots())
	if G.map_id == "suburb":
		var mb := MapBuilder.new()
		mb.name = "Map"
		add_child(mb)
		G.map = mb
		map_seed = G.rng.randi()
		if not G.resume.is_empty():
			map_seed = int(G.resume.get("seed", map_seed))
		mb.build(SuburbLayout.data(), map_seed)
		people.ruins = mb.survivor_points()
	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	G.cam = cam
	builder = BuildController.new()
	builder.name = "Builder"
	add_child(builder)
	G.builder = builder
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	G.hud = hud
	zones.compute_now()
	buildings.refresh_zones()
	flow.compute_now()
	_zones_ready = true
	people.setup_start()
	hud.tool_pressed.connect(_on_tool_pressed)
	hud.start_wave_pressed.connect(start_wave)
	hud.play_pressed.connect(_on_play)
	hud.continue_pressed.connect(_on_continue)
	hud.restart_pressed.connect(_on_restart)
	hud.card_action.connect(_on_card_action)
	builder.tool_changed.connect(_on_tool_changed)
	builder.message.connect(func(t):
		hud.toast(t)
		_ui("ui_invalid"))
	builder.plan_changed.connect(_on_plan_changed)
	hud.plan_undo.connect(func():
		_ui("ui_cancel")
		builder.undo_point())
	hud.confirm_pressed.connect(func():
		_ui("ui_confirm")
		builder.confirm())
	hud.cancel_pressed.connect(func():
		_ui("ui_cancel")
		builder.cancel())
	hud.map_picked.connect(func(id):
		_ui("ui_tap")
		if id != G.map_id:
			G.map_id = id
			get_tree().reload_current_scene()
		else:
			hud.title_card.queue_redraw())
	hud.settings_pressed.connect(func():
		_ui("ui_open")
		builder.select(CardModels.Settings.new()))
	hud.undo_last_pressed.connect(func():
		var n: int = builder.undo_last()
		_ui("ui_cancel" if n > 0 else "ui_invalid")
		hud.toast("Undone, supplies back" if n > 0 else "Work has started: can't undo"))
	_make_edge_markers()

func _setup_env() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.29, 0.42)
	sm.sky_horizon_color = Color(0.88, 0.64, 0.44)
	sm.ground_horizon_color = Color(0.5, 0.4, 0.31)
	sm.ground_bottom_color = Color(0.13, 0.12, 0.1)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.1
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.62
	e.ambient_light_sky_contribution = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.62, 0.52, 0.44)
	e.fog_light_energy = 1.0
	e.fog_density = 0.85
	e.fog_depth_begin = 70.0
	e.fog_depth_end = 230.0
	e.fog_depth_curve = 1.6
	e.fog_sky_affect = 0.0
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 0.9
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.1
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	world_env = WorldEnvironment.new()
	world_env.environment = e
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-27.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.77, 0.54)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	add_child(sun)

func _update_ui_scale() -> void:
	var win := get_window()
	var ws := Vector2(win.size)
	if ws.x < 2.0 or ws.y < 2.0:
		return
	var ratio := 1.0
	var insets := [0.0, 0.0, 0.0, 0.0]
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.zdUiScale || window.devicePixelRatio || 1", true)
		if v != null:
			ratio = float(v)
		var s = JavaScriptBridge.eval("JSON.stringify(window.zdSafe ? window.zdSafe() : [0,0,0,0])", true)
		if s is String:
			var arr = JSON.parse_string(s)
			if arr is Array and arr.size() == 4:
				insets = arr
	else:
		ratio = DisplayServer.screen_get_scale()
	if _ui_ratio > 0.0:
		ratio = _ui_ratio
	var f := maxf(1.0, ratio)
	var short := minf(ws.x, ws.y)
	if short / f < 360.0:
		f = short / 360.0
	if short / f > 900.0:
		f = short / 900.0
	f = maxf(f, 0.5)
	var size := Vector2i(int(ws.x / f), int(ws.y / f))
	if size != _last_ui_size:
		_last_ui_size = size
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = size
	var k := ratio / f
	hud.set_safe_insets(float(insets[0]) * k, float(insets[1]) * k, float(insets[2]) * k, float(insets[3]) * k)

func spend(n: int) -> bool:
	if n > supplies:
		return false
	supplies -= n
	return true

func add_supplies(n: int) -> void:
	supplies += n

func _on_zombie_killed(z) -> void:
	add_supplies(z.reward)

func _process(dt: float) -> void:
	if not manual_clock:
		sim_step(minf(dt, 0.1))
	_update_hud()
	quality.tick(dt)

func sim_step(dt: float) -> void:
	G.sim_time += dt
	zones.update(3000)
	flow.update(3000)
	match phase:
		"build":
			phase_t -= dt
			_save_t -= dt
			if _save_t <= 0.0:
				_save_t = 20.0
				autosave()
			if phase_t <= 0.0 and not test_mode:
				start_wave()
		"wave":
			_spawn_step(dt)
			if _queue.is_empty() and zombies.alive_count <= 0:
				_wave_cleared()
			elif _queue.is_empty() and zombies.alive_count <= 3:
				_straggle_t += dt
				if _straggle_t > 45.0:
					for z in zombies.alive_list:
						z.enrage()
				if _straggle_t > 150.0:
					for z in zombies.alive_list.duplicate():
						z.hurt(1000000000.0)
			else:
				_straggle_t = 0.0
			_wave_t += dt
			if zombies.alive_count != _stall_n or not _queue.is_empty():
				_stall_n = zombies.alive_count
				_stall_t = 0.0
			else:
				_stall_t += dt
			if (_stall_t > 120.0 and _stall_t - dt <= 120.0) or (_wave_t > 300.0 and _wave_t - dt <= 300.0):
				for z in zombies.alive_list:
					z.enrage()
			elif _stall_t > 180.0 or (_wave_t > 420.0 and _queue.is_empty() and zombies.alive_count <= maxi(10, wave_size(wave) / 10)):
				for z in zombies.alive_list.duplicate():
					z.hurt(1000000000.0)
	zombies.step(dt)
	walls.step(dt)
	buildings.step(dt)
	G.helis.step(dt)
	workers.step(dt)
	soldiers.step(dt)
	people.step(dt)
	fx.step(dt)
	_update_markers()

func _update_hud() -> void:
	var left := zombies.alive_count + _queue.size()
	var hq_frac := 0.0
	if buildings.hq and buildings.hq.state != Building.DEAD:
		hq_frac = buildings.hq.hp / buildings.hq.max_hp
	hud.set_state(supplies, wave, phase, maxf(0.0, phase_t), left, hq_frac)
	hud.set_people(people.population(), people.idle_count(), people.pop_cap())
	hud.set_crates(logi.crates_total(), logi.capacity_total())
	var need_goal: bool = phase == "build" and people.hq_zone() == 0 and not test_mode
	hud.set_goal(GOAL_TEXT if need_goal else "")
	hud.set_undo_last(builder.undo_t)
	var anchor: Vector3 = builder.pending_anchor() if builder.has_tool() and builder.has_pending() else Vector3.INF
	if anchor != Vector3.INF and not cam.cam.is_position_behind(anchor):
		hud.place_confirm(cam.cam.unproject_position(anchor), true, builder.pending_ok())
	else:
		hud.place_confirm(Vector2.ZERO, false, false)
	_amb_t -= get_process_delta_time()
	if _amb_t <= 0.0 and G.sfx and phase != "title":
		_amb_t = 0.5
		G.sfx.set_ambience(clampf(zombies.alive_count / 60.0, 0.0, 1.0))

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F3:
				hud.toggle_fps()
			KEY_ESCAPE:
				builder.set_tool("")
			KEY_ENTER, KEY_KP_ENTER:
				builder.confirm()
			KEY_BACKSPACE:
				builder.undo_point()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
				var i: int = 9 if e.keycode == KEY_0 else e.keycode - KEY_1
				if i < Defs.TOOLS.size():
					_on_tool_pressed(Defs.TOOLS[i])
			KEY_X:
				_on_tool_pressed("remove")
			KEY_SPACE:
				if phase == "build":
					start_wave()

func _on_plan_changed() -> void:
	var editing: bool = builder.is_wall_tool() or builder.tool == "_reshape"
	var n: int = builder.plan.size() if builder.is_wall_tool() else builder.rs_hist.size()
	hud.set_plan(editing, n)

func _ui(name: String) -> void:
	if G.sfx:
		G.sfx.play_ui(name)

func _on_tool_pressed(t: String) -> void:
	if phase == "over" or phase == "title":
		return
	_ui("ui_cancel" if t == builder.tool else "ui_tap")
	var need := int(Defs.BUILD.get(t, {}).get("unlock", 0))
	if need > wave:
		hud.toast("Unlocks at wave %d" % need)
		return
	builder.set_tool(t)

func _on_card_action(id: String, target) -> void:
	if id.begins_with("plus:"):
		var job := id.substr(5)
		var why: String = people.add_job(job)
		if why != "":
			hud.toast(why)
			_ui("ui_invalid")
		else:
			_ui("ui_recruit" if job == "soldier" else "ui_assign")
		return
	if id.begins_with("minus:"):
		var why2: String = people.remove_job(id.substr(6))
		if why2 != "":
			hud.toast(why2)
			_ui("ui_invalid")
		else:
			_ui("ui_cancel")
		return
	if id.begins_with("mount:"):
		var gun := id.substr(6)
		var why3 := ""
		if target is CardModels.SlotPick:
			if target.seg != null:
				why3 = walls.add_nest(target.seg, target.point, gun)
			elif buildings.mount(target.host, target.slot, gun) == null:
				why3 = "Can't put that there"
		_card_result(why3, "Workers will build it. A loader or soldier crews it")
		return
	var w := builder.sel_point
	match id:
		"close":
			_ui("ui_close")
			builder.select(null)
		"sell":
			_ui("ui_sell")
			buildings.remove_thing(target)
			builder.select(null)
		"assign":
			if target is Building:
				var n: int = soldiers.assign(target)
				if n == 0:
					hud.toast("No idle soldiers. Give people the Soldier job at the HQ")
					_ui("ui_invalid")
				else:
					_ui("ui_assign")
		"move", "rotate":
			_ui("ui_tap")
			builder.select(null)
			builder.begin_move(target)
		"slot":
			var i: int = target.free_slot()
			if i >= 0:
				builder.select(CardModels.SlotPick.new(target, i))
		"mount":
			builder.select(CardModels.SlotPick.new(null, -1, target, w if w != Vector3.INF else target.position))
		"upgrade":
			_card_result(walls.upgrade_segment(target), "Workers will build concrete. The wood stays up until then")
		"upgrade_run":
			_card_result(walls.upgrade_run(target), "Workers will build concrete. The wood stays up until then")
		"ports":
			_card_result(walls.add_ports(target), "Workers will cut firing ports")
		"bastion":
			_card_result(walls.add_bastion(target, w if w != Vector3.INF else target.position), "Workers will build the bastion")
		"gate":
			_card_result(walls.place_gate(w if w != Vector3.INF else target.position, target), "Workers will build the gate")
		"reshape":
			_ui("ui_tap")
			builder.select(null)
			builder.begin_reshape(target)
		"upgrade_zone":
			_card_result(walls.upgrade_zone(target.zone_id), "Workers will build concrete. The wood stays up until then")
		"expand":
			_ui("ui_tap")
			builder.select(null)
			builder.set_tool("wall")
			hud.toast("Draw from one wall to another, then tick")
		"inner_yes":
			_ui("ui_confirm")
			walls.remove_inner(target.payload)
			builder.select(null)
			hud.toast("Inner wall coming down (half refund)")
		"inner_no":
			_ui("ui_close")
			builder.select(null)
		"claim":
			_card_result(target.start_claim(), "Workers will secure it")
		"cancel_claim":
			_ui("ui_cancel")
			target.cancel_claim()
			builder.select(null)
		"rebuild":
			_card_result(walls.rebuild_rubble(target), "Workers will rebuild it")
		"floor":
			_card_result(target.add_floor(), "Workers will build the next storey")
		"buy_heli":
			_card_result(target.buy_heli(), "It's on its way")
		"heli_rescue":
			_ui("ui_tap")
			builder.heli_pad = target
			builder.set_tool("_heli_rescue")
		"heli_patrol":
			_ui("ui_tap")
			builder.heli_pad = target
			builder.set_tool("_heli_patrol")
		"heli_resupply":
			var why_r: String = target.heli.start_resupply() if target.heli != null else "No helicopter"
			_card_result(why_r, "Crates are on their way out")
		"clear_rubble":
			_ui("ui_sell")
			walls.clear_rubble(target)
			builder.select(null)
		"auto_rebuild":
			walls.auto_rebuild = not walls.auto_rebuild
			_ui("ui_tap")
			hud.toast("Auto rebuild %s" % ("on" if walls.auto_rebuild else "off"))
			hud.show_card(target)
		"claim_fence":
			_card_result(target.claim(), "Workers will make it part of your walls")
		"sound_test":
			if OS.has_feature("web"):
				JavaScriptBridge.eval("window.zdAudioKick && window.zdAudioKick()", true)
			if G.sfx:
				G.sfx.play_ui("wave_cleared")
		"mute":
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
			hud.settings_btn.queue_redraw()
		"quality":
			quality.next_mode()
			_ui("ui_tap")
			hud.toast("Graphics: %s" % quality.label())
		"zspeed":
			zombie_speed = _next_choice(SPEED_CHOICES, zombie_speed)
			_save_game_settings()
			_ui("ui_tap")
			hud.toast("Zombie speed %d%%  ·  new zombies from now on" % int(round(zombie_speed * 100.0)))
		"horde":
			horde_mult = _next_choice(HORDE_CHOICES, horde_mult)
			_save_game_settings()
			_ui("ui_tap")
			hud.toast("Horde size %d%%  ·  from the next wave" % int(round(horde_mult * 100.0)))
		"fps":
			quality.next_fps()
			_ui("ui_tap")
			hud.toast("Frame rate: %s%s" % [quality.fps_label(), "  ·  cooler, longer battery" if quality.fps_cap == 30 else ""])

func _card_result(why: String, ok_text: String) -> void:
	if why != "":
		hud.toast(why)
		_ui("ui_invalid")
		return
	_ui("ui_confirm")
	builder.select(null)
	hud.toast(ok_text)

func _on_zones_updated(breached: bool, secured: bool) -> void:
	buildings.refresh_zones()
	if _zones_ready and phase != "over" and not test_mode:
		var inner: Array = walls.ready_expansion()
		if not inner.is_empty():
			if true:
				var refund := 0
				for s in inner:
					refund += int(round(s.paid * Defs.REFUND_BUILT))
				builder.select(CardModels.Ask.new("Remove inner wall?", ["The new zone is sealed. The old wall between is now inside.", "Take it down for +%d?" % refund], "inner_yes", "inner_no", inner))
	if not _zones_ready or phase == "title" or phase == "over":
		return
	if breached:
		hud.show_banner("ZONE BREACHED", "Workers will rebuild the wall" if walls.auto_rebuild else "Tap the rubble to rebuild it", Hud.DANGER)
		_ui("zone_breached")
		cam.shake(0.4)
	elif secured:
		hud.show_banner("ZONE SECURED", "Guns inside restock from crates in the zone", Hud.OK)

func _on_tool_changed(t: String) -> void:
	var h := ""
	if t == "remove":
		h = "Tap what to remove, then tick (refund)"
	elif t == "_move":
		h = "Drag it or tap a spot, turn the handle, then tick"
	elif t == "_reshape":
		h = "Drag corners, tap + for a new corner, then tick"
	elif t == "_heli_rescue":
		h = "Tap a group of survivors (SOS)"
	elif t == "_heli_patrol":
		h = "Tap where it should patrol"
	elif Defs.BUILD.has(t):
		h = String(Defs.BUILD[t].get("hint", ""))
		if Defs.MOUNTABLE.has(t):
			h = "Tap ground or a glowing slot, then tick"
		elif t == "wall" or t == "concrete":
			h = "Tap points. Drag to look. Tick to build"
		elif t == "wire" or t == "dig":
			h = "Tap the start, tap the end, then tick"
		elif not Defs.is_prefab(t):
			h = "Tap to place, then tick"
	hud.set_tool(t, h)

func _on_play() -> void:
	_ui("ui_confirm")
	hud.show_title(false)
	phase = "build"
	phase_t = Defs.FIRST_BUILD_PHASE_TIME
	cam.focus(Defs.hq_center() + Vector3(0, 0, 4), 38.0)
	hud.show_banner("BUILD", "Wave 1 comes from the %s" % _edge_text())
	hud.toast("Tap BUILD, pick Wood, tap points round the HQ, then tick")

func _on_restart() -> void:
	get_tree().reload_current_scene()

func wave_size(w: int) -> int:
	return maxi(1, int(round(_base_wave_size(w) * horde_mult)))

func _base_wave_size(w: int) -> float:
	var mult: float = float(G.map.layout.get("wave_mult", 1.0)) if G.map else 1.0
	if w == 1:
		return 24.0
	if w == 2:
		return 44.0
	if w == 3:
		return 60.0
	return 60.0 * pow(1.38, w - 3) * mult

func _load_game_settings() -> void:
	if test_mode:
		return
	var cf := ConfigFile.new()
	if cf.load(QualityManager.SETTINGS_PATH) == OK:
		var sp := float(cf.get_value("game", "zombie_speed", 1.0))
		var hm := float(cf.get_value("game", "horde", 1.0))
		zombie_speed = sp if SPEED_CHOICES.has(sp) else 1.0
		horde_mult = hm if HORDE_CHOICES.has(hm) else 1.0

func _save_game_settings() -> void:
	if test_mode:
		return
	var cf := ConfigFile.new()
	cf.load(QualityManager.SETTINGS_PATH)
	cf.set_value("game", "zombie_speed", zombie_speed)
	cf.set_value("game", "horde", horde_mult)
	cf.save(QualityManager.SETTINGS_PATH)

static func _next_choice(choices: Array, v: float) -> float:
	var i := choices.find(v)
	return choices[(i + 1) % choices.size()]

func _plan_edges() -> void:
	var n := 1
	if wave >= 2:
		n = 2
	if wave >= 6:
		n = 3
	if wave >= 9:
		n = 4
	var all := [0, 1, 2, 3]
	all.shuffle()
	if wave == 1:
		all = [0]
	_edges = all.slice(0, n)
	_edges.sort()

func _edge_text() -> String:
	var names := []
	for e in _edges:
		names.append(EDGE_NAMES[e])
	if names.size() == 1:
		return names[0]
	if names.size() == 4:
		return "every side"
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]

func start_wave() -> void:
	if phase != "build":
		return
	autosave()
	phase = "wave"
	zombies.wave = wave
	_wave_t = 0.0
	_stall_t = 0.0
	_queue.clear()
	var count := wave_size(wave)
	var runner_frac := 0.0
	if wave >= 3:
		runner_frac = minf(0.3, 0.1 + 0.025 * (wave - 3))
	var brutes := mini(count, int(round(brute_count(wave) * horde_mult)))
	for i in count - brutes:
		_queue.append(Defs.Z_RUNNER if G.rng.randf() < runner_frac else Defs.Z_WALKER)
	_queue.shuffle()
	for i in brutes:
		var at := int(float(_queue.size()) * (0.15 + 0.6 * float(i) / maxf(1.0, brutes)))
		_queue.insert(clampi(at, 0, _queue.size()), Defs.Z_BRUTE)
	var duration := 22.0 + wave * 4.0
	if wave == 1:
		duration = 40.0
	_spawn_gap = maxf(0.12, duration / count)
	_spawn_t = 0.5
	var sub := "From the %s" % _edge_text()
	if brutes > 0:
		sub += "  ·  %d brute%s" % [brutes, "" if brutes == 1 else "s"]
	hud.show_banner("WAVE %d" % wave, sub)
	if G.sfx:
		G.sfx.play("siren", Vector3.ZERO)
	wave_started.emit(wave)

func brute_count(w: int) -> int:
	if w < 4:
		return 0
	return w - 3 + maxi(0, w - 7)

func _spawn_step(dt: float) -> void:
	_spawn_t -= dt
	var cap: int = quality.horde_cap() if quality else Defs.MAX_ALIVE
	while _spawn_t <= 0.0 and not _queue.is_empty():
		if zombies.alive_count >= cap:
			_spawn_t = 0.3
			return
		var pack := mini(_queue.size(), G.rng.randi_range(2, 4) if wave < 4 else G.rng.randi_range(3, 7))
		var at := _spawn_point()
		for k in pack:
			if zombies.alive_count >= cap:
				break
			var kind: int = _queue.pop_back()
			var off := Vector3(G.rng.randf_range(-2.5, 2.5), 0, G.rng.randf_range(-2.5, 2.5))
			zombies.spawn(kind, at + off)
		_spawn_t += _spawn_gap * pack * G.rng.randf_range(0.6, 1.4)

func _spawn_point() -> Vector3:
	var e: int = _edges[G.rng.randi() % _edges.size()]
	if G.map:
		return G.map.spawn_point(e, G.rng)
	var h := Defs.HALF
	var along := G.rng.randf_range(-h * 0.6, h * 0.6)
	var out := G.rng.randf_range(2.0, 7.0)
	match e:
		0:
			return Vector3(along, 0, -h - out)
		1:
			return Vector3(h + out, 0, along)
		2:
			return Vector3(along, 0, h + out)
		_:
			return Vector3(-h - out, 0, along)

func wave_bonus() -> int:
	var claimed := 0
	if G.map:
		for mb in G.map.buildings:
			if is_instance_valid(mb) and mb.claimed:
				claimed += 1
	return Defs.WAVE_BONUS_BASE + Defs.WAVE_BONUS_PER * wave + Defs.BONUS_PER_PERSON * maxi(0, people.population() - Defs.BONUS_FREE_PEOPLE) + Defs.BONUS_PER_CLAIM * claimed

func _wave_cleared() -> void:
	waves_cleared = wave
	var bonus := wave_bonus()
	var farm := 0
	for b in buildings.built_of("greenhouse"):
		farm += int(b.def.get("income", 0))
	add_supplies(bonus + farm)
	var sub := "+%d supplies" % (bonus + farm)
	if farm > 0:
		sub += " (%d from farms)" % farm
	if people.saved_wave > 0:
		sub += "  ·  %d saved" % people.saved_wave
	if people.lost_wave > 0:
		sub += "  ·  %d lost" % people.lost_wave
	hud.show_banner("WAVE %d CLEARED" % wave, sub)
	_ui("wave_cleared")
	logi.on_wave_cleared()
	wave_cleared.emit(wave)
	wave += 1
	phase = "build"
	phase_t = Defs.BUILD_PHASE_TIME
	_plan_edges()
	if wave == 3 and buildings.count_built("workshop") == 0:
		hud.toast("Guns use up ammo crates. Build a Workshop and add Crafters")
	for t in Defs.TOOLS:
		if int(Defs.BUILD[t].get("unlock", 0)) == wave:
			hud.toast("%s unlocked" % String(Defs.BUILD[t].get("long", t)))
	_save_t = 20.0
	autosave()

func autosave() -> void:
	if test_mode or manual_clock or phase == "title" or phase == "over":
		return
	SaveGame.write(self)

func _on_continue() -> void:
	var d := SaveGame.read()
	if d.is_empty():
		hud.toast("That save can't be loaded")
		_ui("ui_invalid")
		return
	_ui("ui_confirm")
	G.resume = d
	get_tree().reload_current_scene()

func _continue(d: Dictionary) -> void:
	hud.show_title(false)
	if not SaveGame.restore(self, d):
		hud.show_title(true)
		return
	phase = "build"
	phase_t = maxf(float(d.get("phase_t", 0.0)), 30.0)
	_save_t = 20.0
	_plan_edges()
	cam.focus(Defs.hq_center() + Vector3(0, 0, 4), 38.0)
	cam.snap()
	hud.show_banner("WELCOME BACK", "Wave %d comes from the %s" % [wave, _edge_text()])

func on_hq_destroyed() -> void:
	if phase == "over":
		return
	phase = "over"
	SaveGame.clear()
	builder.set_tool("")
	builder.select(null)
	_queue.clear()
	hud.show_game_over(waves_cleared, zombies.kills)

func _make_edge_markers() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(44.0, 7.0)
	var h := Defs.HALF - 4.0
	var spots := [
		[Vector3(0, 0.05, -h), PI],
		[Vector3(h, 0.05, 0), PI * 0.5],
		[Vector3(0, 0.05, h), 0.0],
		[Vector3(-h, 0.05, 0), -PI * 0.5],
	]
	for s in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = Art.mat_spawn_arrow
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = s[0]
		mi.rotation.y = s[1]
		mi.visible = false
		add_child(mi)
		_edge_markers.append(mi)

func _update_markers() -> void:
	var show := phase == "build" or (phase == "wave" and not _queue.is_empty())
	for i in 4:
		_edge_markers[i].visible = show and _edges.has(i)

func _showcase(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	hud.show_title(false)
	phase = "build"
	phase_t = 999.0
	supplies = 20000
	wave = 6
	var c := Defs.hq_center()
	cam.focus(c + Vector3(0, 0, 2), 36.0)
	cam.snap()
	hud.set_tab("build")
	for i in 40:
		sim_step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot(dir + "/01_start.png")
	builder.set_tool("wall")
	var ring := []
	for q in START_RING:
		ring.append(c + q)
	cam.focus(c, 40.0)
	cam.snap()
	for i in 3:
		await get_tree().process_frame
	for i in 5:
		builder.tap(cam.cam.unproject_position(ring[i]))
	for i in 6:
		_update_hud()
		await get_tree().process_frame
	await _shot(dir + "/02_drawing.png")
	builder.cancel()
	builder.set_tool("")
	var rp: Array[Vector3] = []
	for q in ring:
		rp.append(q)
	walls.build_ring("wall", rp)
	walls.build_gate_now(c + Vector3(0, 0, 12))
	var zf := c.z - 19.0
	var house: Building = buildings.place_rect("house", Vector3(c.x - 7.0, 0, zf), 0.0, true)
	var bar: Building = buildings.place_rect("barracks", Vector3(c.x + 2.0, 0, zf), 0.0, true)
	walls.lay("wall", c + Vector3(-9, 0, -11), Vector3(c.x - 9.0, 0, zf + 2.0), 0, true)
	walls.lay("wall", Vector3(c.x - 5.0, 0, zf), Vector3(c.x - 1.0, 0, zf), 0, true)
	walls.lay("wall", Vector3(c.x + 5.0, 0, zf + 2.0), Vector3(c.x + 9.0, 0, zf + 2.0), 0, true)
	walls.lay("wall", Vector3(c.x + 9.0, 0, zf + 2.0), c + Vector3(9, 0, -11), 0, true)
	walls.refresh_posts()
	zones.compute_now()
	buildings.refresh_zones()
	var inner := walls.inner_path(WallSystem.vkey(c + Vector3(-9, 0, -11)), WallSystem.vkey(c + Vector3(9, 0, -11)), [])
	walls.remove_inner(inner)
	if house:
		buildings.mount(house, 0, "turret", false, true)
		buildings.mount(house, 1, "sniper", false, true)
	if bar:
		buildings.mount(bar, 0, "mortar", false, true)
	var east: LinearStructure = walls.segment_at(c + Vector3(12, 0, 1), 1.0)
	if east:
		walls.add_bastion(east, c + Vector3(12, 0, 1))
	var west: LinearStructure = walls.segment_at(c + Vector3(-12, 0, 2), 1.0)
	if west:
		walls.add_nest(west, c + Vector3(-12, 0, 2), "turret")
	var south: LinearStructure = walls.segment_at(c + Vector3(6, 0, 12), 1.0)
	if south:
		walls.add_ports(south)
	var plat_c := Defs.world_to_cell(c + Vector3(-6, 0, 18))
	if buildings.place("platform", plat_c):
		buildings.mount(buildings.last_placed, 0, "turret")
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(-3, -2))
	buildings.place_built("turret", Defs.HQ_ORIGIN + Vector2i(4, -2))
	for i in 10:
		people.spawn_civilian(c + Vector3(-2 + i * 0.5, 0, 6), true)
	for i in 4:
		people.add_job("worker")
	for i in 3:
		people.add_job("loader")
	for i in 2:
		people.add_job("soldier")
	people.add_job("fetcher")
	var fp := buildings.place_rect("depot", Vector3(c.x + 22.0, 0, c.z + 4.0), deg_to_rad(30.0), true)
	for i in 3000:
		sim_step(1.0 / 30.0)
		if i % 200 == 0:
			await get_tree().process_frame
	zones.compute_now()
	buildings.refresh_zones()
	if south:
		pass
	for s2 in walls.live():
		if s2.ported and s2.free_slots() > 0:
			soldiers.assign(s2)
	for i in 300:
		sim_step(1.0 / 30.0)
		if i % 60 == 0:
			await get_tree().process_frame
	cam.focus(c + Vector3(0, 0, -4), 50.0)
	cam.snap()
	for i in 10:
		await get_tree().process_frame
	await _shot(dir + "/03_base.png")
	var wseg: LinearStructure = walls.segment_at(c + Vector3(-12, 0, -3), 1.0)
	cam.focus(c + Vector3(-8, 0, 0), 32.0)
	cam.snap()
	builder.sel_point = c + Vector3(-12, 0, -3)
	builder.select(wseg)
	for i in 6:
		await get_tree().process_frame
	await _shot(dir + "/04_wall_card.png")
	builder.select(null)
	builder.select(buildings.hq)
	for i in 6:
		await get_tree().process_frame
	await _shot(dir + "/05_people.png")
	builder.select(null)
	builder.set_tool("workshop")
	cam.focus(c + Vector3(24, 0, -14), 34.0)
	cam.snap()
	for i in 3:
		await get_tree().process_frame
	builder.tap(cam.cam.unproject_position(c + Vector3(24, 0, -14)))
	builder.g_yaw = deg_to_rad(30.0)
	builder._refresh_ghost()
	for i in 6:
		_update_hud()
		await get_tree().process_frame
	await _shot(dir + "/06_place_building.png")
	builder.set_tool("")
	builder.set_tool("turret")
	cam.focus(c + Vector3(0, 0, -18), 40.0)
	cam.snap()
	for i in 3:
		await get_tree().process_frame
	if bar:
		builder.tap(cam.cam.unproject_position(bar.slot_xform(1).origin))
	for i in 6:
		_update_hud()
		await get_tree().process_frame
	await _shot(dir + "/07_roof_gun.png")
	builder.set_tool("")
	_edges = [0, 1]
	start_wave()
	for i in 2100:
		sim_step(1.0 / 30.0)
		if i % 90 == 0 or i > 1900:
			await get_tree().process_frame
	cam.focus(c + Vector3(4, 0, -8), 48.0)
	cam.snap()
	for i in 6:
		sim_step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot(dir + "/08_wave.png")
	cam.focus(c + Vector3(10, 0, 4), 16.0)
	cam.snap()
	for i in 6:
		sim_step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot(dir + "/09_close.png")
	builder.select(CardModels.Settings.new())
	for i in 4:
		await get_tree().process_frame
	await _shot(dir + "/10_sound.png")
	get_tree().quit()

func _shot(path: String) -> void:
	if hud and (path.contains("v06") or path.contains("suburb_v05")):
		hud._banners.clear()
		hud._banner_age = -1.0
		hud.banner.visible = false
	if hud:
		hud._gain_t = 0.0
		hud._gain = 0
		hud.stats.queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
