class_name MortarPit
extends Building
var yaw_n: Node3D
var tube: Node3D
var muzzle: Node3D
var reload := 1.5
var _aim := Vector3.INF
var _tube_rest := 0.0
var _kick := 0.0
var shots := 0

func _on_model_ready() -> void:
	yaw_n = model.find_child("Yaw", true, false) as Node3D
	tube = model.find_child("Tube", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	if yaw_n == null:
		yaw_n = model
	if tube:
		_tube_rest = tube.rotation.x
	if muzzle == null:
		muzzle = Marker3D.new()
		muzzle.position = Vector3(0, 1.0, -0.4)
		yaw_n.add_child(muzzle)
	yaw_n.rotation.y = rest_yaw

func _apply_rest() -> void:
	if yaw_n:
		yaw_n.rotation.y = rest_yaw

func reload_frac() -> float:
	return clampf(1.0 - reload / Defs.MORTAR_RELOAD, 0.0, 1.0)

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var r := "Ready" if reload <= 0.0 else "Reloading  %.1f s" % reload
	var out := ["Range %d-%d m  ·  %s" % [int(Defs.MORTAR_MIN), int(gun_range()), r]]
	if host != null:
		out = super.card_lines() + out
	return out

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	reload -= dt
	if _kick > 0.0:
		_kick = maxf(0.0, _kick - dt * 3.0)
	if tube:
		tube.rotation.x = _tube_rest - _kick * 0.12
	if reload > 0.0 or not crew_ok():
		return
	if _aim == Vector3.INF:
		var rng := gun_range()
		_aim = G.zombies.best_cluster(position, Defs.MORTAR_MIN, rng, 1.8 + 0.03 * rng)
		if _aim == Vector3.INF:
			reload = 0.4
			return
	var parent := yaw_n.get_parent() as Node3D
	var lp := parent.global_transform.affine_inverse() * _aim
	var d := lp - yaw_n.position
	var want := atan2(-d.x, -d.z)
	var diff := wrapf(want - yaw_n.rotation.y, -PI, PI)
	var step := 3.5 * dt
	yaw_n.rotation.y += clampf(diff, -step, step)
	if absf(diff) < 0.06:
		if use_round():
			_fire()
		else:
			reload = 0.3

func _fire() -> void:
	var from := muzzle.global_position
	var to := _aim
	_aim = Vector3.INF
	reload = Defs.MORTAR_RELOAD
	shots += 1
	_kick = 1.0
	if G.fx:
		var flight: float = G.fx.mortar_shell(from, to)
		if G.sfx:
			G.sfx.play_delayed("mortar_whistle", to, maxf(0.0, flight - 1.6))
		G.fx.flash(from, 1.6)
		G.fx.dust(from + Vector3(0, 0.2, 0), 0.6)
	if G.sfx:
		G.sfx.play("mortar", from)
