class_name GarrisonBunker
extends Building
var slots: Array[Node3D] = []
var shots := 0

func _on_model_ready() -> void:
	for i in 4:
		var m := model.find_child("Slot%d" % (i + 1), true, false) as Node3D
		if m == null:
			m = Marker3D.new()
			var a := PI * 0.25 + i * PI * 0.5 + PI
			m.position = Vector3(sin(a) * 1.0, 1.0, cos(a) * 1.0)
			model.add_child(m)
		slots.append(m)

func _slot_for(p: Vector3) -> Node3D:
	var best: Node3D = slots[0]
	var bd := INF
	for s in slots:
		var d := s.global_position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = s
	return best

func tick(dt: float) -> void:
	super.tick(dt)
	if state != BUILT:
		return
	for s in occupants:
		if not is_instance_valid(s):
			continue
		s.cd -= dt
		if s.cd > 0.0:
			continue
		var z = G.zombies.nearest(position, Defs.SOLDIER_RANGE + 2.0)
		if z == null:
			s.cd = 0.3
			continue
		if not use_round():
			s.cd = 0.3
			continue
		s.cd = Defs.SOLDIER_INTERVAL * randf_range(0.85, 1.15)
		var slot := _slot_for(z.position)
		var from := slot.global_position
		var tp: Vector3 = z.aim_point() + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		z.hurt(Defs.SOLDIER_DAMAGE, from)
		shots += 1
		if G.fx:
			G.fx.tracer(from, tp, 1)
			G.fx.flash(from, 0.9)
			G.fx.hit(tp, (tp - from).normalized(), 1)
		if G.sfx:
			G.sfx.play("rifle", from)
