class_name SalvageSpot
extends Node3D
var scrap := 0
var scrap_max := 0
var fetchers := 0
var _model: Node3D
var _pile: MeshInstance3D

func setup(p: Vector3, model_kind: String, amount: int, yaw: float = INF) -> void:
	position = Vector3(p.x, 0, p.z)
	scrap = amount
	scrap_max = maxi(amount, 1)
	if model_kind != "":
		_model = Art.model(model_kind)
		_model.rotation.y = randf() * TAU if yaw == INF else yaw
		add_child(_model)
	_pile = MeshInstance3D.new()
	_pile.mesh = Art.scrap_pile_mesh()
	_pile.material_override = Art.mat_vc
	add_child(_pile)
	refresh()

func refresh() -> void:
	if _pile:
		var f := clampf(float(scrap) / maxf(1.0, scrap_max), 0.0, 1.0)
		_pile.visible = scrap > 0
		_pile.scale = Vector3.ONE * (0.5 + 0.5 * f)

func take(n: int) -> int:
	var got := mini(n, scrap)
	scrap -= got
	refresh()
	return got

func goals() -> Dictionary:
	for off in [Vector3(0, 0, 2.6), Vector3(2.6, 0, 0), Vector3(-2.6, 0, 0), Vector3(0, 0, -2.6), Vector3(0, 0, 4.0), Vector3(4.0, 0, 0)]:
		var g: Dictionary = G.grid.point_goals(position + off, 1)
		if not g.is_empty():
			return g
	return G.grid.point_goals(position + Vector3(0, 0, 5.0), 2)
