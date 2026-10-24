class_name ZoneMap
extends RefCounted
signal updated(breached: bool, secured: bool)
const NW := Defs.NW
const NH := Defs.NH
var grid: Grid
var region := PackedInt32Array()
var zone_cells := 0
var zone_count := 0
var mask_image: Image
var mask_tex: ImageTexture
var version := 0
var last_ms := 0.0
var _dirty := true
var _phase := 0
var _out := PackedByteArray()
var _wreg := PackedInt32Array()
var _queue := PackedInt32Array()
var _qh := 0
var _qt := 0
var _scan := 0
var _label := 0
var _usec := 0
var _lost := 0
var _gained := 0
var _cells := 0
var _mask := PackedByteArray()
var fixed_work := 0

func _init(g: Grid) -> void:
	grid = g
	var n := NW * NH
	region.resize(n)
	_wreg.resize(n)
	_out.resize(n)
	_queue.resize(n + 8)
	_mask.resize(n)
	mask_image = Image.create(NW, NH, false, Image.FORMAT_L8)
	mask_image.fill(Color(0, 0, 0))
	mask_tex = ImageTexture.create_from_image(mask_image)
	grid.paths_changed.connect(request)

func request() -> void:
	_dirty = true

func compute_now() -> void:
	_begin()
	_dirty = false
	while _phase != 0:
		_step(1 << 30, 1 << 30)

func update(budget_usec: int = 3000) -> void:
	if _dirty and _phase == 0:
		_begin()
		_dirty = false
	if _phase != 0:
		if fixed_work > 0:
			_step(fixed_work, 1 << 30)
		else:
			_step(1 << 30, budget_usec)

func is_busy() -> bool:
	return _dirty or _phase != 0

func _begin() -> void:
	_usec = 0
	var t0 := Time.get_ticks_usec()
	_out.fill(0)
	_wreg.fill(0)
	_qh = 0
	_qt = 0
	var nblk := grid.nblk
	for x in NW:
		_seed(x, 0, nblk)
		_seed(x, NH - 1, nblk)
	for y in range(1, NH - 1):
		_seed(0, y, nblk)
		_seed(NW - 1, y, nblk)
	_phase = 1
	_usec += Time.get_ticks_usec() - t0

func _seed(x: int, y: int, nblk: PackedByteArray) -> void:
	var i := y * NW + x
	if Grid.zone_open(nblk[i]) and _out[i] == 0:
		_out[i] = 1
		_queue[_qt] = i
		_qt += 1

func _step(budget: int, max_usec: int) -> void:
	var t0 := Time.get_ticks_usec()
	var nblk := grid.nblk
	var work := 0
	if _phase == 1:
		while _qh < _qt and work < budget:
			work += 1
			if (work & 255) == 0 and Time.get_ticks_usec() - t0 >= max_usec:
				break
			var u := _queue[_qh]
			_qh += 1
			var x := u % NW
			var y := u / NW
			if x > 0:
				_flood(u - 1, nblk)
			if x < NW - 1:
				_flood(u + 1, nblk)
			if y > 0:
				_flood(u - NW, nblk)
			if y < NH - 1:
				_flood(u + NW, nblk)
		if _qh >= _qt:
			_phase = 2
			_scan = 0
			_label = 0
			_qh = 0
			_qt = 0
	if _phase == 2:
		while work < budget:
			if (work & 255) == 255 and Time.get_ticks_usec() - t0 >= max_usec:
				break
			if _qh < _qt:
				work += 1
				var u := _queue[_qh]
				_qh += 1
				var x := u % NW
				var y := u / NW
				if x > 0:
					_grow(u - 1, nblk)
				if x < NW - 1:
					_grow(u + 1, nblk)
				if y > 0:
					_grow(u - NW, nblk)
				if y < NH - 1:
					_grow(u + NW, nblk)
				continue
			var found := false
			while _scan < NW * NH:
				var i := _scan
				_scan += 1
				work += 1
				if Grid.zone_open(nblk[i]) and _out[i] == 0 and _wreg[i] == 0:
					_label += 1
					_wreg[i] = _label
					_qh = 0
					_qt = 0
					_queue[_qt] = i
					_qt += 1
					found = true
					break
				if work >= budget or ((work & 255) == 0 and Time.get_ticks_usec() - t0 >= max_usec):
					break
			if not found and _scan >= NW * NH:
				_phase = 3
				_scan = 0
				_lost = 0
				_gained = 0
				_cells = 0
				break
			if not found:
				break
	if _phase == 3:
		var n := NW * NH
		while _scan < n and work < budget:
			var i := _scan
			_scan += 1
			work += 1
			var was := region[i] > 0
			var now := _wreg[i] > 0
			if was and not now and Grid.zone_open(nblk[i]):
				_lost += 1
			elif now and not was:
				_gained += 1
			if now:
				_cells += 1
				_mask[i] = 255
			else:
				_mask[i] = 0
			if (work & 255) == 0 and Time.get_ticks_usec() - t0 >= max_usec:
				break
		if _scan >= n:
			_usec += Time.get_ticks_usec() - t0
			_finish()
			return
	_usec += Time.get_ticks_usec() - t0

func _flood(v: int, nblk: PackedByteArray) -> void:
	if _out[v] == 0 and Grid.zone_open(nblk[v]):
		_out[v] = 1
		_queue[_qt] = v
		_qt += 1

func _grow(v: int, nblk: PackedByteArray) -> void:
	if _wreg[v] == 0 and _out[v] == 0 and Grid.zone_open(nblk[v]):
		_wreg[v] = _label
		_queue[_qt] = v
		_qt += 1

func _finish() -> void:
	_phase = 0
	var t0 := Time.get_ticks_usec()
	var tmp := region
	region = _wreg
	_wreg = tmp
	zone_cells = _cells
	zone_count = _label
	mask_image.set_data(NW, NH, false, Image.FORMAT_L8, _mask)
	mask_tex.update(mask_image)
	version += 1
	_usec += Time.get_ticks_usec() - t0
	last_ms = _usec / 1000.0
	updated.emit(_lost > 6, _gained > 6)

func zone_at(p: Vector3) -> int:
	var c := Defs.world_to_nav(p)
	if not grid.ninb(c):
		return 0
	return region[grid.nidx(c)]

func zone_of_cells(cells: PackedInt32Array) -> int:
	for i in cells:
		var c := grid.ncell_of(i)
		for d in Grid.DIRS:
			var n := c + d
			if not grid.ninb(n):
				continue
			var r := region[grid.nidx(n)]
			if r > 0:
				return r
	return 0

func zone_of_building(b) -> int:
	return zone_of_cells(grid.building_nav_cells(b))
