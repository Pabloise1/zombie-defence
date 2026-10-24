class_name FlameBunker
extends Building
var yaw_n: Node3D
var nozzle: Node3D
var jet: CPUParticles3D
var target = null
var _retarget := 0.0
var _tick := 0.0
var firing := false
var _patch_t := 0.0

func _on_model_ready() -> void:
	yaw_n = model.find_child("Yaw", true, false) as Node3D
	nozzle = model.find_child("Nozzle", true, false) as Node3D
	if yaw_n == null:
		yaw_n = model
	if nozzle == null:
		nozzle = Marker3D.new()
		nozzle.position = Vector3(0, 1.1, -1.0)
		yaw_n.add_child(nozzle)
	if G.fx:
		jet = G.fx.make_flame_jet()
		nozzle.add_child(jet)
	yaw_n.rotation.y = rest_yaw

func _apply_rest() -> void:
	if yaw_n:
		yaw_n.rotation.y = rest_yaw

static func flame_life(r: float) -> float:
	var v := 15.0
	var d := 3.0
	var disc := v * v - 2.0 * d * r
	if disc <= 0.0:
		return v / d
	return (v - sqrt(disc)) / d

func has_fuel() -> bool:
	return G.logi == null or G.logi.fuel_near(position)

func card_lines() -> Array:
	var out := super.card_lines()
	if state == BUILT and not has_fuel():
		out.append("NO FUEL. Build a fuel tank within %d m" % int(Defs.FUEL_RANGE))
	return out

func _forward() -> Vector3:
	var f := -nozzle.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		if jet:
			jet.emitting = false
		return
	_retarget -= dt
	var rng := gun_range()
	if not crew_ok() or not has_fuel():
		target = null
	elif target != null and (not target.alive or target.position.distance_squared_to(position) > rng * rng):
		target = null
	if target == null and _retarget <= 0.0 and crew_ok() and has_fuel():
		_retarget = 0.25
		target = G.zombies.nearest(position, rng)
	firing = false
	if target != null:
		var parent := yaw_n.get_parent() as Node3D
		var tpos: Vector3 = target.position
		var lp := parent.global_transform.affine_inverse() * tpos
		var d := lp - yaw_n.position
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - yaw_n.rotation.y, -PI, PI)
		var step := 4.5 * dt
		yaw_n.rotation.y += clampf(diff, -step, step)
		firing = absf(diff) < 0.45 and mag > 0 and reload_t <= 0.0
	if jet and jet.emitting != firing:
		jet.emitting = firing
	if jet:
		var want_life := flame_life(rng)
		if absf(jet.lifetime - want_life) > 0.02:
			jet.lifetime = want_life
	if firing:
		_tick -= dt
		if _tick <= 0.0 and use_round():
			_tick = 0.2
			G.zombies.flame_cone(nozzle.global_position, _forward(), rng, Defs.FLAME_ANGLE, Defs.FLAME_DPS * 0.2)
			_patch_t -= 0.2
			if _patch_t <= 0.0 and G.fx:
				_patch_t = 1.0
				var tip: Vector3 = nozzle.global_position + _forward() * rng * randf_range(0.55, 0.85)
				G.fx.fire_patch(tip, 1.6, 4.0)
			if G.sfx:
				G.sfx.play("flame", position)
