class_name Rubble
extends Node3D
var kind := "wall"
var a := Vector3.ZERO
var b := Vector3.ZERO
var ported := false
var length := 1.0
var dir := Vector3.RIGHT
var rebuild_segs: Array = []
var made_at := 0.0

func setup(k: String, pa: Vector3, pb: Vector3, with_ports: bool) -> void:
	kind = k
	a = Vector3(pa.x, 0, pa.z)
	b = Vector3(pb.x, 0, pb.z)
	ported = with_ports
	length = maxf(0.05, a.distance_to(b))
	dir = (b - a) / length
	position = (a + b) * 0.5
	made_at = G.sim_time
	_build_visual()

func _build_visual() -> void:
	var d: Dictionary = Defs.BUILD.get(kind, Defs.BUILD["wall"])
	var ang := atan2(-dir.z, dir.x)
	var h := float(d.get("height", 2.2))
	var hard := kind == "concrete" or kind == "gate" or kind == "brickwall"
	var col := Color(0.52, 0.5, 0.47) if hard else Color(0.42, 0.31, 0.2)
	if kind == "hedge":
		col = Color(0.24, 0.32, 0.15)
	var mname := String(d.get("model", "wall"))
	if kind == "gate":
		mname = "concrete_wall"
	var n := maxi(1, roundi(length / Defs.WALL_PIECE))
	var pl := length / n
	var stub_h := clampf(0.55 / maxf(h, 0.5), 0.12, 0.45)
	for i in n:
		var m := Art.model(mname)
		m.position = a - position + dir * (pl * (i + 0.5))
		m.rotation.y = ang
		var s := stub_h * randf_range(0.55, 1.35)
		m.scale = Vector3(pl / Defs.WALL_PIECE * randf_range(0.85, 0.98), s, randf_range(0.9, 1.05))
		m.rotation.z = randf_range(-0.06, 0.06)
		Art.set_override(m, Art.rubble_mat(hard, kind == "hedge"))
		Art.set_shadows(m, false)
		add_child(m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Art.rubble_chunk()
	var count := int(clampf(length * 3.5, 4.0, 40.0))
	mm.instance_count = count
	var side := Vector3(-dir.z, 0, dir.x)
	for i in count:
		var t := randf_range(-0.5, 0.5) * length
		var off := randf_range(-1.3, 1.3)
		var sz := randf_range(0.18, 0.5) if hard else randf_range(0.12, 0.38)
		var basis := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		var sc := Vector3(sz, sz * randf_range(0.4, 0.9), sz * (randf_range(2.5, 5.0) if not hard else randf_range(0.7, 1.4)))
		basis = basis.scaled(sc)
		var p := dir * t + side * off * absf(off) * 0.8
		p.y = sc.y * 0.3
		mm.set_instance_transform(i, Transform3D(basis, p))
		var v := randf_range(0.75, 1.15)
		mm.set_instance_color(i, Color(col.r * v, col.g * v, col.b * v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Art.mat_vc
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func display_name() -> String:
	return "Rubble"

func is_rebuilding() -> bool:
	for s in rebuild_segs:
		if is_instance_valid(s) and s.state != Building.DEAD:
			return true
	return false

func rebuild_cost() -> int:
	return 0

func seg_distance(p: Vector3) -> float:
	var ap := Vector3(p.x - a.x, 0, p.z - a.z)
	var t := clampf(ap.dot(dir), 0.0, length)
	var q := a + dir * t
	return Vector2(p.x - q.x, p.z - q.z).length()

func card_title() -> String:
	var d: Dictionary = Defs.BUILD.get(kind, {})
	return "Broken " + String(d.get("long", kind)).to_lower()

func card_lines() -> Array:
	if is_rebuilding():
		return ["Workers are rebuilding it", "The zone seals the moment it's done"]
	var auto := "on" if G.walls.auto_rebuild else "off"
	return ["%.1f m gap in the wall" % length, "Auto rebuild is %s" % auto]

func card_buttons() -> Array:
	if is_rebuilding():
		return [["close", "OK", true]]
	var c := rebuild_cost()
	return [["rebuild", "REBUILD" if c <= 0 else "REBUILD %d" % c, G.main.supplies >= c], ["clear_rubble", "CLEAR", true]]
