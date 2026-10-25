class_name Turret
extends Building
var yaw_n: Node3D
var barrel: Node3D
var muzzle: Node3D
var _barrel_rest := Vector3.ZERO
var target = null
var _retarget := 0.0
var _cd := 0.0
var _recoil := 0.0
var _flash: MeshInstance3D
var _flash_t := 0.0
var _casings: CPUParticles3D
var _firing_t := 0.0
var _idle_t := 0.0
var shots := 0
var kills := 0

func _on_model_ready() -> void:
	yaw_n = model.find_child("Yaw", true, false) as Node3D
	barrel = model.find_child("Barrel", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D
	if yaw_n == null:
		yaw_n = model
	if muzzle == null:
		muzzle = Marker3D.new()
		muzzle.position = Vector3(0, 1.0, -1.2)
		yaw_n.add_child(muzzle)
	if barrel != null:
		_barrel_rest = barrel.position
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.65, 0.65)
	_flash.mesh = q
	_flash.material_override = Art.mat_muzzle
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	muzzle.add_child(_flash)
	_casings = G.fx.make_casings() if G.fx else null
	if _casings:
		yaw_n.add_child(_casings)
		_casings.position = Vector3(0.25, 0.1, 0.0)
	yaw_n.rotation.y = rest_yaw

func _apply_rest() -> void:
	if yaw_n:
		yaw_n.rotation.y = rest_yaw

func _restore_overrides() -> void:
	if _flash:
		_flash.material_override = Art.mat_muzzle

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	_cd -= dt
	_retarget -= dt
	var rng := gun_range()
	if not crew_ok():
		target = null
	elif target != null and (not target.alive or target.global_position.distance_squared_to(global_position) > rng * rng):
		target = null
	if crew_ok() and (target == null or _retarget <= 0.0):
		_retarget = 0.2
		target = _pick_target(rng)
	if target != null:
		var tp: Vector3 = target.aim_point()
		var parent := yaw_n.get_parent() as Node3D
		var lp := parent.global_transform.affine_inverse() * tp
		var d := lp - yaw_n.position
		var want := atan2(-d.x, -d.z)
		var diff := wrapf(want - yaw_n.rotation.y, -PI, PI)
		var step := 7.0 * dt
		yaw_n.rotation.y += clampf(diff, -step, step)
		if absf(diff) < 0.18 and _cd <= 0.0 and use_round():
			_fire(tp)
		_idle_t = 0.0
	else:
		_idle_t += dt
		var want_r := rest_yaw + sin(_idle_t * 0.6) * 0.35
		yaw_n.rotation.y = lerp_angle(yaw_n.rotation.y, want_r, minf(1.0, dt * 1.5))
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - dt * 9.0)
		if barrel:
			barrel.position = _barrel_rest + Vector3(0, 0, _recoil * 0.09)
	if _flash_t > 0.0:
		_flash_t -= dt
		if _flash_t <= 0.0:
			_flash.visible = false
	if _firing_t > 0.0:
		_firing_t -= dt
		if _firing_t <= 0.0 and _casings:
			_casings.emitting = false

func _pick_target(rng: float):
	return G.zombies.nearest(global_position, rng)

func _fire(tp: Vector3) -> void:
	_cd = 1.0 / Defs.TURRET_RATE
	shots += 1
	var from := muzzle.global_position
	var spread := Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
	var hit_pos := tp + spread
	var was_alive: bool = target.alive
	target.hurt(Defs.TURRET_DAMAGE, from)
	if was_alive and not target.alive:
		kills += 1
	_recoil = 1.0
	_flash_t = 0.045
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	var s := randf_range(0.7, 1.15)
	_flash.scale = Vector3(s, s, s)
	_firing_t = 0.25
	if _casings and not _casings.emitting:
		_casings.emitting = true
	if G.fx:
		G.fx.tracer(from, hit_pos, 0)
		G.fx.hit(hit_pos, (hit_pos - from).normalized(), 0)
	if G.sfx:
		G.sfx.play("shot", from)
