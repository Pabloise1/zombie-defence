class_name WallNest
extends Building
var line_dir := Vector3.RIGHT
var wall_kind := "wall"

func setup_nest(p: Vector3, d: Vector3, wk: String, blueprint: bool) -> void:
	kind = "nest"
	def = Defs.BUILD["nest"]
	wall_kind = wk
	line_dir = d
	size = 1
	max_hp = 1.0
	hp = 1.0
	var wd: Dictionary = Defs.BUILD[wk]
	var top := float(wd.get("nest_h", wd.get("height", 2.2)))
	position = Vector3(p.x, top, p.z)
	rotation.y = atan2(-d.z, d.x)
	if wd.has("nest_in"):
		position += inward() * float(wd["nest_in"])
	model = Art.model("wall_mount_nest")
	add_child(model)
	mounted = [null]
	if blueprint:
		_as_blueprint()
	else:
		_finish(true)

func slot_count() -> int:
	return 1

func slot_bonus() -> float:
	return float(Defs.BUILD[wall_kind].get("slot_bonus", 0.25))

func cells() -> Array[Vector2i]:
	return []

func blocks_now() -> bool:
	return false

func has_health() -> bool:
	return false

func inward() -> Vector3:
	var n := Vector3(-line_dir.z, 0, line_dir.x)
	var p := Vector3(position.x, 0, position.z)
	if G.zones:
		if G.zones.zone_at(p + n * 1.3) > 0:
			return n
		if G.zones.zone_at(p - n * 1.3) > 0:
			return -n
	return n if (Defs.hq_center() - p).dot(n) > 0.0 else -n

func inner_zone() -> int:
	if G.zones == null:
		return 0
	return G.zones.zone_at(Vector3(position.x, 0, position.z) + inward() * 1.3)

func access_goals() -> Dictionary:
	return G.grid.point_goals(Vector3(position.x, 0, position.z) + inward() * 1.4, 1)

func entry_point() -> Vector3:
	return Vector3(position.x, 0, position.z) + inward() * 1.4

func job_goals() -> Dictionary:
	return access_goals()

func edge_distance(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()

func supported() -> bool:
	if G.walls == null:
		return false
	var s = G.walls.segment_at(Vector3(position.x, 0, position.z), 0.6)
	return s != null and s.kind != "gate" and s.state == BUILT

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var g = mounted[0] if not mounted.is_empty() else null
	if g != null and is_instance_valid(g):
		return ["Holds a %s  ·  +%d%% range" % [g.long_name(), int(slot_bonus() * 100.0)]]
	return ["Empty nest. Put a gun in it"]

func card_buttons() -> Array:
	if state == BLUEPRINT:
		return [["sell", "CANCEL +%d" % paid, true]]
	var out := []
	if free_slot() >= 0:
		out.append(["slot", "ADD GUN", true])
	out.append(["sell", "REMOVE +%d" % int(round(paid * Defs.REFUND_BUILT)), true])
	return out
