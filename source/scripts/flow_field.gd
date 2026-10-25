class_name FlowField
extends RefCounted
const INF := 1.0e+20
const NW := Defs.NW
const NH := Defs.NH
var grid: Grid
var dist := PackedFloat32Array()
var next := PackedInt32Array()
var version := 0
var last_ms := 0.0
var last_frames := 0
var _dirty := true
var _busy := false
var _wd := PackedFloat32Array()
var _wn := PackedInt32Array()
var _cost := PackedFloat32Array()
var _open := PackedByteArray()
var _skip := PackedByteArray()
var _hp := PackedFloat32Array()
var _hc := PackedInt32Array()
var _hn := 0
var _usec := 0
var _frames := 0
var _row := 0
var fixed_pops := 0
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]
var _off := PackedInt32Array()
var _ca := PackedInt32Array()
var _cb := PackedInt32Array()

func _init(g: Grid) -> void:
	grid = g
	var n := NW * NH
	dist.resize(n)
	next.resize(n)
	dist.fill(INF)
	next.fill(-1)
	_wd.resize(n)
	_wn.resize(n)
	_cost.resize(n)
	_open.resize(n)
	_skip.resize(n)
	for k in 8:
		_off.append(int(DY[k]) * NW + int(DX[k]))
		_ca.append(int(DY[k]) * NW)
		_cb.append(int(DX[k]))
	grid.paths_changed.connect(request)

func request() -> void:
	_dirty = true

func compute_now() -> void:
	_start()
	_dirty = false
	_step(1 << 30, 1 << 30)

func update(budget_usec: int = 3000) -> void:
	if _dirty and not _busy:
		_start()
		_dirty = false
	if _busy:
		if fixed_pops > 0:
			_step(1 << 30, fixed_pops)
		else:
			_step(budget_usec, 1 << 30)

func is_busy() -> bool:
	return _busy or _dirty

func _goal_bias(owner) -> float:
	if owner == null:
		return 6.0
	if owner is HQBuilding:
		return 0.0
	if owner is Building and owner.def.has("lure"):
		return -float(owner.def["lure"])
	if owner is LinearStructure:
		return 5.0
	if Defs.GUNS.has(owner.kind):
		return 3.0
	return 4.0

func _start() -> void:
	var t0 := Time.get_ticks_usec()
	_busy = true
	_frames = 0
	_row = 0
	_hn = 0
	_wd.fill(INF)
	_wn.fill(-1)
	_usec = Time.get_ticks_usec() - t0

func _init_rows(rows: int) -> void:
	var nblk := grid.nblk
	var y1 := mini(NH, _row + rows)
	for y in range(_row, y1):
		var i0 := y * NW
		for i in range(i0, i0 + NW):
			var b := nblk[i]
			if b == Grid.N_OPEN:
				_cost[i] = 3.0 if grid.n_trench_i(i) else 1.0
				_open[i] = 1
				_skip[i] = 0
			elif b == Grid.N_SLOW:
				_cost[i] = 4.0
				_open[i] = 1
				_skip[i] = 0
			elif b == Grid.N_ROCK or b == Grid.N_STATIC:
				_cost[i] = INF
				_open[i] = 0
				_skip[i] = 1
			else:
				_cost[i] = 1.0
				_open[i] = 0
				_skip[i] = 1
				var d := 0.0 if grid.hq_nav.has(i) else _goal_bias(grid.nown[i])
				_wd[i] = d
				_push(d, i)
	_row = y1
	if _row >= NH:
		var blist: Array = G.buildings.list if G.buildings else []
		for bld in blist:
			if is_instance_valid(bld) and bld.state == Building.BUILT and not bld.blocks_now():
				var extra: float = float(bld.def.get("zcost", 1.0))
				if extra > 1.0:
					for i in grid.building_nav_cells(bld):
						_cost[i] = maxf(_cost[i], extra)

func _step(max_usec: int, max_pops: int) -> void:
	var t0 := Time.get_ticks_usec()
	_frames += 1
	var pops := 0
	while _row < NH:
		_init_rows(8)
		pops += 8 * NW / 6
		if pops >= max_pops or Time.get_ticks_usec() - t0 >= max_usec:
			_usec += Time.get_ticks_usec() - t0
			return
	var off := _off
	var ca := _ca
	var cb := _cb
	while _hn > 0:
		if pops >= max_pops:
			break
		if (pops & 127) == 0 and Time.get_ticks_usec() - t0 >= max_usec:
			break
		pops += 1
		var p := _hp[0]
		var u := _pop()
		if p > _wd[u]:
			continue
		var ux := u % NW
		var uy := u / NW
		var cu := _cost[u]
		if ux > 0 and uy > 0 and ux < NW - 1 and uy < NH - 1:
			for k in 8:
				var v := u + off[k]
				if _skip[v] == 1:
					continue
				var nd := 0.0
				if k < 4:
					nd = p + 0.5 * (_cost[v] + cu)
				else:
					if _open[u + ca[k]] == 0 or _open[u + cb[k]] == 0:
						continue
					nd = p + 0.70711 * (_cost[v] + cu)
				if nd < _wd[v]:
					_wd[v] = nd
					_wn[v] = u
					_push(nd, v)
			continue
		for k in 8:
			var vx: int = ux + DX[k]
			var vy: int = uy + DY[k]
			if vx < 0 or vy < 0 or vx >= NW or vy >= NH:
				continue
			var v := vy * NW + vx
			if _skip[v] == 1:
				continue
			var ln := 0.5
			if k >= 4:
				if _open[vy * NW + ux] == 0 or _open[uy * NW + vx] == 0:
					continue
				ln = 0.70711
			var nd := p + ln * (_cost[v] + cu)
			if nd < _wd[v]:
				_wd[v] = nd
				_wn[v] = u
				_push(nd, v)
	_usec += Time.get_ticks_usec() - t0
	if _hn == 0:
		_busy = false
		var td := dist
		dist = _wd
		_wd = td
		var tn := next
		next = _wn
		_wn = tn
		version += 1
		last_ms = _usec / 1000.0
		last_frames = _frames

func _push(p: float, c: int) -> void:
	if _hn >= _hp.size():
		_hp.resize(_hn * 2 + 1024)
		_hc.resize(_hn * 2 + 1024)
	var i := _hn
	_hn += 1
	while i > 0:
		var par := (i - 1) >> 1
		if _hp[par] <= p:
			break
		_hp[i] = _hp[par]
		_hc[i] = _hc[par]
		i = par
	_hp[i] = p
	_hc[i] = c

func _pop() -> int:
	var top := _hc[0]
	_hn -= 1
	if _hn > 0:
		var p := _hp[_hn]
		var c := _hc[_hn]
		var i := 0
		while true:
			var l := i * 2 + 1
			if l >= _hn:
				break
			var m := l
			if l + 1 < _hn and _hp[l + 1] < _hp[l]:
				m = l + 1
			if _hp[m] >= p:
				break
			_hp[i] = _hp[m]
			_hc[i] = _hc[m]
			i = m
		_hp[i] = p
		_hc[i] = c
	return top
