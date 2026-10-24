class_name RoofBridge
extends Building
var pa := Vector3.ZERO
var pb := Vector3.ZERO
var end_a = null
var end_b = null
var length := 1.0

func setup_bridge(a: Vector3, b: Vector3, ra, rb, blueprint: bool) -> void:
	kind = "bridge"
	def = Defs.BUILD["bridge"]
	pa = a
	pb = b
	end_a = ra
	end_b = rb
	length = maxf(0.5, Vector2(b.x - a.x, b.z - a.z).length())
	max_hp = 1.0
	hp = 1.0
	size = 1
	position = Vector3(a.x, 0, a.z)
	model = Node3D.new()
	model.name = "Pieces"
	add_child(model)
	var n := maxi(1, int(ceil(length / 6.0)))
	var each := length / n
	var dirv := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var yaw := atan2(-dirv.z, dirv.x)
	var rise := (b.y - a.y)
	for i in n:
		var m := Art.model("roof_bridge")
		var t0 := float(i) / n
		var p0 := a.lerp(b, t0)
		m.position = p0 - position
		m.rotation = Vector3(0, yaw, atan2(rise, length))
		m.scale = Vector3(each / 4.0, 1, 1)
		model.add_child(m)
	if blueprint:
		_as_blueprint()
	else:
		_finish(true)

func cells() -> Array[Vector2i]:
	return []

func blocks_now() -> bool:
	return false

func has_health() -> bool:
	return false

func job_adjacent() -> bool:
	return false

func job_goals() -> Dictionary:
	var mid := pa.lerp(pb, 0.5)
	var goals: Dictionary = G.grid.point_goals(Vector3(mid.x, 0, mid.z), 3)
	if goals.is_empty():
		goals = G.grid.point_goals(Vector3(pa.x, 0, pa.z), 3)
	return goals

func job_world_pos() -> Vector3:
	return pa.lerp(pb, 0.5)

func work(dt: float) -> bool:
	if state != BLUEPRINT:
		return true
	progress += dt / maxf(1.0, float(def.get("time_per_m", 1.0)) * length)
	if progress >= 1.0:
		_finish(false)
		return true
	build_look()
	return false

func _rise_model() -> Node3D:
	return model.duplicate() as Node3D

func _make_scaffold() -> MeshInstance3D:
	return null

func _on_built() -> void:
	if G.net:
		G.net.dirty = true

func tick(dt: float) -> void:
	super.tick(dt)
	if state == DEAD:
		return
	for e in [end_a, end_b]:
		if e != null and (not is_instance_valid(e) or e.state == DEAD):
			destroy(true)
			return

func _on_destroyed(_effects: bool) -> void:
	if G.net:
		G.net.dirty = true

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	return ["%.0f m walkway up high" % length, "Soldiers and loaders cross it"]

func card_buttons() -> Array:
	if state != BUILT:
		return super.card_buttons()
	var refund := int(round(paid * Defs.REFUND_BUILT))
	return [["sell", "REMOVE +%d" % refund, true]]
