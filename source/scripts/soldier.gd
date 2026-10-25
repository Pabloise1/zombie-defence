class_name Soldier
extends Person
enum {IDLE, MOVE, INSIDE, PERCH, DEAD, GUARD, RETREAT, HEAL, CLIMB}
const HURT_FRAC := 0.35
const JOG := 3.6
var mode := IDLE
var post = null
var auto_post := false
var home := Vector3.ZERO
var target = null
var cd := 0.0
var _retarget := 0.0
var sector := -1
var guard_spot := Vector3.INF
var heal_at = null
var _regen_t := 0.0
var _climb := {}

func setup(at: Vector3, home_pos: Vector3) -> void:
	kind = "soldier"
	hp = Defs.SOLDIER_HP
	max_hp = Defs.SOLDIER_HP
	speed = 3.2
	position = at
	home = home_pos
	setup_model("soldier", ["idle", "walk", "aim", "fire"])
	cd = randf_range(0.0, 0.6)
	walk_to(home, 1)

func exposed() -> bool:
	return not dead and (mode == IDLE or mode == MOVE or mode == GUARD or mode == RETREAT)

func is_free() -> bool:
	return not dead and (mode == IDLE or mode == GUARD or (mode == MOVE and post == null))

func _on_death() -> void:
	mode = DEAD
	_set_target(null)
	if post and is_instance_valid(post):
		post.soldier_cancelled(self)
	post = null

func _set_target(z) -> void:
	if target == z:
		return
	if target != null and is_instance_valid(target):
		target.aimed = maxi(0, target.aimed - 1)
	target = z
	if z != null:
		z.aimed += 1

func assign(b, by_ai: bool = false) -> bool:
	post = b
	auto_post = by_ai
	if not by_ai:
		sector = -1
	_climb = G.net.route_for(b, position) if G.net else {}
	if not _climb.is_empty() and not _climb.get("ok", false):
		post = null
		auto_post = false
		_climb = {}
		return false
	b.reserve_slot(self)
	mode = MOVE
	visible = true
	state = Building.BUILT
	var dest: Vector3 = _climb["access"] if not _climb.is_empty() else b.entry_point()
	if not walk_to(dest, 2):
		b.soldier_cancelled(self)
		post = null
		auto_post = false
		mode = IDLE
		return false
	return true

func go_idle(from: Vector3) -> void:
	if dead:
		return
	post = null
	auto_post = false
	visible = true
	state = Building.BUILT
	position = Vector3(from.x, G.grid.n_floor_y(from), from.z)
	mode = MOVE
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func leave_post() -> void:
	if post != null and is_instance_valid(post):
		var out: Vector3 = post.entry_point()
		post.soldier_cancelled(self)
		visible = true
		state = Building.BUILT
		position = Vector3(out.x, G.grid.n_floor_y(out), out.z)
	post = null
	auto_post = false
	mode = IDLE
	stop()

func guard(spot: Vector3, sec: int) -> void:
	sector = sec
	guard_spot = spot
	mode = GUARD
	if not walk_to(spot, 1):
		guard_spot = Vector3.INF
		mode = IDLE

func rest() -> void:
	if auto_post:
		leave_post()
	sector = -1
	guard_spot = Vector3.INF
	mode = IDLE
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func step(dt: float) -> void:
	if dead:
		step_dead(dt)
		return
	if mode == HEAL:
		_heal(dt)
		return
	if mode == INSIDE:
		return
	if mode == PERCH and post != null and is_instance_valid(post) and post.host != null:
		position = post.crew_spot()
	_moving = false
	if exposed() and mode != RETREAT and hp < max_hp * HURT_FRAC:
		_retreat()
	match mode:
		MOVE:
			follow(dt, JOG)
			if arrived():
				if not _climb.is_empty() and post != null and is_instance_valid(post):
					mode = CLIMB
					start_air(_climb["points"], _climb["seen"])
					_climb = {}
				else:
					_arrive()
		CLIMB:
			if not air_step(dt, JOG * 0.8):
				visible = true
				_arrive()
			_fire_t = maxf(0.0, _fire_t - dt)
			anim_mode = "idle"
			animate(dt)
			return
		RETREAT:
			follow(dt, JOG)
			if arrived():
				_start_heal()
		GUARD:
			var close: bool = target != null and is_instance_valid(target) and target.alive and target.position.distance_to(position) < 7.0
			if not arrived() and not close:
				follow(dt, JOG)
			_shoot(dt)
			if target == null and arrived() and G.soldiers:
				var c: Vector3 = G.soldiers.sector_focus(sector)
				if c != Vector3.INF:
					face_point(c)
		IDLE:
			if position.distance_to(home) > 1.5 and arrived():
				walk_to(home, 1)
			if not arrived():
				follow(dt)
			_shoot(dt)
	if mode == IDLE or mode == MOVE or mode == GUARD or mode == RETREAT:
		settle(dt)
	else:
		rotation.y = lerp_angle(rotation.y, _face, minf(1.0, dt * 10.0))
	_regen_t -= dt
	if _regen_t <= 0.0:
		_regen_t = 1.0
		if target == null and hp < max_hp:
			hp = minf(max_hp, hp + 1.0)
	_fire_t = maxf(0.0, _fire_t - dt)
	if _fire_t > 0.0:
		anim_mode = "fire"
	elif target != null or mode == PERCH or (mode == GUARD and arrived()):
		anim_mode = "aim"
	else:
		anim_mode = "idle"
	animate(dt)

func _arrive() -> void:
	if post != null and is_instance_valid(post) and post.state == Building.BUILT:
		if post.soldier_arrived(self):
			if post.kind == "sniper":
				mode = PERCH
				state = Building.DEAD
				var perch := post.model.find_child("Perch", true, false) as Node3D
				global_position = perch.global_position if perch else post.position + Vector3(0, 4.3, 0)
				return
			var spot = post.perch_for(self)
			if spot != null:
				mode = PERCH
				state = Building.DEAD
				global_position = spot
			else:
				mode = INSIDE
				state = Building.DEAD
				visible = false
			return
	post = null
	auto_post = false
	mode = IDLE
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func _retreat() -> void:
	if G.hud and G.main and not G.main.test_mode:
		G.hud.event("soldier_hurt", "A soldier's hurt: falling back to heal", 10.0)
	if auto_post:
		leave_post()
	_set_target(null)
	sector = -1
	mode = RETREAT
	heal_at = null
	var best_d := INF
	for b in G.buildings.built_of("barracks"):
		var d: float = b.position.distance_to(position)
		if d < best_d:
			best_d = d
			heal_at = b
	var door: Vector3 = heal_at.entry_point() if heal_at != null else Defs.hq_center() + Vector3(0, 0, 3.8)
	if not walk_to_avoiding(G.grid.point_goals(door, 1)):
		walk_to(door, 2)

func _start_heal() -> void:
	mode = HEAL
	visible = false
	state = Building.DEAD

func _heal(dt: float) -> void:
	var rate := 18.0 if heal_at != null and is_instance_valid(heal_at) else 9.0
	hp = minf(max_hp, hp + rate * dt)
	if hp >= max_hp:
		visible = true
		state = Building.BUILT
		mode = IDLE
		if G.people:
			home = G.people.home_spot(self)
		walk_to(home, 1)

func _shoot(dt: float) -> void:
	cd -= dt
	_retarget -= dt
	var r := Defs.SOLDIER_RANGE
	if target != null and (not is_instance_valid(target) or not target.alive or target.position.distance_squared_to(position) > r * r):
		_set_target(null)
	if _retarget <= 0.0:
		_retarget = randf_range(0.3, 0.45)
		var best = G.soldiers.pick_target(position, r, target) if G.soldiers else G.zombies.nearest(position, r)
		_set_target(best)
	if target == null:
		return
	face_point(target.position)
	var fwd := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	var to: Vector3 = target.position - position
	to.y = 0.0
	var facing := to.length_squared() < 0.01 or fwd.dot(to.normalized()) > 0.9
	if cd <= 0.0 and not _moving and facing:
		cd = Defs.SOLDIER_INTERVAL * randf_range(0.85, 1.15)
		fire_at(target, G.soldiers.damage())

func fire_at(z, dmg: float, snd: String = "rifle") -> void:
	var tp: Vector3 = z.aim_point() + Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), randf_range(-0.15, 0.15))
	var from := gun_tip(tp)
	z.hurt(dmg, from)
	_fire_t = 0.22
	if G.fx:
		var heavy := snd == "sniper"
		G.fx.tracer(from, tp, 2 if heavy else 1)
		G.fx.flash(from, 1.4 if heavy else 0.9)
		G.fx.hit(tp, (tp - from).normalized(), 2 if heavy else 1)
	if G.sfx:
		G.sfx.play(snd, from)

func gun_tip(toward: Vector3 = Vector3.INF) -> Vector3:
	var fwd := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	if toward != Vector3.INF:
		var d := Vector3(toward.x - global_position.x, 0, toward.z - global_position.z)
		if d.length_squared() > 0.01:
			fwd = d.normalized()
	return global_position + Vector3(0, 1.42, 0) + fwd * 0.75 + Vector3(-fwd.z, 0, fwd.x) * 0.1
