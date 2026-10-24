class_name StairsTower
extends PrefabBuilding

func level_points() -> Array:
	var out := []
	for nm in ["Mid", "Top"]:
		var m := model.find_child(nm, true, false) as Node3D if model else null
		if m:
			out.append(m.global_position)
	if out.is_empty():
		out = [position + Vector3(0, 3.0, 0), position + Vector3(0, 6.0, 0)]
	return out

func bottom_point() -> Vector3:
	var m := model.find_child("Bottom", true, false) as Node3D if model else null
	if m:
		return Vector3(m.global_position.x, 0, m.global_position.z) + (m.global_position - position).normalized() * 0.8
	return global_transform * Vector3(0, 0, 1.6)

func entry_point() -> Vector3:
	return bottom_point()

func access_goals() -> Dictionary:
	var goals: Dictionary = G.grid.point_goals(bottom_point(), 1)
	if goals.is_empty():
		goals = G.grid.ring_goals(G.grid.building_nav_cells(self))
	return goals

func _on_built() -> void:
	super._on_built()
	if G.net:
		G.net.dirty = true

func _on_destroyed(effects: bool) -> void:
	if G.net:
		G.net.dirty = true
	super._on_destroyed(effects)

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var links: int = G.net.links_of(self) if G.net else 0
	return ["Climbs to 3 m and 6 m", "Linked to %d roof%s or walkway%s" % [links, "" if links == 1 else "s", "" if links == 1 else "s"] if links > 0 else "Put it next to a roof or a fortified wall"]
