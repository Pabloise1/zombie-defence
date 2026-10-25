class_name FortModule
extends Building
# A 2 m fort block you drag out in rows. Touching modules join up: shared
# walls open out, outer walls get firing slits, and roofs at the same height
# run on as one walkway. Raise a module (or the whole fort) floor by floor up
# to max_levels. Every module has a roof gun slot and one soldier per floor.
const LEVEL_H := 3.0
const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var levels := 1
var raising := false
var raise_progress := 0.0
var _slot_node: Node3D

func _make_model() -> void:
	model = Node3D.new()
	model.name = "Fort"
	add_child(model)
	if mounted.is_empty():
		mounted.append(null)
	_rebuild_visual()

func _concrete() -> bool:
	return kind == "fort_concrete"

func neighbour(d: Vector2i):
	var c := cell + d
	if not G.grid.inb(c):
		return null
	var o = G.grid.occ[G.grid.idx(c)]
	if o is FortModule and is_instance_valid(o) and o.state != DEAD:
		return o
	return null

func _rebuild_visual() -> void:
	for ch in model.get_children():
		ch.queue_free()
	var masks := []
	var par := 0
	for l in levels:
		var m := 0
		for i in 4:
			var n = neighbour(SIDES[i])
			if n != null and n.levels > l and n.state == state:
				m |= 1 << i
		masks.append(m)
	for i in 4:
		var n2 = neighbour(SIDES[i])
		if n2 == null or n2.levels < levels or n2.state != state:
			par |= 1 << i
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = Art.fort_module_mesh(_concrete(), masks, par)
	mi.material_override = null
	mi.set_surface_override_material(0, Art.mat_vc)
	model.add_child(mi)
	_slot_node = Node3D.new()
	_slot_node.name = "RoofSlot1"
	_slot_node.position = Vector3(0, levels * LEVEL_H + 0.25, 0)
	model.add_child(_slot_node)
	if state == BLUEPRINT:
		Art.set_override(model, Art.mat_blueprint)
		Art.set_shadows(model, false)
	for g in mounted:
		if g != null and is_instance_valid(g):
			g.position = global_transform * _slot_node.position if is_inside_tree() else position + _slot_node.position

func _refresh_area() -> void:
	if not is_inside_tree() or state == DEAD:
		return
	_rebuild_visual()
	for d in SIDES:
		var n = neighbour(d)
		if n != null and n != self:
			n._rebuild_visual()

func _on_built() -> void:
	super._on_built()
	_refresh_area()

func _on_destroyed(effects: bool) -> void:
	super._on_destroyed(effects)
	for d in SIDES:
		var n = neighbour(d)
		if n != null:
			n.call_deferred("_rebuild_visual")

func tick(dt: float) -> void:
	super.tick(dt)
	if state == BUILT:
		port_tick(dt)

func _slot_marker(i: int) -> Node3D:
	return _slot_node if i == 0 else null

func slot_count() -> int:
	return 1

func slot_bonus() -> float:
	return float(def.get("slot_bonus", 0.15)) * levels

func capacity() -> int:
	return levels

func soldier_range() -> float:
	return Defs.SOLDIER_RANGE + 3.0 + 1.5 * (levels - 1)

func port_points() -> Array:
	var out := []
	for l in levels:
		for i in 4:
			var n = neighbour(SIDES[i])
			if n != null and n.levels > l:
				continue
			var d: Vector2i = SIDES[i]
			out.append(position + Vector3(d.x * 1.05, l * LEVEL_H + 1.5, d.y * 1.05))
	if out.is_empty():
		out.append(position + Vector3(0, levels * LEVEL_H + 1.2, 0))
	return out

func max_levels() -> int:
	return int(def.get("max_levels", 4))

func raise_cost() -> int:
	return int(def.get("raise_cost", 40)) + 10 * (levels - 1)

func can_raise() -> String:
	if state != BUILT:
		return "Finish it first"
	if raising:
		return "Already going up"
	if levels >= max_levels():
		return "As tall as it goes"
	return ""

func raise_one(pay: bool = true) -> String:
	var why := can_raise()
	if why != "":
		return why
	var c := raise_cost()
	if pay and not G.main.spend(c):
		return "A floor costs %d" % c
	raising = true
	raise_progress = 0.0
	paid += c if pay else 0
	G.workers.add_job(self)
	return ""

# Every module joined to this one that's the same height goes up a floor.
func group() -> Array:
	var seen := {self: true}
	var open := [self]
	var out := []
	while not open.is_empty():
		var m = open.pop_back()
		out.append(m)
		for d in SIDES:
			var n = m.neighbour(d)
			if n != null and not seen.has(n) and n.state == BUILT:
				seen[n] = true
				open.append(n)
	return out

func raise_group_list() -> Array:
	return group().filter(func(m): return m.levels == levels and m.can_raise() == "")

func raise_group() -> String:
	var list := raise_group_list()
	if list.is_empty():
		return can_raise() if can_raise() != "" else "Nothing to raise"
	var total := 0
	for m in list:
		total += m.raise_cost()
	if not G.main.spend(total):
		return "Raising %d modules costs %d" % [list.size(), total]
	for m in list:
		m.raise_one(false)
		m.paid += m.raise_cost()
	return ""

func job_valid() -> bool:
	return super.job_valid() or (raising and state == BUILT and is_inside_tree())

func work(dt: float) -> bool:
	if state == BLUEPRINT:
		return super.work(dt)
	if not raising:
		return true
	raise_progress += dt / maxf(0.5, float(def.get("raise_time", 6.0)))
	if G.fx and randf() < dt * 1.5:
		G.fx.dust(position + Vector3(0, levels * LEVEL_H, 0), 0.6)
	if raise_progress >= 1.0:
		finish_raise()
		return true
	return false

func finish_raise() -> void:
	raising = false
	raise_progress = 0.0
	levels += 1
	var per := float(def.get("hp_per_level", def.get("hp", 700.0)))
	var frac := hp / maxf(1.0, max_hp)
	max_hp = per * levels
	hp = minf(max_hp, max_hp * frac + per)
	_pop = 1.0
	if G.sfx:
		G.sfx.play("build", position)
	_refresh_area()
	if G.buildings:
		G.buildings.changed.emit()

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var joined := group().size()
	var out := ["%d floor%s  ·  joined to %d module%s  ·  roof gun +%d%% range" % [levels, "" if levels == 1 else "s", joined - 1, "" if joined == 2 else "s", int(round(slot_bonus() * 100.0))]]
	var s := "Soldiers at the slits %d/%d" % [occupants.size(), capacity()]
	if not incoming.is_empty():
		s += "  (+%d coming)" % incoming.size()
	out.append(s)
	if raising:
		out.append("Raising a floor: %d%%" % int(raise_progress * 100.0))
	return out

func card_buttons() -> Array:
	if state != BUILT:
		return super.card_buttons()
	var out := []
	if can_raise() == "":
		out.append(["raise", "+ FLOOR %d" % raise_cost(), G.main.supplies >= raise_cost()])
		var list := raise_group_list()
		if list.size() > 1:
			var total := 0
			for m in list:
				total += m.raise_cost()
			out.append(["raise_all", "RAISE ALL %d · %d" % [list.size(), total], G.main.supplies >= total])
	for b in super.card_buttons():
		out.append(b)
	return out
