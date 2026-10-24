class_name Loader
extends Person
enum {IDLE, SERVE, FETCH_GO, FETCH_CARRY, FILL_GO, FILL_CARRY}
var mode := IDLE
var gun = null
var src = null
var dest = null
var crewing = null
var home := Vector3.ZERO
var crate: Node3D
var _wait_t := 0.0
var _climb := {}
var _climbing := false

func setup(at: Vector3) -> void:
	kind = "loader"
	speed = 3.6
	position = at
	setup_model("loader", ["idle", "walk", "carry"])
	crate = Art.model("ammo_crate")
	crate.position = Vector3(0.18, 1.55, 0.02)
	crate.visible = false
	add_child(crate)
	go_home()

func go_home() -> void:
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func exposed() -> bool:
	return not dead and visible and crewing == null

func release() -> void:
	if crewing != null and is_instance_valid(crewing):
		var out: Vector3 = crewing.entry_point()
		position = Vector3(out.x, G.grid.n_floor_y(out), out.z)
	crewing = null
	if gun != null and is_instance_valid(gun) and gun.loader == self:
		gun.loader = null
	if G.people:
		G.people.unclaim(gun)
		G.people.unclaim(dest)
	gun = null
	src = null
	dest = null
	crate.visible = false
	if not dead:
		state = Building.BUILT

func serve(g) -> bool:
	release()
	_climb = G.net.route_for(g, position) if G.net else {}
	if not _climb.is_empty() and not _climb.get("ok", false):
		_climb = {}
		return false
	gun = g
	mode = SERVE
	var goals: Dictionary = g.access_goals() if _climb.is_empty() else G.grid.point_goals(_climb["access"], 1)
	if not walk_to_goals(goals):
		gun = null
		mode = IDLE
		return false
	return true

func fetch(g) -> bool:
	var s = G.logi.nearest_with_crates(g.position) if G.logi else null
	if s == null:
		return false
	release()
	gun = g
	src = s
	G.people.claim(g, self)
	mode = FETCH_GO
	if not walk_to_goals(_store_goals(s)):
		release()
		mode = IDLE
		return false
	return true

func fill(ap) -> bool:
	var s = G.logi.nearest_with_crates(ap.position, ap) if G.logi else null
	if s == null or s is SupplyDevice:
		return false
	release()
	dest = ap
	src = s
	G.people.claim(ap, self)
	mode = FILL_GO
	if not walk_to_goals(_store_goals(s)):
		release()
		mode = IDLE
		return false
	return true

func _store_goals(s) -> Dictionary:
	if s.has_method("access_goals"):
		return s.access_goals()
	return G.grid.ring_goals(G.grid.building_nav_cells(s))

func is_free() -> bool:
	return mode == IDLE

func _on_death() -> void:
	release()

func _on_flee() -> void:
	if crate.visible and G.logi:
		G.logi.add_crates(1, position)
	release()
	mode = IDLE

func _on_safe() -> void:
	go_home()

static func trip_safe(from: Vector3, to: Vector3) -> bool:
	if G.zombies == null:
		return true
	if G.zombies.count_near(to, 16.0) > 0:
		return false
	return G.zombies.danger_on_line(from, to) < 1.5

func _abort() -> void:
	release()
	mode = IDLE
	go_home()

func step(dt: float) -> void:
	if dead:
		step_dead(dt)
		return
	_moving = false
	if crewing == null:
		scan_threat(dt, 7.0)
		if flee_step(dt):
			settle(dt)
			animate(dt)
			return
	if gun != null and (not is_instance_valid(gun) or gun.state != Building.BUILT):
		_abort()
	if dest != null and (not is_instance_valid(dest) or dest.state != Building.BUILT):
		_abort()
	match mode:
		SERVE:
			if gun != null and gun.zone == 0 and gun.host == null:
				_abort()
			elif crewing != null:
				position = crewing.crew_spot()
			elif _climbing:
				if not air_step(dt, 3.0):
					_climbing = false
					visible = true
					_climb = {}
			elif not arrived():
				follow(dt)
			elif not _climb.is_empty():
				_climbing = true
				start_air(_climb["points"], _climb["seen"])
			elif gun != null:
				gun.loader = self
				if gun.host != null:
					crewing = gun
					state = Building.DEAD
					position = gun.crew_spot()
				face_point(gun.position)
		FETCH_GO, FILL_GO:
			if G.main.phase != "build" and G.main.phase != "wave":
				_abort()
			elif not arrived():
				follow(dt)
			elif src == null or not is_instance_valid(src) or not G.logi.take_crate(src):
				_abort()
			else:
				crate.visible = true
				var goals: Dictionary = gun.access_goals() if mode == FETCH_GO else G.grid.ring_goals(G.grid.building_nav_cells(dest))
				mode = FETCH_CARRY if mode == FETCH_GO else FILL_CARRY
				if not walk_to_goals(goals):
					G.logi.add_crates(1, position)
					_abort()
		FETCH_CARRY, FILL_CARRY:
			var to: Vector3 = gun.position if mode == FETCH_CARRY and gun != null else (dest.position if dest != null else position)
			if G.main.phase != "build" and G.main.phase != "wave":
				G.logi.add_crates(1, position)
				_abort()
			elif not arrived() and G.zombies and G.zombies.count_near(to, 12.0) > 0:
				_wait_t += dt
				if _wait_t > 6.0:
					_wait_t = 0.0
					if not walk_to_avoiding(gun.access_goals() if mode == FETCH_CARRY else G.grid.ring_goals(G.grid.building_nav_cells(dest))):
						G.logi.add_crates(1, position)
						_abort()
			elif not arrived():
				_wait_t = 0.0
				follow(dt, 3.0)
			else:
				if mode == FETCH_CARRY:
					gun.restock()
				else:
					dest.crates = mini(dest.store_cap(), dest.crates + 1)
				if G.sfx:
					G.sfx.play("impact_metal", position)
				_abort()
		_:
			if not arrived():
				follow(dt)
	anim_mode = "carry" if crate.visible else "idle"
	if crewing == null and not _climbing:
		settle(dt)
	else:
		rotation.y = lerp_angle(rotation.y, _face, minf(1.0, dt * 10.0))
	animate(dt)
