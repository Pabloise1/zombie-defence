class_name Mine
extends Building
var _fuse := -1.0
var _blink := 0.0
var _light: Node3D

func _on_model_ready() -> void:
	_light = model.find_child("Light", true, false) as Node3D

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	_blink += dt
	if _light:
		var fast := _fuse >= 0.0
		var period := 0.12 if fast else 1.0
		_light.visible = fmod(_blink, period) < period * 0.35
	if _fuse < 0.0:
		if G.zombies.any_near(position, 1.4):
			_fuse = 0.18
			if G.sfx:
				G.sfx.play("click", position)
	else:
		_fuse -= dt
		if _fuse <= 0.0:
			explode()

func explode() -> void:
	if state == DEAD:
		return
	var p := position + Vector3(0, 0.3, 0)
	G.zombies.damage_radius(p, Defs.MINE_RADIUS, Defs.MINE_DAMAGE)
	if G.fx:
		G.fx.explosion(p, 1.0)
	if G.cam:
		G.cam.shake(0.7)
	if G.sfx:
		G.sfx.play("mine_explosion", p)
	destroy(false)
