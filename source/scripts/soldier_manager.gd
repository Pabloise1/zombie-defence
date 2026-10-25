class_name SoldierManager
extends Node3D
signal changed
const SECTORS := 8
const WATCH := 80.0
var soldiers: Array = []
var threat := PackedFloat32Array()
var focus: Array = []
var total_threat := 0.0
var _threat_t := 0.0
var _alloc_t := 0.0
var _calm := 0.0

func _ready() -> void:
	threat.resize(SECTORS)
	focus.resize(SECTORS)
	focus.fill(Vector3.INF)

func add_soldier(at: Vector3) -> Soldier:
	var s := Soldier.new()
	s.name = "Soldier%d" % soldiers.size()
	add_child(s)
	soldiers.append(s)
	var home: Vector3 = G.people.home_spot(s) if G.people else at
	s.setup(at, home)
	changed.emit()
	return s

func remove_soldier(s: Soldier) -> void:
	if s.post and is_instance_valid(s.post):
		s.post.soldier_cancelled(s)
	soldiers.erase(s)
	changed.emit()

# Rifle damage, with the Armory bonus.
func damage() -> float:
	if G.buildings and G.buildings.count_built("armory") > 0:
		return Defs.SOLDIER_DAMAGE * 1.25
	return Defs.SOLDIER_DAMAGE

func idle_soldiers() -> Array:
	var out := []
	for s in soldiers:
		if not s.dead and (s.is_free() or s.auto_post):
			out.append(s)
	return out

func idle_count() -> int:
	return idle_soldiers().size()

func assign(b) -> int:
	var n := 0
	var idle := idle_soldiers()
	idle.sort_custom(func(a, c): return a.position.distance_squared_to(b.position) < c.position.distance_squared_to(b.position))
	for s in idle:
		if b.free_slots() <= 0:
			break
		if s.auto_post:
			s.leave_post()
		if s.assign(b):
			n += 1
	changed.emit()
	return n

func on_dead(s) -> void:
	soldiers.erase(s)
	changed.emit()

func step(dt: float) -> void:
	_threat_t -= dt
	if _threat_t <= 0.0:
		_threat_t = 0.5
		_update_threat()
	_alloc_t -= dt
	if _alloc_t <= 0.0:
		_alloc_t = 1.0
		_allocate(1.0)
	for i in range(soldiers.size() - 1, -1, -1):
		var s = soldiers[i]
		if is_instance_valid(s):
			s.step(dt)
	for c in get_children():
		if c is Soldier and c.dead and not soldiers.has(c):
			c.step(dt)

static func sector_of(p: Vector3) -> int:
	var d := p - Defs.hq_center()
	var a := atan2(d.z, d.x)
	return posmod(int(floor((a + PI) / TAU * SECTORS + 0.5)), SECTORS)

static func sector_dir(k: int) -> Vector3:
	var a := float(k) / SECTORS * TAU - PI
	return Vector3(cos(a), 0, sin(a))

func _update_threat() -> void:
	threat.fill(0.0)
	var sums: Array = []
	sums.resize(SECTORS)
	sums.fill(Vector3.ZERO)
	total_threat = 0.0
	if G.zombies == null:
		return
	var hq := Defs.hq_center()
	for z in G.zombies.alive_list:
		if not z.alive:
			continue
		var d: float = Vector2(z.position.x - hq.x, z.position.z - hq.z).length()
		if d > WATCH:
			continue
		var w := 0.35
		if z.pressing:
			w = 2.0
		if z.st == Zombie.ATTACK:
			w = 4.0
		if z.target != null and z.target is Person:
			w += 1.5
		if z.kind == Defs.Z_BRUTE:
			w *= 3.0
		elif z.kind == Defs.Z_RUNNER:
			w *= 1.3
		w *= clampf(1.4 - d / 90.0, 0.4, 1.4)
		var k := sector_of(z.position)
		threat[k] += w
		sums[k] += z.position * w
		total_threat += w
	for k in SECTORS:
		focus[k] = sums[k] / threat[k] if threat[k] > 0.01 else Vector3.INF

func threat_at(p: Vector3) -> float:
	var mx := 0.0
	for k in SECTORS:
		mx = maxf(mx, threat[k])
	if mx <= 0.01:
		return 0.0
	return threat[sector_of(p)] / mx

func sector_focus(k: int) -> Vector3:
	if k < 0 or k >= SECTORS:
		return Vector3.INF
	return focus[k]

func _allocate(dt: float) -> void:
	var free: Array = []
	for s in soldiers:
		if s.dead:
			continue
		if s.is_free() or (s.auto_post and s.post != null):
			free.append(s)
	if free.is_empty():
		return
	if total_threat < 1.5:
		_calm += dt
		if _calm > 5.0:
			for s in free:
				if s.sector >= 0 or s.auto_post:
					s.rest()
		return
	_calm = 0.0
	var n := free.size()
	var want := PackedInt32Array()
	want.resize(SECTORS)
	var rem: Array = []
	var given := 0
	for k in SECTORS:
		var share := n * threat[k] / total_threat
		want[k] = int(floor(share))
		given += want[k]
		rem.append([share - floor(share), k])
	rem.sort_custom(func(a, b): return a[0] > b[0])
	var i := 0
	while given < n and i < rem.size():
		if threat[rem[i][1]] > 0.5:
			want[rem[i][1]] += 1
			given += 1
		i += 1
	var have := PackedInt32Array()
	have.resize(SECTORS)
	var spare: Array = []
	for s in free:
		var k: int = s.sector
		if k >= 0 and have[k] < want[k]:
			have[k] += 1
		else:
			spare.append(s)
	for k in SECTORS:
		while have[k] < want[k] and not spare.is_empty():
			var c: Vector3 = focus[k] if focus[k] != Vector3.INF else Defs.hq_center() + sector_dir(k) * 20.0
			spare.sort_custom(func(a, b): return a.position.distance_squared_to(c) < b.position.distance_squared_to(c))
			var s = spare.pop_front()
			_send(s, k, have[k], want[k])
			have[k] += 1
	for s in spare:
		if s.sector >= 0 or s.auto_post:
			s.rest()

func _send(s, k: int, i: int, n: int) -> void:
	if s.auto_post:
		s.leave_post()
	var c: Vector3 = focus[k] if focus[k] != Vector3.INF else Defs.hq_center() + sector_dir(k) * 20.0
	var port = _port_on_side(k, c)
	if port != null:
		s.sector = k
		if s.assign(port, true):
			s.sector = k
			return
	var spot := _guard_spot(c, i, n)
	if spot != Vector3.INF:
		s.guard(spot, k)

func _port_on_side(k: int, c: Vector3):
	var best = null
	var bd := 34.0
	var cands: Array = []
	if G.buildings:
		cands.append_array(G.buildings.list)
	if G.walls:
		cands.append_array(G.walls.live())
	for b in cands:
		if not is_instance_valid(b) or b.state != Building.BUILT or b.host != null:
			continue
		if b.kind == "sniper" or b.capacity() <= 0 or b.free_slots() <= 0:
			continue
		if b is MapBuilding and not b.claimed:
			continue
		if sector_of(b.position) != k:
			continue
		var d: float = b.position.distance_to(c)
		if d < bd:
			bd = d
			best = b
	return best

func _guard_spot(c: Vector3, i: int, n: int) -> Vector3:
	var g: Grid = G.grid
	var hq := Defs.hq_center()
	var zone: int = G.people.hq_zone() if G.people else 0
	var to_hq := Vector3(hq.x - c.x, 0, hq.z - c.z)
	var l := to_hq.length()
	if l < 0.5:
		return Vector3.INF
	var d := to_hq / l
	var side := Vector3(-d.z, 0, d.x)
	var lateral := (float(i) - (n - 1) * 0.5) * 2.6
	var stand := Vector3.INF
	if zone > 0:
		var t := 0.0
		while t < l:
			var p := c + d * t + side * lateral
			var nc := Defs.world_to_nav(p)
			if g.ninb(nc) and G.zones.region[g.nidx(nc)] == zone:
				stand = p + d * 1.5
				break
			t += 1.0
	else:
		stand = hq - d * 7.0 + side * lateral
	if stand == Vector3.INF:
		return Vector3.INF
	return _walkable_near(stand, zone)

func _walkable_near(p: Vector3, zone: int) -> Vector3:
	var g: Grid = G.grid
	var c := Defs.world_to_nav(p)
	for r in 5:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nc := c + Vector2i(dx, dy)
				if not g.ninb(nc):
					continue
				var j := g.nidx(nc)
				if not g.nwalk_people_i(j) or g.nblk[j] == Grid.N_GATE or g.hq_nav.has(j):
					continue
				if zone > 0 and G.zones.region[j] != zone:
					continue
				return Defs.nav_center(nc)
	return Vector3.INF

func pick_target(p: Vector3, r: float, current = null):
	var zm = G.zombies
	if zm == null:
		return null
	var c := Defs.world_to_cell(p)
	var cr := int(ceil(r / Defs.CELL))
	var r2 := r * r
	var best = null
	var bs := INF
	for dy in range(-cr, cr + 1):
		var y := c.y + dy
		if y < 0 or y >= Defs.H:
			continue
		for dx in range(-cr, cr + 1):
			var x := c.x + dx
			if x < 0 or x >= Defs.W:
				continue
			var j: int = zm.cell_head[y * Defs.W + x]
			while j >= 0:
				var z: Zombie = zm.alive_list[j]
				j = zm.znext[j]
				if not z.alive:
					continue
				var ex := z.position.x - p.x
				var ez := z.position.z - p.z
				var d2 := ex * ex + ez * ez
				if d2 > r2:
					continue
				var score := sqrt(d2)
				if z.st == Zombie.ATTACK:
					score -= 8.0
				elif z.pressing:
					score -= 5.0
				if z.target != null and z.target is Person:
					score -= 6.0
				if z.kind == Defs.Z_BRUTE:
					score -= 9.0
				var others: int = z.aimed - (1 if z == current else 0)
				if others > 0 and z.hp <= others * damage():
					score += 12.0
				else:
					score += others * 2.5
				if z == current:
					score -= 1.5
				if score < bs:
					bs = score
					best = z
	return best
