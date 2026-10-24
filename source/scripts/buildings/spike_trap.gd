class_name SpikeTrap
extends Building
var _timer := 0.0
var _spikes: Node3D
var _rest_y := 0.0
var _jab := 0.0

func _on_model_ready() -> void:
	_spikes = model.find_child("Spikes", true, false) as Node3D
	if _spikes:
		_rest_y = _spikes.position.y

func damage_per_hit() -> float:
	return Defs.SPIKE_DAMAGE * (2.0 if in_trench else 1.0)

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	_timer -= dt
	if _timer <= 0.0:
		_timer = Defs.SPIKE_INTERVAL
		var n: int = G.zombies.damage_cell(cell, damage_per_hit())
		if n > 0:
			_jab = 1.0
			if G.sfx:
				G.sfx.play("spike", position)
	if _spikes:
		_jab = maxf(0.0, _jab - dt * 5.0)
		_spikes.position.y = _rest_y - 0.12 + 0.16 * _jab
