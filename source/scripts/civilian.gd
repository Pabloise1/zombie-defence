class_name Civilian
extends Person
enum {ARRIVING, IDLE}
var mode := ARRIVING
var owned := false
var home := Vector3.ZERO
var variant := "civilian_a"
var _retry := 0.0
var _stuck := 0.0
var _last := Vector3.ZERO
var waiting := false
var boarding := false
var _board_to := Vector3.INF

func setup(at: Vector3, owned_now: bool) -> void:
	kind = "civilian"
	variant = "civilian_a" if randf() < 0.5 else "civilian_b"
	setup_model(variant, ["idle", "run", "cower"])
	position = at
	owned = owned_now
	speed = 4.3
	if owned:
		mode = IDLE
		home = G.people.home_spot(self)
		walk_to(home, 1)
	else:
		mode = ARRIVING
		_plan_refuge()

func _plan_refuge() -> void:
	var goals: Dictionary = G.people.refuge_goals(position)
	if not walk_to_avoiding(goals):
		walk_to_goals(goals)

func _on_safe() -> void:
	if owned:
		walk_to(home, 1)

func step(dt: float) -> void:
	if dead:
		step_dead(dt)
		return
	_moving = false
	if mode == ARRIVING and (waiting or boarding):
		_stranded_step(dt)
		settle(dt)
		animate(dt)
		return
	if mode == ARRIVING:
		var had: bool = threat != null
		if scan_threat(dt, 10.0) and not had:
			_plan_refuge()
		if not arrived():
			follow(dt, 4.6)
		if G.people.is_safe(position):
			_join()
		else:
			_retry -= dt
			if _retry <= 0.0:
				_retry = 1.5
				if arrived():
					_plan_refuge()
				if arrived() and position.distance_to(_last) < 0.3:
					_stuck += 1.5
					if _stuck > 3.0:
						var p: Vector3 = G.people.nearest_safe_point(position)
						if p != Vector3.INF and p.distance_to(position) < 8.0:
							position = p
							_join()
				else:
					_stuck = 0.0
				_last = position
		anim_mode = "run"
	else:
		scan_threat(dt, 8.0)
		if flee_step(dt):
			settle(dt)
			animate(dt)
			return
		if arrived() and position.distance_to(home) > 1.5:
			walk_to(home, 1)
		if not arrived():
			follow(dt, 2.6)
		anim_mode = "cower" if G.zombies.any_near(position, 7.0) else "idle"
		if _moving:
			anim_mode = "walk"
	settle(dt)
	animate(dt)

func _stranded_step(dt: float) -> void:
	scan_threat(dt, 9.0)
	if boarding:
		if not arrived():
			follow(dt, 4.4)
		anim_mode = "run"
		return
	if threat != null and is_instance_valid(threat) and threat.position.distance_to(position) < 5.0:
		waiting = false
		G.people.leave_group(self)
		_plan_refuge()
		return
	anim_mode = "cower"

func board_at(p: Vector3) -> void:
	if p.distance_to(_board_to) < 0.5 and not arrived():
		return
	_board_to = p
	boarding = true
	waiting = false
	walk_to(p, 1)

func _join() -> void:
	owned = true
	mode = IDLE
	stop()
	home = G.people.home_spot(self)
	walk_to(home, 1)
	G.people.on_joined(self)
