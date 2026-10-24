class_name HeliManager
extends Node3D
var list: Array = []

func add_heli(k: String, pad) -> Heli:
	var h := Heli.new()
	h.name = "Heli%d" % list.size()
	add_child(h)
	h.setup(k, pad)
	list.append(h)
	var lt: Transform3D = pad.land_xform()
	var from := lt.origin.normalized() * (Defs.HALF + 10.0)
	if from.length() < 1.0:
		from = Vector3(0, 0, -Defs.HALF - 10.0)
	h.position = Vector3(from.x, Heli.CRUISE_ALT, from.z)
	h.rotor = 1.0
	h.mission = "home"
	h.dest = lt.origin
	h.alt = Heli.CRUISE_ALT
	h.fly = Heli.CRUISE
	if G.sfx:
		G.sfx.loop("rotor_loop", h)
	return h

func on_lost(h) -> void:
	list.erase(h)

func step(dt: float) -> void:
	for h in list.duplicate():
		if is_instance_valid(h):
			h.step(dt)

func landed_near(p: Vector3, r: float):
	for h in list:
		if is_instance_valid(h) and h.landed() and h.fly != Heli.DEAD and Vector2(h.position.x - p.x, h.position.z - p.z).length() < r:
			return h
	return null

func landing_spot(p: Vector3) -> Vector3:
	var g: Grid = G.grid
	var c := Defs.world_to_nav(p)
	for r in range(0, 14, 2):
		for k in 12:
			var a := TAU * k / 12.0
			var q := c + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			if _clear(g, q) and not (G.zombies and G.zombies.any_near_r(Defs.nav_center(q), 8.0)):
				return Defs.nav_center(q)
			if r == 0:
				break
	return Vector3.INF

func _clear(g: Grid, c: Vector2i) -> bool:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var n := c + Vector2i(dx, dy)
			if not g.ninb(n):
				return false
			var b := g.nblk[g.nidx(n)]
			if b != Grid.N_OPEN:
				return false
	return true
