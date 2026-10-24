class_name GunPlatform
extends Building

func _on_model_ready() -> void:
	mounted = [null]

func slot_count() -> int:
	return 1

func access_goals() -> Dictionary:
	return G.grid.ring_goals(G.grid.building_nav_cells(self))

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var g = mounted[0] if not mounted.is_empty() else null
	if g != null and is_instance_valid(g):
		return ["Carries a %s  ·  +%d%% range" % [g.long_name(), int(slot_bonus() * 100.0)]]
	return ["Empty. Put a gun on top  ·  +%d%% range" % int(slot_bonus() * 100.0)]
