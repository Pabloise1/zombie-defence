class_name Grid
extends RefCounted
signal paths_changed
const W := Defs.W
const H := Defs.H
const NW := Defs.NW
const NH := Defs.NH
const N_OPEN := 0
const N_WALL := 1
const N_GATE := 2
const N_BUILD := 3
const N_ROCK := 4
const N_SLOW := 5
const N_STATIC := 6
const CLIMB_COST := 40.0
var terrain := PackedByteArray()
var occ: Array = []
var digs: Array = []
var hq_cells := {}
var nblk := PackedByteArray()
var nown: Array = []
var heal: Callable
var hq_nav := {}
var wall_near := PackedByteArray()
var version := 0
var _g := PackedFloat32Array()
var _from := PackedInt32Array()
var _closed := PackedByteArray()
var _heap_p := PackedFloat32Array()
var _heap_c := PackedInt32Array()
var _heap_n := 0
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

func _init() -> void:
	terrain.resize(W * H)
	terrain.fill(Defs.T_GROUND)
	occ.resize(W * H)
	digs.resize(W * H)
	nblk.resize(NW * NH)
	nblk.fill(N_OPEN)
	nown.resize(NW * NH)
	_g.resize(NW * NH)
	_from.resize(NW * NH)
	_closed.resize(NW * NH)
	for y in Defs.HQ_SIZE:
		for x in Defs.HQ_SIZE:
			var c := Defs.HQ_ORIGIN + Vector2i(x, y)
			hq_cells[idx(c)] = true
			for n in build_to_nav_cells(c):
				hq_nav[nidx(n)] = true

func idx(c: Vector2i) -> int:
	return c.y * W + c.x

func cell_of(i: int) -> Vector2i:
	return Vector2i(i % W, i / W)

func inb(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H

func is_hq(c: Vector2i) -> bool:
	return hq_cells.has(idx(c))

func floor_y(c: Vector2i) -> float:
	if not inb(c):
		return 0.0
	var t := terrain[idx(c)]
	return -Defs.TRENCH_DEPTH if (t == Defs.T_TRENCH or t == Defs.T_TUNNEL) else 0.0

func floor_y_i(i: int) -> float:
	var t := terrain[i]
	return -Defs.TRENCH_DEPTH if (t == Defs.T_TRENCH or t == Defs.T_TUNNEL) else 0.0

func center(c: Vector2i) -> Vector3:
	var p := Defs.cell_center(c)
	p.y = floor_y(c)
	return p

func is_trench(c: Vector2i) -> bool:
	if not inb(c):
		return false
	var t := terrain[idx(c)]
	return t == Defs.T_TRENCH or t == Defs.T_TUNNEL

func is_rock(c: Vector2i) -> bool:
	return inb(c) and terrain[idx(c)] == Defs.T_ROCK

func blocker_at_i(i: int):
	var b = occ[i]
	if b != null and b.blocks_now():
		return b
	return null

# Scattered rocks and trees that building over clears away. Nav index ->
# the node that owns it (Decor or MapBuilder), which has clear_clutter(ni).
var clutter_nav := {}

func is_clutter_cell(c: Vector2i) -> bool:
	for n in build_to_nav_cells(c):
		if clutter_nav.has(nidx(n)):
			return true
	return false

func clear_clutter(navs) -> void:
	var any := false
	for ni in navs:
		var o = clutter_nav.get(ni)
		if o != null and is_instance_valid(o):
			o.clear_clutter(ni)
			any = true
	if any:
		notify_paths_changed()

func clear_clutter_cells(cells) -> void:
	var navs := []
	for c in cells:
		for n in build_to_nav_cells(c):
			navs.append(nidx(n))
	clear_clutter(navs)

func set_rock(c: Vector2i) -> void:
	terrain[idx(c)] = Defs.T_ROCK
	for n in build_to_nav_cells(c):
		nblk[nidx(n)] = N_ROCK

func set_trench(c: Vector2i) -> void:
	terrain[idx(c)] = Defs.T_TRENCH
	notify_paths_changed()

func notify_paths_changed() -> void:
	version += 1
	paths_changed.emit()

func build_to_nav_cells(c: Vector2i) -> Array[Vector2i]:
	var x := c.x * 2
	var y := c.y * 2
	return [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]

func nidx(n: Vector2i) -> int:
	return n.y * NW + n.x

func ncell_of(i: int) -> Vector2i:
	return Vector2i(i % NW, i / NW)

func ninb(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x < NW and n.y < NH

func n_trench_i(i: int) -> bool:
	var x := (i % NW) / 2
	var y := (i / NW) / 2
	var t := terrain[y * W + x]
	return t == Defs.T_TRENCH or t == Defs.T_TUNNEL

func n_floor_y_i(i: int) -> float:
	return -Defs.TRENCH_DEPTH if n_trench_i(i) else 0.0

func n_floor_y(p: Vector3) -> float:
	var n := Defs.world_to_nav(p)
	if not ninb(n):
		return 0.0
	return n_floor_y_i(nidx(n))

func nav_center(n: Vector2i) -> Vector3:
	var p := Defs.nav_center(n)
	if ninb(n):
		p.y = n_floor_y_i(nidx(n))
	return p

func nsolid_i(i: int) -> bool:
	var b := nblk[i]
	return b == N_BUILD or b == N_ROCK or b == N_STATIC

static func zone_open(b: int) -> bool:
	return b == N_OPEN or b == N_SLOW or b == N_STATIC

static func is_structure(b: int) -> bool:
	return b == N_WALL or b == N_GATE or b == N_BUILD

func nblocked_i(i: int) -> bool:
	return nblk[i] != N_OPEN

func nwalk_people_i(i: int) -> bool:
	var b := nblk[i]
	if b == N_OPEN or b == N_GATE or b == N_SLOW:
		return true
	return hq_nav.has(i)

func mark_nav(cells: PackedInt32Array, code: int, owner) -> void:
	for i in cells:
		if nblk[i] == N_ROCK or (nblk[i] == N_STATIC and nown[i] != owner):
			continue
		nblk[i] = code
		nown[i] = owner
	if code == N_WALL or code == N_GATE:
		refresh_wall_near(cells)

func refresh_wall_near(cells: PackedInt32Array) -> void:
	if wall_near.size() != NW * NH:
		wall_near.resize(NW * NH)
	for i in cells:
		var cx := i % NW
		var cy := i / NW
		for dy in range(-1, 2):
			var y := cy + dy
			if y < 0 or y >= NH:
				continue
			for dx in range(-1, 2):
				var x := cx + dx
				if x < 0 or x >= NW:
					continue
				var j := y * NW + x
				var near := 0
				for ey in range(-1, 2):
					var yy := y + ey
					if yy < 0 or yy >= NH:
						continue
					for ex in range(-1, 2):
						var xx := x + ex
						if xx < 0 or xx >= NW:
							continue
						var b := nblk[yy * NW + xx]
						if b == N_WALL or b == N_GATE:
							near = 1
				wall_near[j] = near

func clear_nav(cells: PackedInt32Array, owner) -> void:
	var cleared := PackedInt32Array()
	for i in cells:
		if nown[i] == owner:
			nown[i] = null
			if nblk[i] != N_ROCK:
				nblk[i] = N_OPEN
				cleared.append(i)
	if not cleared.is_empty() and heal.is_valid():
		heal.call(cleared)
	if not cleared.is_empty():
		refresh_wall_near(cleared)

func building_nav_cells(b) -> PackedInt32Array:
	if b.host != null or b.on_host:
		return PackedInt32Array()
	if b.rect:
		return b.nav_list
	var out := PackedInt32Array()
	for c in b.cells():
		for n in build_to_nav_cells(c):
			out.append(nidx(n))
	return out

func rect_footprint(p: Vector3, yaw: float, hx: float, hz: float) -> Dictionary:
	var nav := PackedInt32Array()
	var cells: Array[Vector2i] = []
	var seen := {}
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var ex := hx - 0.12
	var ez := hz - 0.12
	var r := sqrt(hx * hx + hz * hz) + 1.0
	var c0 := Defs.world_to_nav(p - Vector3(r, 0, r))
	var c1 := Defs.world_to_nav(p + Vector3(r, 0, r))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var n := Vector2i(x, y)
			if not ninb(n):
				continue
			var cc := Defs.nav_center(n)
			var d := Vector2(cc.x - p.x, cc.z - p.z)
			var lx := absf(d.dot(ax))
			var lz := absf(d.dot(az))
			var cell_on_ax := 0.5 * (absf(ax.x) + absf(ax.y))
			var cell_on_az := 0.5 * (absf(az.x) + absf(az.y))
			if lx > ex + cell_on_ax or lz > ez + cell_on_az:
				continue
			var rect_on_x := ex * absf(ax.x) + ez * absf(az.x)
			var rect_on_y := ex * absf(ax.y) + ez * absf(az.y)
			if absf(d.x) > rect_on_x + 0.5 or absf(d.y) > rect_on_y + 0.5:
				continue
			nav.append(nidx(n))
			var bc := Defs.nav_to_build(n)
			var bi := idx(bc)
			if not seen.has(bi):
				seen[bi] = true
				cells.append(bc)
	return {"nav": nav, "cells": cells}

func supercover(a: Vector3, b: Vector3) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ax := (a.x + Defs.HALF) / Defs.NAV
	var ay := (a.z + Defs.HALF) / Defs.NAV
	var bx := (b.x + Defs.HALF) / Defs.NAV
	var by := (b.z + Defs.HALF) / Defs.NAV
	var x := floori(ax)
	var y := floori(ay)
	var ex := floori(bx)
	var ey := floori(by)
	var dx := bx - ax
	var dy := by - ay
	var sx := 1 if dx > 0.0 else -1
	var sy := 1 if dy > 0.0 else -1
	var tdx := absf(1.0 / dx) if absf(dx) > 1.0e-09 else INF
	var tdy := absf(1.0 / dy) if absf(dy) > 1.0e-09 else INF
	var tmx := ((x + (1 if sx > 0 else 0)) - ax) / dx if absf(dx) > 1.0e-09 else INF
	var tmy := ((y + (1 if sy > 0 else 0)) - ay) / dy if absf(dy) > 1.0e-09 else INF
	_add_cell(out, x, y)
	var guard := 0
	while guard < 4000:
		guard += 1
		var tn := minf(tmx, tmy)
		if tn > 1.0:
			break
		if absf(tmx - tmy) < 1.0e-07:
			_add_cell(out, x + sx, y)
			_add_cell(out, x, y + sy)
			x += sx
			y += sy
			tmx += tdx
			tmy += tdy
		elif tmx < tmy:
			x += sx
			tmx += tdx
		else:
			y += sy
			tmy += tdy
		_add_cell(out, x, y)
	_add_cell(out, ex, ey)
	return out

func _add_cell(out: PackedInt32Array, x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= NW or y >= NH:
		return
	var i := y * NW + x
	if not out.has(i):
		out.append(i)

func _walk_cost(i: int) -> float:
	return 3.0 if n_trench_i(i) else 1.0

func find_path(start: Vector3, goals: Dictionary, budget: int = 9000, avoid: bool = false) -> PackedInt32Array:
	var out := PackedInt32Array()
	if goals.is_empty():
		return out
	var danger: PackedFloat32Array = G.zombies.danger if avoid and G.zombies else PackedFloat32Array()
	var use_danger := danger.size() == Defs.W * Defs.H
	var sn := Defs.world_to_nav(start)
	sn.x = clampi(sn.x, 0, NW - 1)
	sn.y = clampi(sn.y, 0, NH - 1)
	var s := nidx(sn)
	if goals.has(s):
		return out
	var gc: Vector2i = ncell_of(goals.keys()[0])
	_g.fill(1.0e+20)
	_closed.fill(0)
	_heap_n = 0
	_g[s] = 0.0
	_from[s] = -1
	_push(_h(sn, gc), s)
	var found := -1
	var pops := 0
	while _heap_n > 0 and pops < budget:
		pops += 1
		var u := _pop()
		if _closed[u] == 1:
			continue
		_closed[u] = 1
		if goals.has(u):
			found = u
			break
		var ux := u % NW
		var uy := u / NW
		for k in 8:
			var d := DIRS[k]
			var vx := ux + d.x
			var vy := uy + d.y
			if vx < 0 or vy < 0 or vx >= NW or vy >= NH:
				continue
			var v := vy * NW + vx
			if _closed[v] == 1:
				continue
			var climb := nblk[v] == N_WALL
			if not nwalk_people_i(v) and not goals.has(v) and not climb:
				continue
			var step := 1.0
			if k >= 4:
				if climb or not nwalk_people_i(uy * NW + vx) or not nwalk_people_i(vy * NW + ux):
					continue
				step = 1.4142
			var ng: float = _g[u] + step * _walk_cost(v) + (CLIMB_COST if climb else 0.0) + (6.0 if nblk[v] == N_SLOW else 0.0)
			if use_danger:
				ng += danger[(vy >> 1) * Defs.W + (vx >> 1)] * 5.0
			if ng < _g[v]:
				_g[v] = ng
				_from[v] = u
				_push(ng + _h(Vector2i(vx, vy), gc), v)
	if found < 0:
		return out
	var cur := found
	var guard := 0
	while cur != s and cur >= 0 and guard < 20000:
		guard += 1
		out.append(cur)
		cur = _from[cur]
	out.reverse()
	return out

func ring_goals(cells: PackedInt32Array) -> Dictionary:
	var goals := {}
	var inside := {}
	for i in cells:
		inside[i] = true
	for i in cells:
		var c := ncell_of(i)
		for d in DIRS:
			var n := c + d
			if not ninb(n):
				continue
			var j := nidx(n)
			if inside.has(j):
				continue
			if nwalk_people_i(j) and not hq_nav.has(j):
				goals[j] = true
	return goals

func point_goals(p: Vector3, radius: int = 2) -> Dictionary:
	var goals := {}
	var c := Defs.world_to_nav(p)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var n := c + Vector2i(dx, dy)
			if ninb(n) and nwalk_people_i(nidx(n)):
				goals[nidx(n)] = true
	return goals

func _h(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return float(maxi(dx, dy)) + 0.4142 * float(mini(dx, dy))

func _push(p: float, c: int) -> void:
	if _heap_n >= _heap_p.size():
		_heap_p.resize(_heap_n * 2 + 64)
		_heap_c.resize(_heap_n * 2 + 64)
	var i := _heap_n
	_heap_n += 1
	while i > 0:
		var par := (i - 1) >> 1
		if _heap_p[par] <= p:
			break
		_heap_p[i] = _heap_p[par]
		_heap_c[i] = _heap_c[par]
		i = par
	_heap_p[i] = p
	_heap_c[i] = c

func _pop() -> int:
	var top := _heap_c[0]
	_heap_n -= 1
	if _heap_n > 0:
		var p := _heap_p[_heap_n]
		var c := _heap_c[_heap_n]
		var i := 0
		while true:
			var l := i * 2 + 1
			if l >= _heap_n:
				break
			var m := l
			if l + 1 < _heap_n and _heap_p[l + 1] < _heap_p[l]:
				m = l + 1
			if _heap_p[m] >= p:
				break
			_heap_p[i] = _heap_p[m]
			_heap_c[i] = _heap_c[m]
			i = m
		_heap_p[i] = p
		_heap_c[i] = c
	return top
