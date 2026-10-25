class_name Cannon
extends Turret
# Autocannon: slow, heavy shells that burst on impact. Goes for brutes first,
# then runners, then whatever is closest.

func _pick_target(rng: float):
	return G.zombies.best_threat(global_position, rng)

func _fire(tp: Vector3) -> void:
	_cd = Defs.CANNON_INTERVAL
	shots += 1
	var from := muzzle.global_position
	var was_alive: bool = target.alive
	var at: Vector3 = target.position
	target.hurt(Defs.CANNON_DAMAGE, from)
	if was_alive and not target.alive:
		kills += 1
	var r2 := Defs.CANNON_SPLASH * Defs.CANNON_SPLASH
	for z in G.zombies.alive_list:
		if z == target or not z.alive:
			continue
		var dx: float = z.position.x - at.x
		var dz: float = z.position.z - at.z
		if dx * dx + dz * dz < r2:
			z.hurt(Defs.CANNON_SPLASH_DAMAGE, at)
			if not z.alive:
				kills += 1
	_recoil = 1.0
	_flash_t = 0.07
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(1.2, 1.6)
	if G.fx:
		G.fx.tracer(from, tp, 1)
		G.fx.hit(tp, (tp - from).normalized(), 1)
		G.fx.dirt(Vector3(at.x, at.y + 0.2, at.z))
	if G.sfx:
		G.sfx.play("sniper", from)
