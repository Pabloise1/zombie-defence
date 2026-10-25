class_name ZombieManager
extends Node3D
signal killed(z)
const W := Defs.W
const H := Defs.H
var all: Array = []
var active: Array = []
var alive_list: Array = []
var _free := {}
var alive_count := 0
var dying_count := 0
var kills := 0
var spawned := 0
var wave := 1
var cell_head := PackedInt32Array()
var znext := PackedInt32Array()
var danger := PackedFloat32Array()
var _danger_t := 0.0
var _frame := 0
var shadows := true
var lod := true
var step_usec := 0
var near_count := 0
var tier_counts := [0, 0, 0, 0]
var lod_boost := 0
var prof := PackedInt64Array([0, 0, 0, 0, 0])

func _ready() -> void:
	cell_head.resize(W * H)
	danger.resize(W * H)
	znext.resize(256)

func prewarm(per_variant: int) -> void:
	_free_list("zombie_brute").append(_create("zombie_brute"))
	for v in ["zombie_a", "zombie_b"]:
		for i in per_variant:
			_free_list(v).append(_create(v))

func _free_list(v: String) -> Array:
	if not _free.has(v):
		_free[v] = []
	return _free[v]

func _create(v: String) -> Zombie:
	var z := Zombie.new()
	z.id = all.size()
	add_child(z)
	z.build(v)
	if not shadows:
		Art.set_shadows(z.model, false)
	all.append(z)
	return z

func spawn(kind: int, pos: Vector3) -> Zombie:
	var v := "zombie_b" if kind == Defs.Z_RUNNER else ("zombie_a" if randf() < 0.6 else "zombie_b")
	if kind == Defs.Z_BRUTE:
		v = "zombie_brute"
	var fl := _free_list(v)
	var z: Zombie = fl.pop_back() if fl.size() > 0 else _create(v)
	z.reset(kind, pos, wave)
	if not z.listed:
		z.listed = true
		active.append(z)
	alive_count += 1
	spawned += 1
	return z

func on_killed(z: Zombie) -> void:
	alive_count -= 1
	kills += 1
	killed.emit(z)

func recycle(z: Zombie) -> void:
	if not z.active:
		return
	z.active = false
	z.visible = false
	z.position = Vector3(0, -100, 0)
	_free_list(z.variant).append(z)

func set_shadows(on: bool) -> void:
	shadows = on
	for z in all:
		Art.set_shadows(z.model, on)

func clear_all() -> void:
	for z in active:
		if z.alive:
			z.alive = false
			alive_count -= 1
		recycle(z)
		z.listed = false
	active.clear()
	alive_list.clear()

func step(dt: float) -> void:
	_frame += 1
	for i in range(active.size() - 1, -1, -1):
		if not active[i].active:
			active[i].listed = false
			active.remove_at(i)
	var t0 := Time.get_ticks_usec()
	_build_buckets()
	var ta := Time.get_ticks_usec()
	_separation()
	var tb := Time.get_ticks_usec()
	_danger_t -= dt
	if _danger_t <= 0.0:
		_danger_t = 0.5
		_build_danger()
	var tc := Time.get_ticks_usec()
	prof[0] += ta - t0
	prof[1] += tb - ta
	prof[2] += tc - tb
	var view := Vector3.ZERO
	var vr := 1000000.0
	if lod and G.cam:
		view = G.cam.target
		vr = G.cam.dist * 1.25 + 14.0
	var r0 := vr * vr * 0.36
	var r1 := vr * vr
	var r2 := vr * vr * 3.0
	near_count = 0
	dying_count = 0
	tier_counts = [0, 0, 0, 0]
	for z in active:
		if not z.alive:
			dying_count += 1
			z.near = true
			z.tier = 0
			z.step(dt)
			continue
		var dx: float = z.position.x - view.x
		var dz: float = z.position.z - view.z
		var d2 := dx * dx + dz * dz
		var tier := 0
		if d2 > r2:
			tier = 3
		elif d2 > r1:
			tier = 2
		elif d2 > r0:
			tier = 1
		z.tier = tier
		z.near = tier <= 1
		tier_counts[tier] += 1
		if tier <= 1:
			near_count += 1
		var every: int = tier + 1 + (lod_boost if tier >= 1 else 0)
		if every == 1:
			z.step(dt)
		elif (z.id + _frame) % every == 0:
			z.step(dt * every)
	var td := Time.get_ticks_usec()
	_advance_anims(dt)
	var te := Time.get_ticks_usec()
	prof[3] += td - tc
	prof[4] += te - td
	step_usec = te - t0

func _build_buckets() -> void:
	cell_head.fill(-1)
	alive_list.clear()
	if G.walls:
		for s in G.walls.segments:
			if is_instance_valid(s):
				s.press = 0
	for z in active:
		if z.alive:
			alive_list.append(z)
			if z.st == Zombie.ATTACK and z.target is LinearStructure and is_instance_valid(z.target):
				z.target.press += 2 if z.kind == Defs.Z_BRUTE else 1
	var n := alive_list.size()
	if znext.size() < n:
		znext.resize(n * 2)
	for k in n:
		var z: Zombie = alive_list[k]
		var c := Defs.world_to_cell(z.position)
		if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
			znext[k] = -2
			z.bucket = -1
			continue
		var i := c.y * W + c.x
		z.bucket = i
		znext[k] = cell_head[i]
		cell_head[i] = k

func _separation() -> void:
	var n := alive_list.size()
	var parity := _frame & 3
	for k in n:
		var z: Zombie = alive_list[k]
		var every := 2 if z.tier <= 1 else 4
		if (z.id + parity) % every != 0:
			continue
		var bi: int = z.bucket
		if bi < 0:
			z.sep = Vector2.ZERO
			continue
		var cx := bi % W
		var cy := bi / W
		var fx := z.position.x / Defs.CELL + W * 0.5 - cx
		var fz := z.position.z / Defs.CELL + H * 0.5 - cy
		var ox := 1 if fx > 0.5 else -1
		var oy := 1 if fz > 0.5 else -1
		var push := Vector2.ZERO
		var checks := 0
		var zr: float = 0.55 * z.scale.x
		for q in 4:
			var x := cx + (ox if (q & 1) == 1 else 0)
			var y := cy + (oy if (q & 2) == 2 else 0)
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var j := cell_head[y * W + x]
			while j >= 0 and checks < 10:
				if j != k:
					var o: Zombie = alive_list[j]
					var dx := z.position.x - o.position.x
					var dz := z.position.z - o.position.z
					var d2 := dx * dx + dz * dz
					var r := maxf((zr + 0.55 * o.scale.x) * 0.5, 0.5) * 1.18
					if d2 < r * r:
						checks += 1
						if d2 > 1.0e-06:
							var d := sqrt(d2)
							var f := (r - d) / r * 3.2
							if o.kind == Defs.Z_BRUTE and z.kind != Defs.Z_BRUTE:
								f *= 1.8
							push.x += dx / d * f
							push.y += dz / d * f
						else:
							push += Vector2(randf_range(-1, 1), randf_range(-1, 1))
				j = znext[j]
		z.sep = push

func _build_danger() -> void:
	danger.fill(0.0)
	for z in alive_list:
		var bi: int = z.bucket
		if bi < 0:
			continue
		var w := 3.0 if z.kind == Defs.Z_BRUTE else 1.0
		danger[bi] += w
		var cx := bi % W
		var cy := bi / W
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and y >= 0 and x < W and y < H:
					danger[y * W + x] += w * 0.5

func _advance_anims(dt: float) -> void:
	var crowd := 1 + lod_boost
	if near_count > 220:
		crowd += 2
	elif near_count > 120:
		crowd += 1
	for z in active:
		if z.anim == null:
			continue
		z.anim_acc += dt
		var every := 1
		match z.tier:
			0:
				every = crowd
			1:
				every = 2 * crowd
			_:
				z.anim_acc = minf(z.anim_acc, 1.0)
				continue
		if (z.id + _frame) % every == 0:
			z.anim.advance(z.anim_acc)
			z.anim_acc = 0.0

func nearest(p: Vector3, r: float):
	if r <= 12.0:
		return nearest_r(p, r)
	var best = null
	var bd := r * r
	for z in alive_list:
		if not z.alive:
			continue
		var dx: float = z.position.x - p.x
		var dz: float = z.position.z - p.z
		var d2 := dx * dx + dz * dz
		if d2 < bd:
			bd = d2
			best = z
	return best

func nearest_r(p: Vector3, r: float, zone: int = -1):
	var c := Defs.world_to_cell(p)
	var cr := int(ceil(r / Defs.CELL))
	var r2 := r * r
	var best = null
	var bd := r2
	for dy in range(-cr, cr + 1):
		var y := c.y + dy
		if y < 0 or y >= H:
			continue
		for dx in range(-cr, cr + 1):
			var x := c.x + dx
			if x < 0 or x >= W:
				continue
			var j := cell_head[y * W + x]
			while j >= 0:
				var z: Zombie = alive_list[j]
				if z.alive:
					var ex := z.position.x - p.x
					var ez := z.position.z - p.z
					var d2 := ex * ex + ez * ez
					if d2 < bd:
						if zone < 0 or (G.zones and G.zones.zone_at(z.position) == zone):
							bd = d2
							best = z
				j = znext[j]
	return best

func any_near(p: Vector3, r: float) -> bool:
	if r > 3.0:
		return any_near_r(p, r)
	var c := Defs.world_to_cell(p)
	var r2 := r * r
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var j := cell_head[y * W + x]
			while j >= 0:
				var z: Zombie = alive_list[j]
				if z.alive:
					var ddx := z.position.x - p.x
					var ddz := z.position.z - p.z
					if ddx * ddx + ddz * ddz < r2:
						return true
				j = znext[j]
	return false

func any_near_r(p: Vector3, r: float) -> bool:
	return nearest_r(p, r) != null

func count_near(p: Vector3, r: float) -> int:
	var c := Defs.world_to_cell(p)
	var cr := int(ceil(r / Defs.CELL))
	var r2 := r * r
	var n := 0
	for dy in range(-cr, cr + 1):
		var y := c.y + dy
		if y < 0 or y >= H:
			continue
		for dx in range(-cr, cr + 1):
			var x := c.x + dx
			if x < 0 or x >= W:
				continue
			var j := cell_head[y * W + x]
			while j >= 0:
				var z: Zombie = alive_list[j]
				if z.alive:
					var ex := z.position.x - p.x
					var ez := z.position.z - p.z
					if ex * ex + ez * ez < r2:
						n += 1
				j = znext[j]
	return n

func danger_on_line(a: Vector3, b: Vector3) -> float:
	var l := a.distance_to(b)
	var steps := maxi(1, int(l / Defs.CELL))
	var s := 0.0
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var c := Defs.world_to_cell(p)
		if c.x >= 0 and c.y >= 0 and c.x < W and c.y < H:
			s += danger[c.y * W + c.x]
	return s

func danger_at(p: Vector3) -> float:
	var c := Defs.world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return 0.0
	return danger[c.y * W + c.x]

func damage_cell(c: Vector2i, amount: float) -> int:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return 0
	var hit := 0
	var j := cell_head[c.y * W + c.x]
	while j >= 0:
		var z: Zombie = alive_list[j]
		var nj := znext[j]
		if z.alive:
			z.hurt(amount, z.position)
			z.stagger_t = maxf(z.stagger_t, 0.25)
			hit += 1
			if G.fx and randf() < 0.5:
				G.fx.blood_puff(z.position + Vector3(0, 0.5, 0))
		j = nj
	return hit

func damage_radius(p: Vector3, r: float, amount: float) -> int:
	if G.map:
		G.map.blast_at(p, r)
	var hit := 0
	var r2 := r * r
	for z in alive_list:
		if not z.alive:
			continue
		var dx: float = z.position.x - p.x
		var dz: float = z.position.z - p.z
		var d2 := dx * dx + dz * dz
		if d2 < r2:
			var f := 1.0 - sqrt(d2) / r * 0.6
			z.blast(amount * f, p)
			hit += 1
	return hit

func count_cell(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return 0
	var n := 0
	var j := cell_head[c.y * W + c.x]
	while j >= 0:
		if alive_list[j].alive:
			n += 1
		j = znext[j]
	return n

func best_cluster(p: Vector3, rmin: float, rmax: float, lead: float) -> Vector3:
	var best := Vector3.INF
	var best_score := 0.0
	var n := alive_list.size()
	if n == 0:
		return best
	var stride := maxi(1, n / 40)
	var r2min := rmin * rmin
	var r2max := rmax * rmax
	var k := 0
	while k < n:
		var z: Zombie = alive_list[k]
		k += stride
		if not z.alive:
			continue
		var dx: float = z.position.x - p.x
		var dz: float = z.position.z - p.z
		var d2 := dx * dx + dz * dz
		if d2 < r2min or d2 > r2max:
			continue
		var score := _crowd(z.position, 3.5)
		if score > best_score:
			best_score = score
			best = z.position
			if z.st == Zombie.WALK:
				var fwd := Vector3(-sin(z.rotation.y), 0, -cos(z.rotation.y))
				best += fwd * z.speed * lead * 0.7
	if best != Vector3.INF:
		best.y = G.grid.floor_y(Defs.world_to_cell(best))
	return best

func _crowd(p: Vector3, r: float) -> float:
	var c := Defs.world_to_cell(p)
	var r2 := r * r
	var score := 0.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var j := cell_head[y * W + x]
			while j >= 0:
				var z: Zombie = alive_list[j]
				if z.alive:
					var ex := z.position.x - p.x
					var ez := z.position.z - p.z
					if ex * ex + ez * ez < r2:
						score += 3.0 if z.kind == Defs.Z_BRUTE else 1.0
				j = znext[j]
	return score

func best_threat(p: Vector3, r: float):
	var best = null
	var best_rank := -1
	var best_d := INF
	var r2 := r * r
	for z in alive_list:
		if not z.alive:
			continue
		var dx: float = z.position.x - p.x
		var dz: float = z.position.z - p.z
		var d2 := dx * dx + dz * dz
		if d2 > r2:
			continue
		var rank := 0
		if z.kind == Defs.Z_BRUTE:
			rank = 2
		elif z.kind == Defs.Z_RUNNER:
			rank = 1
		if rank > best_rank or (rank == best_rank and d2 < best_d):
			best_rank = rank
			best_d = d2
			best = z
	return best

func ignite_radius(p: Vector3, r: float) -> void:
	var c := Defs.world_to_cell(p)
	var cr := int(ceil(r / Defs.CELL))
	var r2 := r * r
	for dy in range(-cr, cr + 1):
		var y := c.y + dy
		if y < 0 or y >= H:
			continue
		for dx in range(-cr, cr + 1):
			var x := c.x + dx
			if x < 0 or x >= W:
				continue
			var j := cell_head[y * W + x]
			while j >= 0:
				var z: Zombie = alive_list[j]
				if z.alive:
					var ex := z.position.x - p.x
					var ez := z.position.z - p.z
					if ex * ex + ez * ez < r2:
						z.ignite(Defs.BURN_TIME * 0.7)
				j = znext[j]

func flame_cone(origin: Vector3, dir: Vector3, r: float, half_angle: float, amount: float) -> int:
	var hit := 0
	var r2 := r * r
	var cos_a := cos(half_angle)
	for z in alive_list:
		if not z.alive:
			continue
		var to := Vector3(z.position.x - origin.x, 0, z.position.z - origin.z)
		var d2 := to.length_squared()
		if d2 > r2 or d2 < 0.0001:
			continue
		if to.normalized().dot(dir) < cos_a:
			continue
		z.hurt_dot(amount)
		z.ignite(Defs.BURN_TIME)
		hit += 1
	return hit
