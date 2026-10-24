class_name WireBarrier
extends Building
var _t := 0.0

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	return ["Slows zombies  ·  %d%% left" % int(hp / max_hp * 100.0)]

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var n: int = G.zombies.count_cell(cell)
	if n > 0:
		if G.sfx and randf() < 0.4:
			G.sfx.play("wire_rattle", position)
		take_damage(Defs.WIRE_WEAR * 0.5 * n)
