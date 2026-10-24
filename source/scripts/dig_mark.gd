class_name DigMark
extends Node3D
var cell := Vector2i.ZERO
var progress := 0.0
var worker = null
var order := 0
var paid := 0
var done := false
var _marker: MeshInstance3D
var _dirt_t := 0.0

func init_mark(c: Vector2i) -> void:
	cell = c
	position = Defs.cell_center(c)
	_marker = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(Defs.CELL * 0.98, Defs.CELL * 0.98)
	_marker.mesh = q
	_marker.material_override = Art.mat_dig_mark
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.position.y = 0.03
	add_child(_marker)

func display_name() -> String:
	return "Dig"

func job_adjacent() -> bool:
	return true

func job_cell() -> Vector2i:
	return cell

func job_valid() -> bool:
	return not done and is_inside_tree()

func job_world_pos() -> Vector3:
	return position

func work(dt: float) -> bool:
	if done:
		return true
	progress += dt / float(Defs.BUILD["dig"]["time"])
	_dirt_t -= dt
	if _dirt_t <= 0.0:
		_dirt_t = 0.45
		if G.fx:
			G.fx.dirt(position + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5)))
	if progress >= 1.0:
		_complete()
		return true
	return false

func _complete() -> void:
	done = true
	var i: int = G.grid.idx(cell)
	G.grid.digs[i] = null
	G.grid.set_trench(cell)
	if G.terrain:
		G.terrain.cell_changed(cell)
	if G.main and G.main.decor:
		G.main.decor.clear_cell(cell)
	if G.fx:
		G.fx.dust(position + Vector3(0, -0.4, 0), 1.0)
	if G.buildings:
		G.buildings.on_dig_removed(self)
	queue_free()

func cancel() -> void:
	done = true
	var i: int = G.grid.idx(cell)
	if G.grid.digs[i] == self:
		G.grid.digs[i] = null
	queue_free()

func job_goals() -> Dictionary:
	var cells := PackedInt32Array()
	for n in G.grid.build_to_nav_cells(cell):
		cells.append(G.grid.nidx(n))
	return G.grid.ring_goals(cells)
