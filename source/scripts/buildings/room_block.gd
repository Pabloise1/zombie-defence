class_name RoomBlock
extends PrefabBuilding
const STOREY := 3.0
# One gun ledge per storey, at a window, each storey facing a different side:
# [window position, outward direction] in storey space.
const LEDGES := [
	[Vector3(0, 0, -1.82), Vector3(0, 0, -1)],
	[Vector3(1.82, 0, 0), Vector3(1, 0, 0)],
	[Vector3(-1.82, 0, 0), Vector3(-1, 0, 0)],
	[Vector3(-0.85, 0, 1.82), Vector3(0, 0, 1)],
]
const LEDGE_OUT := 1.05
const LEDGE_Y := 1.0
const ROOF_SLOTS := 2
static var _ledge_mesh: BoxMesh
static var _ledge_mat: StandardMaterial3D
var storeys := 1
var floor_job = null
var _cap: Node3D
var _floor_slots: Array[Node3D] = []

func _make_model() -> void:
	model = Node3D.new()
	model.name = "Stack"
	add_child(model)
	_rebuild_stack()

func _rebuild_stack() -> void:
	for c in model.get_children():
		c.queue_free()
	_floor_slots.clear()
	for i in storeys:
		var b := Art.model("room_block")
		b.name = "Storey%d" % (i + 1)
		b.position = Vector3(0, STOREY * i, 0)
		model.add_child(b)
		var rs := b.find_child("RoofSlot1", true, false)
		if rs:
			rs.name = "BlockSlot"
		_floor_slots.append(_make_ledge(b, i))
	_cap = Art.model("room_block_top")
	_cap.name = "Cap"
	_cap.position = Vector3(0, STOREY * storeys, 0)
	model.add_child(_cap)

func _make_ledge(storey: Node3D, i: int) -> Node3D:
	if _ledge_mesh == null:
		_ledge_mesh = BoxMesh.new()
		_ledge_mesh.size = Vector3(2.3, 0.22, 2.1)
		_ledge_mat = StandardMaterial3D.new()
		_ledge_mat.albedo_color = Color(0.56, 0.55, 0.51)
		_ledge_mat.roughness = 0.9
	var l: Array = LEDGES[i % LEDGES.size()]
	var out: Vector3 = l[1]
	var at: Vector3 = l[0] + out * LEDGE_OUT
	var slab := MeshInstance3D.new()
	slab.name = "Ledge"
	slab.mesh = _ledge_mesh
	slab.material_override = _ledge_mat
	slab.position = Vector3(at.x, LEDGE_Y - 0.11, at.z)
	slab.rotation.y = atan2(-out.x, -out.z)
	storey.add_child(slab)
	var mk := Node3D.new()
	mk.name = "FloorSlot"
	mk.position = Vector3(at.x, LEDGE_Y, at.z)
	mk.rotation.y = atan2(-out.x, -out.z)
	storey.add_child(mk)
	return mk

func roof_height() -> float:
	return STOREY * storeys + 0.1

func deck_height() -> float:
	return STOREY * (storeys - 1) + 3.83 + 0.37

func _slot_marker(i: int) -> Node3D:
	if i >= ROOF_SLOTS:
		var k := i - ROOF_SLOTS
		return _floor_slots[k] if k < _floor_slots.size() else null
	if _cap == null:
		return null
	return _cap.find_child("RoofSlot%d" % (i + 1), true, false) as Node3D

func slot_count() -> int:
	return ROOF_SLOTS + storeys

func _grow_slots() -> void:
	while mounted.size() < slot_count():
		mounted.append(null)

func _take_over(old) -> void:
	if old is RoomBlock and old.storeys != storeys:
		storeys = old.storeys
		max_hp = float(def.get("hp", 3000.0)) * storeys
		_rebuild_stack()
		_grow_slots()
	super._take_over(old)

func capacity() -> int:
	return 4 * storeys

func pop_bonus() -> int:
	return int(def.get("pop", 2)) * storeys

func port_points() -> Array:
	var out := []
	if model == null:
		return out
	for b in model.get_children():
		if not String(b.name).begins_with("Storey"):
			continue
		for k in 4:
			var w := (b as Node3D).find_child("Window%d" % (k + 1), true, false) as Node3D
			if w:
				out.append(w.global_position)
	return out

func perch_for(_s):
	return null

func soldier_range() -> float:
	return (Defs.SOLDIER_RANGE + 3.0) * (1.0 + 0.1 * (storeys - 1))

func entry_point() -> Vector3:
	var d := model.find_child("Door1", true, false) as Node3D if model else null
	if d:
		return Vector3(d.global_position.x, 0, d.global_position.z)
	return global_transform * Vector3(0, 0, half.y + 1.0)

func access_goals() -> Dictionary:
	var goals: Dictionary = G.grid.point_goals(entry_point(), 1)
	if goals.is_empty():
		goals = G.grid.ring_goals(G.grid.building_nav_cells(self))
	return goals

func job_goals() -> Dictionary:
	if state == BLUEPRINT:
		return super.job_goals()
	return access_goals()

func floor_cost() -> int:
	return int(def.get("floor_cost", 100)) + 25 * (storeys - 1)

func can_add_floor() -> String:
	if state != BUILT:
		return "Finish it first"
	if storeys >= int(def.get("max_floors", 4)):
		return "As tall as it goes"
	if floor_job != null and is_instance_valid(floor_job):
		return "A floor is going up already"
	return ""

func add_floor() -> String:
	var why := can_add_floor()
	if why != "":
		return why
	var c := floor_cost()
	if not G.main.spend(c):
		return "A floor costs %d" % c
	var j := StoreyJob.new()
	j.name = "StoreyJob"
	add_child(j)
	j.setup(self, c)
	floor_job = j
	G.workers.add_job(j)
	return ""

func finish_floor() -> void:
	storeys += 1
	floor_job = null
	var frac := hp / maxf(1.0, max_hp)
	max_hp = float(def.get("hp", 3000.0)) * storeys
	hp = max_hp * frac + float(def.get("hp", 3000.0))
	hp = minf(hp, max_hp)
	_rebuild_stack()
	_grow_slots()
	for i in mounted.size():
		var g = mounted[i]
		if g != null and is_instance_valid(g):
			g.position = slot_xform(i).origin
	_pop = 1.0
	if G.fx:
		G.fx.dust(position + Vector3(0, roof_height(), 0), 1.6)
	if G.sfx:
		G.sfx.play("build", position)
	if G.net:
		G.net.dirty = true
	G.buildings.changed.emit()

func _on_built() -> void:
	super._on_built()
	if G.net:
		G.net.dirty = true

func _on_destroyed(effects: bool) -> void:
	if floor_job != null and is_instance_valid(floor_job):
		floor_job.cancel()
	if G.net:
		G.net.dirty = true
	super._on_destroyed(effects)

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var out := ["%d storey%s  ·  +%d people  ·  roof guns +%d%% range" % [storeys, "" if storeys == 1 else "s", pop_bonus(), int(slot_bonus() * 100.0)]]
	var s := "Soldiers at the windows %d/%d" % [occupants.size(), capacity()]
	if not incoming.is_empty():
		s += "  (+%d coming)" % incoming.size()
	out.append(s)
	var free := 0
	for i in mounted.size():
		if mounted[i] == null or not is_instance_valid(mounted[i]):
			free += 1
	out.append("Gun slots %d free of %d  ·  2 on the roof, 1 on each floor" % [free, mounted.size()])
	if floor_job != null and is_instance_valid(floor_job):
		out.append("Building storey %d: %d%%" % [storeys + 1, int(floor_job.progress * 100.0)])
	return out

func card_buttons() -> Array:
	if state != BUILT:
		return super.card_buttons()
	var out := []
	var why := can_add_floor()
	if why == "":
		out.append(["floor", "+ FLOOR %d" % floor_cost(), G.main.supplies >= floor_cost()])
	var idle: int = G.soldiers.idle_count() if G.soldiers else 0
	out.append(["assign", "ASSIGN" if free_slots() > 0 else "FULL", free_slots() > 0 and idle > 0])
	for b in super.card_buttons():
		if b[0] != "assign":
			out.append(b)
	return out
