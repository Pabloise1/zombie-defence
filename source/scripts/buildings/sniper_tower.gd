class_name SniperTower
extends Building
var target = null
var _retarget := 0.0
var _cd := 1.0
var shots := 0
var kills := 0

func entry_point() -> Vector3:
	if host != null:
		return super.entry_point()
	return global_transform * Vector3(0, 0, 1.6)

func card_lines() -> Array:
	var out := super.card_lines()
	if state == BUILT and not occupants.is_empty():
		out.append("Range %d m  ·  %d kills" % [int(gun_range()), kills])
	return out

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT or occupants.is_empty():
		return
	var s = occupants[0]
	if not is_instance_valid(s):
		occupants.clear()
		return
	_cd -= dt
	_retarget -= dt
	var rng := gun_range()
	if target != null and (not target.alive or target.position.distance_squared_to(position) > rng * rng):
		target = null
	if _retarget <= 0.0:
		_retarget = 0.5
		target = G.zombies.best_threat(position, rng)
	if target == null:
		s.target = null
		return
	s.target = target
	s.face_point(target.position)
	if _cd <= 0.0 and use_round():
		_cd = Defs.SNIPER_INTERVAL
		shots += 1
		var was_alive: bool = target.alive
		s.fire_at(target, Defs.SNIPER_DAMAGE, "sniper")
		if was_alive and not target.alive:
			kills += 1
