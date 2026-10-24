class_name CameraRig
extends Node3D
signal tapped(screen_pos: Vector2)
const MIN_DIST := 14.0
const MAX_DIST := 95.0
const TAP_MOVE := 14.0
var cam: Camera3D
var target := Vector3(0, 0, 8)
var yaw := 0.0
var dist := 40.0
var _t_target := Vector3(0, 0, 8)
var _t_yaw := 0.0
var _t_dist := 40.0
var _vel := Vector3.ZERO
var _shake := 0.0
var _shake_t := 0.0
var _touches := {}
var _start := {}
var _moved := false
var _tool_touch := -1
var _pinch_d := 0.0
var _pinch_a := 0.0
var _pinch_mid := Vector2.ZERO
var _mouse_drag := false
var _mouse_rot := false
var _mouse_down_pos := Vector2.ZERO
var _mouse_tool := false
var _t_down := 0
var _fling := InputClass.Fling.new()
var clock_ms := -1
var enabled := true
var ui_block := true

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.5
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	get_viewport().size_changed.connect(_fit_aspect)
	_fit_aspect()
	_apply(0.0)

func pitch_for(d: float) -> float:
	var f := inverse_lerp(MIN_DIST, MAX_DIST, d)
	return deg_to_rad(lerpf(48.0, 64.0, f))

func _fit_aspect() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0.0:
		return
	if vs.x / vs.y < 0.8:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 44.0
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 42.0

func _apply(dt: float) -> void:
	var k := 1.0 if dt <= 0.0 else minf(1.0, dt * 12.0)
	target = target.lerp(_t_target, k)
	yaw = lerp_angle(yaw, _t_yaw, k)
	dist = lerpf(dist, _t_dist, k)
	var p := pitch_for(dist)
	var off := Vector3(0, sin(p), cos(p)) * dist
	off = off.rotated(Vector3.UP, yaw)
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake_t += dt * 40.0
		shake = Vector3(sin(_shake_t * 1.3), sin(_shake_t * 1.7 + 1.0), cos(_shake_t * 1.1)) * _shake * 0.35
	cam.global_position = target + off + shake
	cam.look_at(target + shake * 0.5, Vector3.UP)

func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.5)

func focus(p: Vector3, d: float = -1.0) -> void:
	_t_target = Vector3(p.x, 0, p.z)
	if d > 0.0:
		_t_dist = d

func snap() -> void:
	target = _t_target
	yaw = _t_yaw
	dist = _t_dist
	_apply(0.0)

func _now() -> int:
	return clock_ms if clock_ms >= 0 else Time.get_ticks_msec()

func _process(dt: float) -> void:
	if _vel.length_squared() > 0.0001 and _touches.is_empty() and not _mouse_drag:
		_t_target += _vel * dt
		_vel *= exp(-InputClass.Fling.DECAY * dt)
		if _vel.length() < 0.3:
			_vel = Vector3.ZERO
	_clamp_target()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt * 1.8)
	_apply(dt)

func _clamp_target() -> void:
	var lim := Defs.HALF + 4.0
	_t_target.x = clampf(_t_target.x, -lim, lim)
	_t_target.z = clampf(_t_target.z, -lim, lim)
	_t_target.y = 0.0

func ground_at(sp: Vector2, plane_y: float = 0.0) -> Vector3:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	var t := (plane_y - o.y) / d.y
	if t < 0.0:
		return Vector3.INF
	return o + d * t

func _pan_by_screen(from: Vector2, to: Vector2) -> void:
	var a := ground_at(from)
	var b := ground_at(to)
	if a == Vector3.INF or b == Vector3.INF:
		return
	var delta := a - b
	_t_target += delta
	target += delta

func _max_glide() -> float:
	return dist * 1.4

func _start_glide() -> void:
	_vel = _fling.release(_now(), _max_glide())
	_fling.reset()

func _over_ui(p: Vector2) -> bool:
	return ui_block and G.hud != null and G.hud.is_over_ui(p)

func _was_tap(start: Vector2, end: Vector2, t0: int) -> bool:
	return not _moved and InputClass.is_tap(start.distance_to(end), Time.get_ticks_msec() - t0)

func _unhandled_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventScreenTouch:
		_touch(e)
	elif e is InputEventScreenDrag:
		_drag(e)
	elif e is InputEventMouseButton:
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_mouse_button(e)
	elif e is InputEventMouseMotion:
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_mouse_motion(e)
	elif e is InputEventMagnifyGesture:
		_t_dist = clampf(_t_dist / e.factor, MIN_DIST, MAX_DIST)
	elif e is InputEventPanGesture:
		_t_dist = clampf(_t_dist * (1.0 + e.delta.y * 0.05), MIN_DIST, MAX_DIST)

func _touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if _touches.is_empty() and _over_ui(e.position):
			return
		_touches[e.index] = e.position
		_start[e.index] = e.position
		_vel = Vector3.ZERO
		_fling.reset()
		if _touches.size() == 1:
			_moved = false
			_t_down = _now()
			if G.builder and G.builder.wants_grab(e.position):
				_tool_touch = e.index
				G.builder.grab_start(e.position)
		elif _touches.size() >= 2:
			if _tool_touch >= 0:
				G.builder.grab_cancel()
				_tool_touch = -1
			_moved = true
			_begin_pinch()
		get_viewport().set_input_as_handled()
	else:
		if not _touches.has(e.index):
			return
		var was_single := _touches.size() == 1
		var tap := was_single and _was_tap(_start[e.index], e.position, _t_down)
		_touches.erase(e.index)
		if e.index == _tool_touch:
			_tool_touch = -1
			G.builder.grab_end(e.position, tap)
		elif tap:
			tapped.emit(e.position)
			if G.builder:
				G.builder.tap(e.position)
		elif was_single and _moved:
			_start_glide()
		if _touches.size() == 1:
			var k = _touches.keys()[0]
			_start[k] = _touches[k]
			_fling.reset()
			_vel = Vector3.ZERO
		elif _touches.size() >= 2:
			_begin_pinch()
		get_viewport().set_input_as_handled()

func _drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var prev: Vector2 = _touches[e.index]
	_touches[e.index] = e.position
	if _touches.size() == 1:
		if not _moved and e.position.distance_to(_start[e.index]) >= InputClass.TAP_PX:
			_moved = true
		if e.index == _tool_touch:
			G.builder.grab_move(e.position)
		else:
			_pan_by_screen(prev, e.position)
			_fling.add(_now(), e.position, _t_target)
	elif _touches.size() >= 2:
		_update_pinch()
	get_viewport().set_input_as_handled()

func _two() -> Array:
	var ks := _touches.keys()
	return [_touches[ks[0]], _touches[ks[1]]]

func _begin_pinch() -> void:
	var t := _two()
	var a: Vector2 = t[0]
	var b: Vector2 = t[1]
	_pinch_d = maxf(1.0, a.distance_to(b))
	_pinch_a = (b - a).angle()
	_pinch_mid = (a + b) * 0.5

func _update_pinch() -> void:
	var t := _two()
	var a: Vector2 = t[0]
	var b: Vector2 = t[1]
	var d := maxf(1.0, a.distance_to(b))
	var ang := (b - a).angle()
	var mid := (a + b) * 0.5
	_pan_by_screen(_pinch_mid, mid)
	_t_dist = clampf(_t_dist * (_pinch_d / d), MIN_DIST, MAX_DIST)
	var da := wrapf(ang - _pinch_a, -PI, PI)
	_t_yaw += da
	yaw += da
	_pinch_d = d
	_pinch_a = ang
	_pinch_mid = mid

func _mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				_t_dist = clampf(_t_dist * 0.88, MIN_DIST, MAX_DIST)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				_t_dist = clampf(_t_dist * 1.13, MIN_DIST, MAX_DIST)
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				if _over_ui(e.position):
					return
				_mouse_down_pos = e.position
				_moved = false
				_vel = Vector3.ZERO
				_fling.reset()
				_t_down = _now()
				if G.builder and G.builder.wants_grab(e.position):
					_mouse_tool = true
					G.builder.grab_start(e.position)
				else:
					_mouse_drag = true
			else:
				var tap := _was_tap(_mouse_down_pos, e.position, _t_down)
				if _mouse_tool:
					_mouse_tool = false
					G.builder.grab_end(e.position, tap)
				elif _mouse_drag:
					_mouse_drag = false
					if tap:
						tapped.emit(e.position)
						if G.builder:
							G.builder.tap(e.position)
					elif _moved:
						_start_glide()
		MOUSE_BUTTON_RIGHT:
			_mouse_rot = e.pressed
			if e.pressed and _mouse_tool:
				_mouse_tool = false
				G.builder.grab_cancel()
		MOUSE_BUTTON_MIDDLE:
			_mouse_drag = e.pressed

func _mouse_motion(e: InputEventMouseMotion) -> void:
	if _mouse_rot:
		_t_yaw -= e.relative.x * 0.008
		yaw = _t_yaw
		return
	if (_mouse_tool or _mouse_drag) and not _moved and e.position.distance_to(_mouse_down_pos) >= InputClass.TAP_PX:
		_moved = true
	if _mouse_tool:
		G.builder.grab_move(e.position)
		return
	if _mouse_drag:
		_pan_by_screen(e.position - e.relative, e.position)
		_fling.add(_now(), e.position, _t_target)
