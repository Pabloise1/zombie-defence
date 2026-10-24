class_name PeopleManager
extends Node3D
signal changed
const MAX_PEOPLE := 140
var arrivals_in_tests := false
var civilians: Array = []
var loaders: Array = []
var fetchers: Array = []
var crafters: Array = []
var ruins: Array[Vector3] = []
var joined_recent := 0
var _join_t := 0.0
var _claims := {}
var _assign_t := 0.0
var _crew_t := 0.0
var _group_t := 8.0
var _groups_left := 0
var _straggle_t := -1.0
var _last_phase := ""
var groups: Array = []
var _sos_left := 0
var _sos_t := 0.0
var saved_wave := 0
var lost_wave := 0

class StrandedGroup:
	extends RefCounted
	var pos := Vector3.ZERO
	var members: Array = []
	var marker: Label3D
	var heli = null
	var rescuer = null
	var t := 0.0
	func call_to(p: Vector3) -> void:
		for c in members:
			if is_instance_valid(c) and not c.dead:
				c.board_at(p)

func owned_civilians() -> Array:
	var out := []
	for c in civilians:
		if not c.dead and c.owned:
			out.append(c)
	return out

func idle_count() -> int:
	return owned_civilians().size()

func count_job(job: String) -> int:
	match job:
		"worker":
			return G.workers.workers.size()
		"soldier":
			return G.soldiers.soldiers.size()
		"loader":
			return loaders.size()
		"fetcher":
			return fetchers.size()
		"crafter":
			return crafters.size()
	return 0

func population() -> int:
	var n := idle_count()
	for j in Defs.JOBS:
		n += count_job(j)
	return n

func pop_cap() -> int:
	return mini(MAX_PEOPLE, G.logi.pop_cap()) if G.logi else Defs.POP_BASE

func room() -> int:
	return maxi(0, pop_cap() - population() - _arriving())

func all_people() -> Array:
	var out: Array = []
	out.append_array(civilians)
	out.append_array(G.workers.workers)
	out.append_array(G.soldiers.soldiers)
	out.append_array(loaders)
	out.append_array(fetchers)
	out.append_array(crafters)
	return out

func workshop_for(c):
	var best = null
	var bd := INF
	for b in G.buildings.built_of("workshop"):
		if crafters_at(b) >= Defs.CRAFTERS_PER_WORKSHOP and c.shop != b:
			continue
		var d: float = b.position.distance_to(c.position)
		if d < bd:
			bd = d
			best = b
	return best

func crafters_at(b) -> int:
	var n := 0
	for c in crafters:
		if c.shop == b:
			n += 1
	return n

func add_job(job: String) -> String:
	var idle := owned_civilians().filter(func(c): return c.mode == Civilian.IDLE and c.visible)
	if idle.is_empty():
		if not owned_civilians().is_empty():
			return "Your idle people are still on their way in"
		return "No idle people. Bring survivors in"
	var arm: int = G.logi.soldier_cost() if G.logi else Defs.SOLDIER_ARM_COST
	if job == "soldier" and not G.main.spend(arm):
		return "Arming a soldier costs %d" % arm
	var hq := Defs.hq_center()
	idle.sort_custom(func(a, b): return a.position.distance_squared_to(hq) < b.position.distance_squared_to(hq))
	var c: Civilian = idle[0]
	var at := c.position
	civilians.erase(c)
	c.queue_free()
	_spawn_job(job, at)
	changed.emit()
	return ""

func _spawn_job(job: String, at: Vector3) -> void:
	match job:
		"worker":
			G.workers.add_worker(at)
		"soldier":
			G.soldiers.add_soldier(at)
		"loader":
			var l := Loader.new()
			l.name = "Loader%d" % loaders.size()
			add_child(l)
			loaders.append(l)
			l.setup(at)
		"fetcher":
			var f := Fetcher.new()
			f.name = "Fetcher%d" % fetchers.size()
			add_child(f)
			fetchers.append(f)
			f.setup(at)
		"crafter":
			var c := Crafter.new()
			c.name = "Crafter%d" % crafters.size()
			add_child(c)
			crafters.append(c)
			c.setup(at)

func remove_job(job: String) -> String:
	var who = null
	match job:
		"worker":
			for w in G.workers.workers:
				if not w.is_busy():
					who = w
			if who == null and not G.workers.workers.is_empty():
				who = G.workers.workers.back()
			if who != null:
				G.workers.remove_worker(who)
		"soldier":
			for s in G.soldiers.soldiers:
				if s.is_free():
					who = s
			if who == null and not G.soldiers.soldiers.is_empty():
				who = G.soldiers.soldiers.back()
			if who != null:
				if who.post and is_instance_valid(who.post):
					who.post.soldier_cancelled(who)
					who.post = null
				G.soldiers.remove_soldier(who)
		"loader":
			for l in loaders:
				if l.is_free():
					who = l
			if who == null and not loaders.is_empty():
				who = loaders.back()
			if who != null:
				who.release()
				loaders.erase(who)
		"fetcher":
			for f in fetchers:
				if f.mode == Fetcher.IDLE:
					who = f
			if who == null and not fetchers.is_empty():
				who = fetchers.back()
			if who != null:
				who._leave_spot()
				fetchers.erase(who)
		"crafter":
			if not crafters.is_empty():
				who = crafters.back()
				for c in crafters:
					if c.mode != Crafter.WORK:
						who = c
				who.release()
				crafters.erase(who)
	if who == null:
		return "Nobody has that job"
	var at: Vector3 = who.global_position
	at.y = 0.0
	who.queue_free()
	spawn_civilian(at, true)
	changed.emit()
	return ""

func spawn_civilian(at: Vector3, owned: bool) -> Civilian:
	var c := Civilian.new()
	c.name = "Civilian%d" % civilians.size()
	add_child(c)
	civilians.append(c)
	c.setup(at, owned)
	return c

func spawn_group(at: Vector3, n: int) -> void:
	for i in n:
		spawn_civilian(at + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), false)

func spawn_stranded(at: Vector3, n: int) -> StrandedGroup:
	var g := StrandedGroup.new()
	g.pos = at
	for i in n:
		var c := spawn_civilian(at + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8)), false)
		c.waiting = true
		c.stop()
		g.members.append(c)
	var m := Label3D.new()
	m.text = "SOS  %d" % n
	m.font_size = 64
	m.outline_size = 16
	m.pixel_size = 0.01
	m.modulate = Color(1.0, 0.85, 0.25)
	m.outline_modulate = Color(0.15, 0.05, 0.02)
	m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.fixed_size = true
	m.pixel_size = 0.0016
	if Hud.font_heavy:
		m.font = Hud.font_heavy
	m.position = at + Vector3(0, 3.2, 0)
	add_child(m)
	g.marker = m
	groups.append(g)
	return g

func stranded_count() -> int:
	var n := 0
	for g in groups:
		if not g.members.is_empty():
			n += 1
	return n

func group_near(p: Vector3, r: float):
	var best = null
	var bd := r
	for g in groups:
		if g.members.is_empty():
			continue
		var d: float = Vector2(g.pos.x - p.x, g.pos.z - p.z).length()
		if d < bd:
			bd = d
			best = g
	return best

func group_to_rescue(from: Vector3):
	var best = null
	var bd := INF
	for g in groups:
		if g.members.is_empty() or g.heli != null:
			continue
		if g.rescuer != null and is_instance_valid(g.rescuer) and not g.rescuer.dead:
			continue
		if G.zombies and G.zombies.count_near(g.pos, 10.0) > 3:
			continue
		var d: float = g.pos.distance_to(from)
		if d < bd:
			bd = d
			best = g
	return best

# A fetcher reached them: everyone gets up and runs for the nearest shelter.
func release_group(g) -> int:
	var n := 0
	for c in g.members:
		if is_instance_valid(c) and not c.dead:
			c.waiting = false
			c.boarding = false
			c._plan_refuge()
			n += 1
	g.members.clear()
	remove_group(g)
	return n

func leave_group(c) -> void:
	for g in groups:
		g.members.erase(c)

func remove_group(g) -> void:
	groups.erase(g)
	if g.marker and is_instance_valid(g.marker):
		g.marker.queue_free()

func _step_groups(dt: float) -> void:
	for g in groups.duplicate():
		for c in g.members.duplicate():
			if not is_instance_valid(c) or c.dead or c.owned:
				g.members.erase(c)
		g.t += dt
		if g.members.is_empty() and g.heli == null:
			remove_group(g)
			continue
		var coming: bool = g.heli != null or (g.rescuer != null and is_instance_valid(g.rescuer) and not g.rescuer.dead)
		if g.marker:
			g.marker.text = "SOS  %d" % g.members.size() if not coming else "HELP COMING"
			g.marker.visible = not g.members.is_empty()
		if g.t > 120.0 and not coming:
			for c in g.members:
				if is_instance_valid(c):
					c.waiting = false
					c._plan_refuge()
			g.members.clear()
			remove_group(g)

func setup_start() -> void:
	var door := Defs.hq_center() + Vector3(0, 0, 4.0)
	for i in Defs.START_PEOPLE:
		spawn_civilian(door + Vector3((i - 2) * 0.9, 0, randf_range(0.0, 1.0)), true)
	for i in Defs.START_WORKERS:
		add_job("worker")

func on_joined(c) -> void:
	joined_recent += 1
	saved_wave += 1
	_join_t = 1.2
	changed.emit()

func on_dead(p) -> void:
	civilians.erase(p)
	loaders.erase(p)
	fetchers.erase(p)
	crafters.erase(p)
	if p is Worker:
		G.workers.workers.erase(p)
	if p is Soldier:
		G.soldiers.on_dead(p)
	if p is Civilian and (not p.owned or p.mode != Civilian.IDLE):
		lost_wave += 1
		if G.hud:
			G.hud.toast("A survivor was caught")
	changed.emit()

func on_building_removed(b) -> void:
	for l in loaders:
		if l.gun == b or l.dest == b or l.src == b or l.crewing == b:
			l.release()
			l.mode = Loader.IDLE
			l.go_home()
	_claims.erase(b)

func hq_zone() -> int:
	return G.zones.zone_at(Defs.hq_center() + Vector3(0, 0, 4.2)) if G.zones else 0

func is_safe(p: Vector3) -> bool:
	if G.zones and G.zones.zone_at(p) > 0:
		return true
	return hq_zone() == 0 and p.distance_to(Defs.hq_center()) < 8.0

func home_spot(_who) -> Vector3:
	var hq := Defs.hq_center()
	var z := hq_zone()
	var g: Grid = G.grid
	for i in 24:
		var a := randf() * TAU
		var r := randf_range(4.5, 10.0)
		var p := hq + Vector3(cos(a) * r, 0, sin(a) * r)
		var n := Defs.world_to_nav(p)
		if not g.ninb(n):
			continue
		var j := g.nidx(n)
		if not g.nwalk_people_i(j) or g.hq_nav.has(j) or g.nblk[j] == Grid.N_GATE:
			continue
		if z > 0 and G.zones.region[j] != z:
			continue
		if _near_gate(n):
			continue
		return Defs.nav_center(n)
	return hq + Vector3(randf_range(-2, 2), 0, 4.5)

func _near_gate(n: Vector2i) -> bool:
	var g: Grid = G.grid
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var m := n + Vector2i(dx, dy)
			if g.ninb(m) and g.nblk[g.nidx(m)] == Grid.N_GATE:
				return true
	return false

func safe_houses() -> Array:
	var out := []
	if G.map:
		for mb in G.map.buildings:
			if is_instance_valid(mb) and mb.claimed and mb.state == Building.BUILT:
				out.append(mb)
	return out

func shelter_cap(h) -> int:
	return int(h.def.get("pop", 1)) + 2

func sheltered_in(h) -> int:
	var n := 0
	for c in civilians:
		if not c.dead and c.shelter == h:
			n += 1
	return n

func _house_open(h) -> bool:
	return sheltered_in(h) < shelter_cap(h) and (G.zombies == null or G.zombies.count_near(h.entry_point(), 5.0) == 0)

# Safe houses only take people in while a wave is on; between waves the
# base is the place to be.
func _sheltering() -> bool:
	return G.main != null and G.main.phase == "wave"

func shelter_at(p: Vector3):
	if not _sheltering():
		return null
	for h in safe_houses():
		var e: Vector3 = h.entry_point()
		if Vector2(e.x - p.x, e.z - p.z).length() < 2.2 and _house_open(h):
			return h
	return null

func refuge_goals(from: Vector3, houses: bool = false) -> Dictionary:
	var g: Grid = G.grid
	var best = null
	var bd := INF
	if houses and _sheltering() and G.zones and G.zones.zone_at(from) == 0:
		var hb = null
		var hd := INF
		for h in safe_houses():
			if not _house_open(h):
				continue
			var d0: float = h.entry_point().distance_squared_to(from)
			if d0 < hd:
				hd = d0
				hb = h
		if hb != null:
			var gate_d := INF
			if G.walls:
				for s in G.walls.live():
					if s.kind == "gate" and s.state == Building.BUILT and _gate_zone(s) > 0:
						gate_d = minf(gate_d, s.position.distance_squared_to(from))
			if hq_zone() == 0:
				gate_d = minf(gate_d, Defs.hq_center().distance_squared_to(from))
			if hd < gate_d:
				var hg: Dictionary = g.point_goals(hb.entry_point(), 1)
				if not hg.is_empty():
					return hg
	if G.walls:
		for s in G.walls.live():
			if s.kind == "gate" and s.state == Building.BUILT:
				var d: float = s.position.distance_squared_to(from)
				if d < bd and _gate_zone(s) > 0:
					bd = d
					best = s
	var goals := {}
	if best != null:
		var c := Defs.world_to_nav(best.position)
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var n := c + Vector2i(dx, dy)
				if g.ninb(n):
					var j := g.nidx(n)
					if G.zones.region[j] > 0 and g.nwalk_people_i(j):
						goals[j] = true
		return goals
	if hq_zone() == 0:
		return g.point_goals(Defs.hq_center() + Vector3(0, 0, 4.5), 2)
	return goals

func _gate_zone(s) -> int:
	var n := Vector3(-s.dir.z, 0, s.dir.x)
	for side in [1.0, -1.0]:
		var z: int = G.zones.zone_at(s.position + n * side * 1.5)
		if z > 0:
			return z
	return 0

func hide_spot(p: Vector3, threat = null) -> Vector3:
	var zone: int = G.zones.zone_at(p) if G.zones else 0
	var best := Vector3.INF
	var bd := INF
	var doors: Array = [Defs.hq_center() + Vector3(0, 0, 3.8)]
	if G.buildings:
		for b in G.buildings.list:
			if is_instance_valid(b) and b.state == Building.BUILT and b.rect and b.host == null and b != G.buildings.hq and b.has_method("capacity") and b.capacity() > 0:
				doors.append(b.entry_point())
	for d in doors:
		var dz: int = G.zones.zone_at(d) if G.zones else 0
		if zone > 0 and dz != zone:
			continue
		var cost: float = p.distance_to(d)
		if threat != null and is_instance_valid(threat):
			if threat.position.distance_to(d) < 6.0:
				continue
			if (d - p).dot(threat.position - p) > 0.0 and threat.position.distance_to(p) < d.distance_to(p):
				cost += 25.0
		if cost < bd:
			bd = cost
			best = d
	return best

func nearest_safe_point(p: Vector3) -> Vector3:
	var g: Grid = G.grid
	var c := Defs.world_to_nav(p)
	var best := Vector3.INF
	var bd := INF
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var n := c + Vector2i(dx, dy)
			if not g.ninb(n):
				continue
			var j := g.nidx(n)
			if G.zones.region[j] > 0 and g.nwalk_people_i(j):
				var d := dx * dx + dy * dy
				if d < bd:
					bd = d
					best = Defs.nav_center(n)
	return best

func prey_near(z, r: float, skip = null):
	var zr: int = G.zones.zone_at(z.position) if G.zones else 0
	var best = null
	var bd := r * r
	for p in all_people():
		if p.dead or not p.exposed() or p == skip:
			continue
		var dx: float = p.position.x - z.position.x
		var dz: float = p.position.z - z.position.z
		var d2 := dx * dx + dz * dz
		if d2 >= bd:
			continue
		var pr: int = G.zones.zone_at(p.position) if G.zones else 0
		if pr != zr:
			continue
		bd = d2
		best = p
	return best

func anyone_passing(p: Vector3, cells: Dictionary) -> bool:
	for q in all_people():
		if q.dead or not q.visible or not q.exposed():
			continue
		var dx: float = q.position.x - p.x
		var dz: float = q.position.z - p.z
		if dx * dx + dz * dz > 49.0:
			continue
		if q.passing_through(cells):
			return true
	return false

func anyone_near(p: Vector3, r: float) -> bool:
	var r2 := r * r
	for q in all_people():
		if q.dead or not q.visible:
			continue
		var dx: float = q.position.x - p.x
		var dz: float = q.position.z - p.z
		if dx * dx + dz * dz < r2:
			return true
	return false

func claim(gun, l) -> void:
	_claims[gun] = l

func unclaim(gun) -> void:
	if gun != null:
		_claims.erase(gun)

func _assign_crews() -> void:
	for gun in G.buildings.mounted_guns():
		if gun.state != Building.BUILT or not gun.needs_crew():
			continue
		var taken := false
		for l in loaders:
			if l.gun == gun:
				taken = true
		if taken:
			continue
		if gun.kind != "sniper":
			var best = null
			var bd := INF
			for l in loaders:
				var spare: bool = l.is_free() or (l.mode == Loader.SERVE and l.crewing == null and l.gun != null and is_instance_valid(l.gun) and l.gun.host == null)
				if not l.dead and spare:
					var d: float = l.position.distance_squared_to(gun.position)
					if d < bd:
						bd = d
						best = l
			if best != null and best.serve(gun):
				continue
		var idle: Array = G.soldiers.idle_soldiers()
		if not idle.is_empty():
			idle.sort_custom(func(a, c): return a.position.distance_squared_to(gun.position) < c.position.distance_squared_to(gun.position))
			if idle[0].auto_post:
				idle[0].leave_post()
			idle[0].assign(gun)

func _assign_loaders() -> void:
	var guns: Array = G.buildings.guns()
	var free := []
	for l in loaders:
		if not l.dead and l.is_free():
			free.append(l)
	if free.is_empty():
		return
	var ph: String = G.main.phase
	if ph == "build" or ph == "wave":
		for gun in guns:
			if free.is_empty():
				return
			if gun.needs_restock() and not _claims.has(gun):
				if ph == "wave" and not Loader.trip_safe(Defs.hq_center(), gun.position):
					continue
				free.sort_custom(func(a, b): return a.position.distance_squared_to(gun.position) < b.position.distance_squared_to(gun.position))
				var l = free.pop_front()
				if not l.fetch(gun):
					free.append(l)
					break
		var ap = G.logi.ammo_point_to_fill() if G.logi else null
		if ap != null and not _claims.has(ap) and not free.is_empty():
			var l2 = free.pop_front()
			if not l2.fill(ap):
				free.append(l2)
	for l in free:
		var best = null
		var bd := INF
		for gun in guns:
			if gun.host != null:
				continue
			if gun.zone == 0 or (gun.loader != null and is_instance_valid(gun.loader) and gun.loader != l):
				continue
			var taken := false
			for o in loaders:
				if o != l and o.gun == gun:
					taken = true
					break
			if taken:
				continue
			var d: float = gun.position.distance_squared_to(l.position)
			if d < bd:
				bd = d
				best = gun
		if best != null:
			l.serve(best)

func step(dt: float) -> void:
	for c in civilians.duplicate():
		if is_instance_valid(c):
			c.step(dt)
	for l in loaders.duplicate():
		if is_instance_valid(l):
			l.step(dt)
	for f in fetchers.duplicate():
		if is_instance_valid(f):
			f.step(dt)
	for c in crafters.duplicate():
		if is_instance_valid(c):
			c.step(dt)
	for ch in get_children():
		if ch is Person and ch.dead and not civilians.has(ch) and not loaders.has(ch) and not fetchers.has(ch) and not crafters.has(ch):
			ch.step(dt)
	_crew_t -= dt
	if _crew_t <= 0.0:
		_crew_t = 0.5
		_assign_crews()
	_assign_t -= dt
	if _assign_t <= 0.0:
		_assign_t = 0.6
		_assign_loaders()
	if _join_t > 0.0:
		_join_t -= dt
		if _join_t <= 0.0 and joined_recent > 0:
			if G.hud:
				G.hud.toast("+%d %s joined" % [joined_recent, "person" if joined_recent == 1 else "people"])
			joined_recent = 0
	_arrivals(dt)
	_step_groups(dt)

func _rescue_hint() -> String:
	if fetchers.is_empty():
		return "Give people the Fetcher job to rescue them"
	return "Fetchers will run out for them"

func _arrivals(dt: float) -> void:
	if G.main == null or (G.main.test_mode and not arrivals_in_tests) or ruins.is_empty():
		return
	var ph: String = G.main.phase
	if ph != _last_phase:
		_last_phase = ph
		if ph == "build":
			if G.map:
				ruins = G.map.survivor_points()
			_groups_left = 1 + (1 if randf() < 0.6 else 0) + G.main.wave / 4
			if G.logi:
				_groups_left += G.logi.radio_count() * Defs.RADIO_GROUPS
			_groups_left += mini(2, safe_houses().size())
			_group_t = randf_range(4.0, 12.0)
			for c in civilians:
				if not c.dead and c.shelter != null:
					c.leave_shelter()
		elif ph == "wave":
			_straggle_t = randf_range(15.0, 35.0)
			_sos_left = 1 + G.main.wave / 3
			_sos_t = randf_range(20.0, 35.0)
			saved_wave = 0
			lost_wave = 0
	if room() <= 0:
		return
	if ph == "build" and _groups_left > 0:
		_group_t -= dt
		if _group_t <= 0.0:
			_groups_left -= 1
			_group_t = randf_range(10.0, 16.0)
			var r: Vector3 = ruins[randi() % ruins.size()]
			var big := mini(randi_range(2, 6) + G.main.wave / 3, room())
			if randf() < 0.5 and r.distance_to(Defs.hq_center()) > 40.0:
				spawn_stranded(r, big)
				if G.hud:
					G.hud.toast("SOS: survivors stuck to the %s. %s" % [_dir_name(r), _rescue_hint()])
			else:
				spawn_group(r, big)
				if G.hud:
					G.hud.toast("Survivors coming from the %s" % _dir_name(r))
	if ph == "wave" and _sos_left > 0:
		_sos_t -= dt
		if _sos_t <= 0.0:
			_sos_left -= 1
			_sos_t = randf_range(25.0, 45.0)
			var far: Array = ruins.filter(func(q): return q.distance_to(Defs.hq_center()) > 35.0)
			if not far.is_empty():
				var r3: Vector3 = far[randi() % far.size()]
				spawn_stranded(r3, mini(randi_range(2, 4) + G.main.wave / 4, room()))
				if G.hud:
					G.hud.toast("SOS to the %s! %s" % [_dir_name(r3), _rescue_hint()])
	if ph == "wave" and _straggle_t > 0.0:
		_straggle_t -= dt
		if _straggle_t <= 0.0:
			var r2: Vector3 = ruins[randi() % ruins.size()]
			var n := mini(randi_range(1, 3), room())
			spawn_group(r2, n)
			var away := r2.normalized()
			var side := Vector3(-away.z, 0, away.x)
			for i in 3:
				var sp := _open_near(r2 + away * randf_range(1.0, 4.0) + side * randf_range(4.0, 7.0) * (1.0 if i % 2 == 0 else -1.0))
				G.zombies.spawn(Defs.Z_WALKER, sp)
			if G.hud:
				G.hud.toast("Survivors in trouble to the %s!" % _dir_name(r2))

func _open_near(p: Vector3) -> Vector3:
	var g: Grid = G.grid
	var c := Defs.world_to_nav(p)
	for r in 9:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if not g.ninb(n):
					continue
				var i := g.nidx(n)
				if g.nblk[i] == Grid.N_OPEN and G.flow.dist[i] < 1.0e+19:
					return Defs.nav_center(n)
	return p

func _arriving() -> int:
	var n := 0
	for c in civilians:
		if not c.dead and not c.owned:
			n += 1
	return n

static func _dir_name(p: Vector3) -> String:
	var a := atan2(p.x, -p.z)
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var k := int(round(a / (PI / 4.0))) % 8
	if k < 0:
		k += 8
	return names[k]
