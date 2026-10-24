class_name StoreyJob
extends Node3D
var block = null
var progress := 0.0
var worker = null
var paid := 0
var done := false
var _ghost: Node3D
var _rise: Node3D
var _scaffold: MeshInstance3D

func setup(b, cost: int) -> void:
	block = b
	paid = cost
	var h: float = RoomBlock.STOREY * b.storeys
	_ghost = Art.model("room_block")
	_ghost.position = Vector3(0, h, 0)
	Art.set_override(_ghost, Art.mat_blueprint)
	Art.set_shadows(_ghost, false)
	add_child(_ghost)
	if b._cap:
		b._cap.position.y = h + RoomBlock.STOREY

func job_goals() -> Dictionary:
	return block.access_goals() if is_instance_valid(block) else {}

func job_valid() -> bool:
	return not done and is_instance_valid(block) and block.state == Building.BUILT and is_inside_tree()

func job_ready() -> bool:
	return true

func job_world_pos() -> Vector3:
	return block.position + Vector3(0, RoomBlock.STOREY * block.storeys + 1.5, 0) if is_instance_valid(block) else global_position

func job_adjacent() -> bool:
	return true

func work(dt: float) -> bool:
	if done:
		return true
	progress += dt / float(block.def.get("floor_time", 16.0))
	_look()
	if progress >= 1.0:
		done = true
		block.finish_floor()
		queue_free()
		return true
	return false

func _look() -> void:
	if _rise == null:
		_rise = Art.model("room_block")
		Art.set_shadows(_rise, false)
		_rise.position = _ghost.position
		add_child(_rise)
		Art.set_override(_ghost, Art.mat_blueprint_faint)
		_scaffold = MeshInstance3D.new()
		_scaffold.mesh = Art.scaffold_mesh(4.0, 4.0, RoomBlock.STOREY + 0.8)
		_scaffold.material_override = Art.mat_vc
		_scaffold.position = _ghost.position
		add_child(_scaffold)
	_rise.scale = Vector3(1.0, lerpf(0.05, 1.0, clampf(progress, 0.0, 1.0)), 1.0)

func cancel() -> void:
	done = true
	if is_instance_valid(block) and block._cap:
		block._cap.position.y = RoomBlock.STOREY * block.storeys
	if is_instance_valid(block):
		block.floor_job = null
		G.main.add_supplies(paid / 2)
	G.workers.remove_job(self)
	queue_free()

func card_title() -> String:
	return "New storey"
