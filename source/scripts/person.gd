class_name Person
extends Node3D
var kind := "person"
var state: int = Building.BUILT
var hp := Defs.PERSON_HP
var max_hp := Defs.PERSON_HP
var dead := false
var speed := 3.4
var path := PackedInt32Array()
var path_i := 0
var model: Node3D
var anim: AnimationPlayer
var anim_mode := "idle"
var _anims := {}
var _limbs := {}
var _face := 0.0
var _moving := false
var _phase := 0.0
var _dead_t := 0.0
var _fire_t := 0.0
const CLIP_SPEED := {"walk": 1.87, "run": 3.85, "carry": 1.25}
var _last_xz := Vector2.ZERO
var _speed_now := 0.0
var _hurt_t := 0.0
var threat = null
var alert_t := 0.0
var fleeing := false
var hiding := false
var hide_door := Vector3.INF
var _aware_t := 0.0
var _calm_t := 0.0
var _bang: Label3D
var _flee_think := 0.0
var air_pts: Array = []
var air_seen: Array = []
var air_i := 0

func setup_model(model_kind: String, clips: Array) -> void:
	if model:
		model.queue_free()
	model = Art.model(model_kind)
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_anims.clear()
	_limbs.clear()
	if anim:
		for n in clips:
			_anims[n] = Art.find_anim(anim, n)
	for n in ["LegL", "LegR", "ArmL", "ArmR"]:
		var nd := model.find_child(n, true, false)
		if nd:
			_limbs[n] = nd

func exposed() -> bool:
	return not dead and visible

func is_built() -> bool:
	return exposed()

func blocks_now() -> bool:
	return false

func edge_distance(p: Vector3) -> float:
	return maxf(0.0, Vector2(p.x - position.x, p.z - position.z).length() - 0.35)

func take_damage(amount: float, _from = null) -> void:
	if not exposed():
		return
	hp -= amount
	_hurt_t = 0.25
	if G.fx:
		G.fx.blood_puff(position + Vector3(0, 1.1, 0))
	if G.sfx:
		G.sfx.play("civilian_scream", position)
	if hp <= 0.0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	state = Building.DEAD
	_on_death()
	if G.fx:
		G.fx.blood(Vector3(position.x, position.y + 0.03, position.z), 0.8)
	if G.sfx:
		G.sfx.play("scream", position)
	if G.people:
		G.people.on_dead(self)

func _on_death() -> void:
	pass

func step_dead(dt: float) -> void:
	_dead_t += dt
	if _bang:
		_bang.visible = false
	model.rotation.x = minf(1.0, _dead_t / 0.5) * PI * 0.48
	if _dead_t > 6.0:
		position.y -= dt * 0.6
	if _dead_t > 7.0:
		queue_free()

func scan_threat(dt: float, r: float) -> bool:
	if alert_t > 0.0:
		alert_t -= dt
		if _bang:
			var k := clampf((1.3 - alert_t) / 0.15, 0.0, 1.0)
			_bang.scale = Vector3.ONE * (0.6 + 0.6 * k - 0.15 * clampf((1.3 - alert_t - 0.15) / 0.2, 0.0, 1.0))
			_bang.modulate.a = clampf(alert_t / 0.3, 0.0, 1.0)
			_bang.visible = alert_t > 0.0
	_aware_t -= dt
	if _aware_t > 0.0 or G.zombies == null:
		return threat != null
	_aware_t = randf_range(0.28, 0.42)
	var zone: int = G.zones.zone_at(position) if G.zones else 0
	var z = G.zombies.nearest_r(position if not hiding else hide_door, r, zone)
	if z != null:
		if threat == null and _calm_t <= 0.0:
			_notice()
		threat = z
		_calm_t = 2.5
	elif threat != null:
		_calm_t -= 0.35
		if _calm_t <= 0.0:
			threat = null
	return threat != null

func _notice() -> void:
	alert_t = 1.3
	if _bang == null:
		_bang = Label3D.new()
		_bang.text = "!"
		_bang.font_size = 120
		_bang.outline_size = 28
		_bang.pixel_size = 0.006
		_bang.modulate = Color(1.0, 0.82, 0.2)
		_bang.outline_modulate = Color(0.12, 0.04, 0.02)
		_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bang.no_depth_test = true
		_bang.fixed_size = false
		_bang.position = Vector3(0, 2.35, 0)
		_bang.font = Hud.font_heavy if Hud.font_heavy else null
		add_child(_bang)
	_bang.visible = true
	if G.sfx:
		G.sfx.play("scream", position)

func flee_step(dt: float) -> bool:
	if hiding:
		if threat == null:
			_come_out()
			return false
		return true
	if not fleeing:
		if threat == null:
			return false
		fleeing = true
		_flee_think = 0.0
		_on_flee()
	if threat == null:
		fleeing = false
		stop()
		return false
	_flee_think -= dt
	if _flee_think <= 0.0:
		_flee_think = 1.2
		if arrived():
			_plan_flight()
	if not arrived():
		follow(dt, maxf(speed * 1.3, 4.2))
	elif hide_door != Vector3.INF and position.distance_to(hide_door) < 1.8:
		hiding = true
		visible = false
		state = Building.DEAD
	anim_mode = "run"
	return true

func _plan_flight() -> void:
	hide_door = Vector3.INF
	if G.people == null:
		return
	var zone: int = G.zones.zone_at(position) if G.zones else 0
	if zone > 0 or G.people.hq_zone() == 0:
		var d: Vector3 = G.people.hide_spot(position, threat)
		if d != Vector3.INF:
			hide_door = d
			walk_to_avoiding(G.grid.point_goals(d, 1))
			return
	walk_to_avoiding(G.people.refuge_goals(position))

func _come_out() -> void:
	hiding = false
	fleeing = false
	visible = true
	state = Building.BUILT
	stop()
	_on_safe()

func _on_flee() -> void:
	pass

func _on_safe() -> void:
	pass

func start_air(pts: Array, seen: Array) -> void:
	air_pts = pts
	air_seen = seen
	air_i = 1
	stop()
	if not pts.is_empty():
		position = pts[0]
	state = Building.DEAD

func air_step(dt: float, spd: float) -> bool:
	if air_i >= air_pts.size():
		return false
	var t: Vector3 = air_pts[air_i]
	var to := t - position
	var d := to.length()
	var step := spd * dt
	if d <= step or d < 0.01:
		position = t
		air_i += 1
	else:
		position += to / d * step
	var flat := Vector3(to.x, 0, to.z)
	if flat.length_squared() > 0.0001:
		_face = atan2(-flat.x, -flat.z)
	_moving = true
	visible = bool(air_seen[mini(air_i, air_seen.size() - 1)]) if not air_seen.is_empty() else true
	rotation.y = lerp_angle(rotation.y, _face, minf(1.0, dt * 10.0))
	return air_i < air_pts.size()

func air_done() -> bool:
	return air_i >= air_pts.size()

func walk_to_goals(goals: Dictionary) -> bool:
	path = PackedInt32Array()
	path_i = 0
	if goals.is_empty():
		return false
	var here: int = G.grid.nidx(_here())
	if goals.has(here):
		return true
	path = G.grid.find_path(position, goals)
	return not path.is_empty()

func walk_to(p: Vector3, radius: int = 1) -> bool:
	return walk_to_goals(G.grid.point_goals(p, radius))

func walk_to_avoiding(goals: Dictionary) -> bool:
	path = PackedInt32Array()
	path_i = 0
	if goals.is_empty():
		return false
	if goals.has(G.grid.nidx(_here())):
		return true
	path = G.grid.find_path(position, goals, 12000, true)
	return not path.is_empty()

func _here() -> Vector2i:
	var n := Defs.world_to_nav(position)
	n.x = clampi(n.x, 0, Defs.NW - 1)
	n.y = clampi(n.y, 0, Defs.NH - 1)
	return n

func passing_through(cells: Dictionary) -> bool:
	if cells.has(G.grid.nidx(_here())):
		return true
	var n := mini(path.size(), path_i + 4)
	for k in range(path_i, n):
		if cells.has(path[k]):
			return true
	return false

func arrived() -> bool:
	return path_i >= path.size()

func stop() -> void:
	path = PackedInt32Array()
	path_i = 0

func follow(dt: float, spd: float = -1.0) -> bool:
	if path_i >= path.size():
		return false
	var t: Vector3 = G.grid.nav_center(G.grid.ncell_of(path[path_i]))
	var to := Vector3(t.x - position.x, 0, t.z - position.z)
	var d := to.length()
	if d < 0.12:
		path_i += 1
		return path_i < path.size()
	var s := speed if spd < 0.0 else spd
	if G.grid.n_trench_i(G.grid.nidx(_here())):
		s *= 0.6
	var mv := to / d * minf(s * dt, d)
	position.x += mv.x
	position.z += mv.z
	_face = atan2(-to.x, -to.z)
	_moving = true
	return true

func face_point(p: Vector3) -> void:
	var to := p - global_position
	if to.length_squared() > 0.0001:
		_face = atan2(-to.x, -to.z)

func settle(dt: float) -> void:
	var fy: float = G.grid.n_floor_y(position)
	position.y = move_toward(position.y, fy, dt * 4.0)
	rotation.y = lerp_angle(rotation.y, _face, minf(1.0, dt * 10.0))

func animate(dt: float) -> void:
	var m := anim_mode
	var xz := Vector2(position.x, position.z)
	var v := xz.distance_to(_last_xz) / maxf(dt, 0.001)
	_last_xz = xz
	_speed_now = lerpf(_speed_now, v if v < 12.0 else 0.0, minf(1.0, dt * 10.0))
	if _moving and m != "run" and m != "carry":
		m = "walk"
	if _moving and m == "walk" and _speed_now > 3.0 and _anims.get("run", "") != "":
		m = "run"
	if _hurt_t > 0.0:
		_hurt_t -= dt
	if anim:
		var want: String = _anims.get(m, "")
		var clip := m
		if want == "":
			for alt in _fallbacks(m):
				want = _anims.get(alt, "")
				if want != "":
					clip = alt
					break
		if want != "" and anim.current_animation != want:
			anim.play(want, 0.15)
		var cs: float = CLIP_SPEED.get(clip, 0.0)
		if kind == "fetcher" and clip == "carry":
			cs = 1.05
		if cs > 0.0 and _moving:
			anim.speed_scale = clampf(_speed_now / cs, 0.4, 2.6)
		else:
			anim.speed_scale = 1.0
		if model:
			model.rotation.x = -_hurt_t * 0.9
		return
	_phase += dt * (11.0 if m == "run" else 9.0)
	var leg := 0.0
	var arm_l := 0.0
	var arm_r := 0.0
	var bob := 0.0
	match m:
		"walk", "carry":
			leg = sin(_phase) * 0.6
			arm_l = -sin(_phase) * 0.45
			arm_r = sin(_phase) * 0.45
			if m == "carry":
				arm_r = -2.6
			bob = absf(sin(_phase)) * 0.05
		"run":
			leg = sin(_phase) * 0.9
			arm_l = -sin(_phase) * 0.8
			arm_r = sin(_phase) * 0.8
			bob = absf(sin(_phase)) * 0.08
		"work":
			arm_r = -0.9 + sin(_phase) * 0.7
			arm_l = -0.6 + sin(_phase) * 0.5
			bob = maxf(0.0, sin(_phase)) * -0.06
		"aim", "fire":
			arm_r = -1.45 + (0.18 if _fire_t > 0.12 else 0.0)
			arm_l = -1.25
		"cower":
			arm_l = -2.4
			arm_r = -2.4
			bob = -0.25
		_:
			arm_l = sin(_phase * 0.15) * 0.05
			arm_r = -arm_l
	if _limbs.has("LegL"):
		_limbs["LegL"].rotation.x = leg
		_limbs["LegR"].rotation.x = -leg
	if _limbs.has("ArmL"):
		_limbs["ArmL"].rotation.x = arm_l
		_limbs["ArmR"].rotation.x = arm_r
	model.position.y = bob

func _fallbacks(m: String) -> Array:
	match m:
		"walk":
			return ["run", "idle"]
		"run":
			return ["walk"]
		"fire":
			return ["aim", "idle"]
		"aim":
			return ["idle"]
		"carry":
			return ["walk"]
		"cower":
			return ["idle"]
		"work":
			return ["idle"]
	return ["idle"]
