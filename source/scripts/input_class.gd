class_name InputClass
extends RefCounted
const TAP_PX := 10.0
const TAP_MS := 300

static func is_tap(moved_px: float, held_ms: int) -> bool:
	return moved_px < TAP_PX and held_ms < TAP_MS

class Fling:
	extends RefCounted
	const WINDOW_MS := 90
	const STILL_MS := 60
	const MIN_PX_S := 500.0
	const DECAY := 9.0
	var _t: Array = []
	var _sp: Array = []
	var _wp: Array = []
	func reset() -> void:
		_t.clear()
		_sp.clear()
		_wp.clear()
	func add(t_ms: int, screen: Vector2, world: Vector3) -> void:
		_t.append(t_ms)
		_sp.append(screen)
		_wp.append(world)
		while _t.size() > 2 and t_ms - int(_t[0]) > WINDOW_MS * 2:
			_t.pop_front()
			_sp.pop_front()
			_wp.pop_front()
	func release(now_ms: int, max_speed: float) -> Vector3:
		if _t.size() < 2:
			return Vector3.ZERO
		var last := int(_t[-1])
		if now_ms - last > STILL_MS:
			return Vector3.ZERO
		var wsum := 0.0
		var vs := Vector3.ZERO
		var ps := 0.0
		for i in range(_t.size() - 1, 0, -1):
			var t1 := int(_t[i])
			var t0 := int(_t[i - 1])
			if last - t0 > WINDOW_MS:
				break
			var dt := float(t1 - t0) / 1000.0
			if dt <= 0.0:
				continue
			var w := 1.0 - float(last - t1) / float(WINDOW_MS)
			w = maxf(w, 0.1) * dt
			vs += (Vector3(_wp[i]) - Vector3(_wp[i - 1])) / dt * w
			ps += (Vector2(_sp[i]) - Vector2(_sp[i - 1])).length() / dt * w
			wsum += w
		if wsum <= 0.0:
			return Vector3.ZERO
		var v := vs / wsum
		if ps / wsum < MIN_PX_S:
			return Vector3.ZERO
		v.y = 0.0
		if v.length() > max_speed:
			v = v.normalized() * max_speed
		return v
