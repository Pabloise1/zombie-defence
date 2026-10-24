extends Node
const DIR := "res://audio/sfx/"
const MAX_VOICES := 24
const UI_VOICES := 6
const MAX_LOOPS := 8
const UNIT_SIZE := 9.0
const PITCH_VAR := 0.05
const WORLD := {
	"mg_shot": [4, -2.0, 6, 0.045, 55.0, 1],
	"mg_tail": [1, -3.0, 3, 0.25, 55.0, 1],
	"rifle_shot": [3, -2.0, 5, 0.06, 55.0, 1],
	"sniper_shot": [3, 0.0, 2, 0.15, 110.0, 3],
	"mortar_launch": [2, 0.0, 3, 0.1, 100.0, 2],
	"mortar_whistle": [1, -3.0, 3, 0.2, 80.0, 2],
	"explosion": [3, 0.0, 4, 0.06, 130.0, 3],
	"mine_explosion": [2, 0.0, 3, 0.06, 120.0, 3],
	"flame_ignite": [1, -1.0, 3, 0.3, 60.0, 2],
	"casings": [3, -5.0, 3, 0.08, 30.0, 0],
	"impact_flesh": [3, -6.0, 4, 0.04, 40.0, 0],
	"impact_dirt": [3, -7.0, 4, 0.04, 40.0, 0],
	"impact_metal": [3, -6.0, 3, 0.05, 40.0, 0],
	"ammo_low": [1, -4.0, 1, 0.5, 40.0, 1],
	"no_ammo": [1, -2.0, 2, 0.6, 50.0, 2],
	"reload": [1, -4.0, 2, 0.4, 40.0, 1],
	"zombie_groan": [9, -8.0, 3, 0.7, 45.0, 0],
	"zombie_attack": [3, -5.0, 4, 0.08, 45.0, 1],
	"zombie_death": [3, -4.0, 4, 0.08, 50.0, 1],
	"runner_shriek": [3, -3.0, 2, 0.5, 70.0, 2],
	"brute_roar": [3, 0.0, 2, 0.8, 100.0, 3],
	"brute_step": [3, -4.0, 3, 0.12, 60.0, 1],
	"body_fall": [2, -6.0, 3, 0.08, 40.0, 0],
	"hit_wood": [3, -5.0, 4, 0.06, 50.0, 1],
	"hit_concrete": [3, -5.0, 4, 0.06, 50.0, 1],
	"hit_metal": [3, -6.0, 4, 0.06, 50.0, 1],
	"collapse": [2, 0.0, 3, 0.15, 110.0, 3],
	"gate_open": [1, -2.0, 2, 0.3, 60.0, 2],
	"gate_close": [1, -2.0, 2, 0.3, 60.0, 2],
	"hammer": [4, -7.0, 4, 0.12, 40.0, 0],
	"saw": [2, -9.0, 2, 0.6, 40.0, 0],
	"dig": [3, -7.0, 3, 0.25, 40.0, 0],
	"build_complete": [1, -2.0, 3, 0.1, 70.0, 2],
	"civilian_scream": [5, -4.0, 2, 0.9, 60.0, 2],
	"spike_trap": [2, -4.0, 3, 0.08, 45.0, 1],
	"mine_click": [1, -3.0, 2, 0.05, 40.0, 2],
	"wire_rattle": [2, -8.0, 2, 0.3, 40.0, 0],
}
const UI := {
	"ui_tap": [1, -4.0, 0.03],
	"ui_place": [1, -2.0, 0.05],
	"ui_invalid": [1, -3.0, 0.15],
	"ui_cancel": [1, -4.0, 0.05],
	"ui_sell": [1, -3.0, 0.1],
	"ui_recruit": [1, -2.0, 0.1],
	"ui_assign": [1, -3.0, 0.05],
	"ui_confirm": [1, -3.0, 0.1],
	"ui_open": [1, -5.0, 0.05],
	"ui_close": [1, -5.0, 0.05],
	"wave_start": [1, -3.0, 2.0],
	"wave_cleared": [1, -2.0, 1.0],
	"zone_breached": [1, -1.0, 1.0],
}
const LOOPS := {
	"flame_loop": [-3.0, 60.0],
	"rotor_loop": [-2.0, 140.0],
	"amb_wind": [-4.0, 0.0],
	"amb_horde": [-2.0, 0.0],
}
const ALIASES := {
	"shot": "mg_shot", "rifle": "rifle_shot", "sniper": "sniper_shot",
	"boom": "explosion", "mortar": "mortar_launch", "click": "mine_click",
	"spike": "spike_trap", "thud": "body_fall", "hit_wall": "hit_wood",
	"build": "build_complete", "break": "collapse", "place": "ui_place",
	"siren": "wave_start", "groan": "zombie_groan", "scream": "civilian_scream",
}
const AUTO_TAIL := {"mg_shot": "mg_tail"}
const TAIL_GAP := 0.28
const CASINGS_CHANCE := 0.12
var enabled := true
var _streams := {}
var _last_var := {}
var _last_start := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _voice_name: Array[String] = []
var _voice_prio: Array[int] = []
var _voice_t: Array[float] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_next := 0
var _loops := {}
var _sustain := {}
var _tails := {}
var _delayed: Array = []
var _amb_wind: AudioStreamPlayer
var _amb_horde: AudioStreamPlayer
var _amb_on := false
var _horde_target := 0.0
var _horde_level := 0.0
var _listener: AudioListener3D
var _world_root: Node3D
var _focus := Vector3.ZERO
var _focus_override := false
var _unlocked := true
var _watchdog := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_unlocked = not OS.has_feature("web")
	_ensure_buses()
	_load_all()
	_world_root = Node3D.new()
	_world_root.name = "World"
	_world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world_root)
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = UNIT_SIZE
		p.max_db = 3.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 6000.0
		p.attenuation_filter_db = -10.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		_world_root.add_child(p)
		_pool.append(p)
		_voice_name.append("")
		_voice_prio.append(-1)
		_voice_t.append(-100.0)
	for i in UI_VOICES:
		var u := AudioStreamPlayer.new()
		u.bus = &"UI"
		add_child(u)
		_ui_pool.append(u)
	_amb_wind = _make_amb("amb_wind")
	_amb_horde = _make_amb("amb_horde")
	_listener = AudioListener3D.new()
	_listener.name = "Listener"
	add_child(_listener)
	_listener.make_current()

func play(sound: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled:
		return
	var n: String = ALIASES.get(sound, sound)
	if sound == "flame":
		sustain("flame_loop", pos, pos, "flame_ignite")
		return
	if UI.has(n):
		play_ui(n, volume_db)
		return
	if not WORLD.has(n):
		_warn_once(n)
		return
	if not _unlocked:
		return
	var d: Array = WORLD[n]
	var max_dist: float = d[4]
	var flat := Vector2(pos.x - _focus.x, pos.z - _focus.z)
	if flat.length() > max_dist:
		return
	var now := _now()
	if now - float(_last_start.get(n, -100.0)) < float(d[3]):
		_note_emitter(n, pos, now)
		return
	var slot := _find_slot(n, int(d[2]), int(d[5]), now, flat.length())
	if slot < 0:
		return
	_last_start[n] = now
	var p := _pool[slot]
	p.stream = _pick(n)
	p.global_position = pos
	p.max_distance = max_dist
	p.volume_db = float(d[1]) + volume_db
	p.pitch_scale = pitch * _rng.randf_range(1.0 - PITCH_VAR, 1.0 + PITCH_VAR)
	p.play()
	_voice_name[slot] = n
	_voice_prio[slot] = int(d[5])
	_voice_t[slot] = now
	_note_emitter(n, pos, now)
	if n == "mg_shot" and _rng.randf() < CASINGS_CHANCE:
		play_delayed("casings", pos + Vector3(0, -0.6, 0), _rng.randf_range(0.12, 0.25))

func play_ui(sound: String, volume_db: float = 0.0) -> void:
	if not enabled or not _unlocked:
		return
	var n: String = ALIASES.get(sound, sound)
	if not UI.has(n):
		if WORLD.has(n):
			_play_flat(n, float(WORLD[n][1]) + volume_db)
		else:
			_warn_once(n)
		return
	var d: Array = UI[n]
	var now := _now()
	if now - float(_last_start.get(n, -100.0)) < float(d[2]):
		return
	_last_start[n] = now
	_play_flat(n, float(d[1]) + volume_db)

func play_delayed(sound: String, pos: Vector3, delay: float) -> void:
	_delayed.append([_now() + delay, sound, pos])

func loop(sound: String, node: Node3D, volume_db: float = 0.0) -> void:
	if not enabled or node == null or not LOOPS.has(sound):
		return
	var key := "%d:%s" % [node.get_instance_id(), sound]
	if _loops.has(key):
		var e: Dictionary = _loops[key]
		if is_instance_valid(e.player):
			e.fading = false
			e.want_db = float(LOOPS[sound][0]) + volume_db
			return
		_loops.erase(key)
	if _loops.size() >= MAX_LOOPS:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = _pick(sound)
	p.unit_size = UNIT_SIZE
	p.max_db = 3.0
	p.max_distance = float(LOOPS[sound][1])
	p.attenuation_filter_cutoff_hz = 6000.0
	p.attenuation_filter_db = -10.0
	p.volume_db = -30.0
	node.add_child(p)
	if _unlocked:
		p.play()
	_loops[key] = {"player": p, "name": sound, "want_db": float(LOOPS[sound][0]) + volume_db, "fading": false}

func stop_loop(node: Node3D, sound: String = "", fade: float = 0.3) -> void:
	if node == null:
		return
	var prefix := "%d:" % node.get_instance_id()
	for key in _loops.keys():
		if String(key).begins_with(prefix) and (sound == "" or String(key).ends_with(":" + sound)):
			_loops[key].fading = true
			_loops[key].fade = maxf(0.01, fade)

func sustain(loop_sound: String, key_pos: Vector3, pos: Vector3, start_sound: String = "") -> void:
	if not enabled or not _unlocked:
		return
	var key := "%d,%d" % [roundi(key_pos.x * 2.0), roundi(key_pos.z * 2.0)]
	var now := _now()
	if _sustain.has(key):
		_sustain[key].until = now + 0.35
		return
	var flat := Vector2(pos.x - _focus.x, pos.z - _focus.z)
	if flat.length() > float(LOOPS[loop_sound][1]):
		return
	if start_sound != "":
		play(start_sound, pos)
	var anchor := Node3D.new()
	_world_root.add_child(anchor)
	anchor.global_position = pos
	loop(loop_sound, anchor)
	_sustain[key] = {"anchor": anchor, "until": now + 0.35}

func set_ambience(horde_intensity: float) -> void:
	_amb_on = true
	_horde_target = clampf(horde_intensity, 0.0, 1.0)
	if _unlocked:
		_start_amb()

func stop_ambience() -> void:
	_amb_on = false
	if _amb_wind:
		_amb_wind.stop()
	if _amb_horde:
		_amb_horde.stop()

func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)

func set_listener_focus(pos: Vector3, use: bool = true) -> void:
	_focus = pos
	_focus_override = use

func hit_structure(kind: String, pos: Vector3) -> void:
	play(material_hit(kind), pos)

func material_hit(kind: String) -> String:
	match kind:
		"concrete", "garrison", "flame", "hq":
			return "hit_concrete"
		"gate", "turret", "mortar", "wire", "spikes", "mine":
			return "hit_metal"
	return "hit_wood"

func _process(dt: float) -> void:
	_update_listener()
	var now := _now()
	if not _delayed.is_empty():
		var keep: Array = []
		for e in _delayed:
			if now >= float(e[0]):
				play(String(e[1]), e[2])
			else:
				keep.append(e)
		_delayed = keep
	if not _tails.is_empty():
		for k in _tails.keys():
			var t: Dictionary = _tails[k]
			if now - float(t.t) > TAIL_GAP:
				_tails.erase(k)
				play(String(AUTO_TAIL[t.name]), t.pos)
	for k in _sustain.keys():
		var s: Dictionary = _sustain[k]
		if now > float(s.until):
			_sustain.erase(k)
			if is_instance_valid(s.anchor):
				stop_loop(s.anchor, "", 0.35)
				s.anchor.get_tree().create_timer(0.6, true).timeout.connect(s.anchor.queue_free)
	for key in _loops.keys():
		var e: Dictionary = _loops[key]
		if not is_instance_valid(e.player):
			_loops.erase(key)
			continue
		var p: AudioStreamPlayer3D = e.player
		if e.fading:
			p.volume_db -= dt * 60.0 / float(e.get("fade", 0.3))
			if p.volume_db < -60.0:
				p.queue_free()
				_loops.erase(key)
		else:
			p.volume_db = move_toward(p.volume_db, float(e.want_db), dt * 90.0)
	if _amb_on and _amb_horde:
		_horde_level = move_toward(_horde_level, _horde_target, dt * 0.5)
		var lin := pow(_horde_level, 0.7)
		_amb_horde.volume_db = float(LOOPS["amb_horde"][0]) + linear_to_db(maxf(lin, 0.0005))
	_watchdog -= dt
	if _watchdog <= 0.0:
		_watchdog = 1.0
		if _unlocked:
			if _amb_on:
				_start_amb()
			for key in _loops.keys():
				var p2: AudioStreamPlayer3D = _loops[key].player
				if is_instance_valid(p2) and not p2.playing and not _loops[key].fading:
					p2.play()

func _exit_tree() -> void:
	for p in _pool:
		p.stop()
	for u in _ui_pool:
		u.stop()
	stop_ambience()
	for key in _loops.keys():
		var p2 = _loops[key].player
		if is_instance_valid(p2):
			p2.stop()

func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_unlocked = true
		_watchdog = 0.05

func _update_listener() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if not _focus_override:
		var found := false
		var g := get_node_or_null("/root/G")
		if g != null:
			var rig = g.get("cam")
			if rig != null and is_instance_valid(rig) and "target" in rig:
				_focus = rig.target
				found = true
		if not found:
			var o := cam.global_position
			var dir := -cam.global_basis.z
			if absf(dir.y) > 0.01:
				var t := -o.y / dir.y
				if t > 0.0:
					_focus = o + dir * t
	var h := clampf(cam.global_position.distance_to(_focus) * 0.22, 4.0, 16.0)
	_listener.global_transform = Transform3D(cam.global_basis, _focus + Vector3.UP * h)

func _find_slot(n: String, cap: int, prio: int, now: float, dist: float) -> int:
	var same := 0
	var oldest_same := -1
	var free := -1
	for i in _pool.size():
		if not _pool[i].playing:
			_voice_name[i] = ""
			if free < 0:
				free = i
			continue
		if _voice_name[i] == n:
			same += 1
			if oldest_same < 0 or _voice_t[i] < _voice_t[oldest_same]:
				oldest_same = i
	if same >= cap:
		if oldest_same >= 0 and now - _voice_t[oldest_same] > 0.03:
			_pool[oldest_same].stop()
			return oldest_same
		return -1
	if free >= 0:
		return free
	var best := -1
	for i in _pool.size():
		if _voice_prio[i] > prio:
			continue
		if best < 0 or _voice_prio[i] < _voice_prio[best] or (_voice_prio[i] == _voice_prio[best] and _voice_t[i] < _voice_t[best]):
			best = i
	if best >= 0:
		_pool[best].stop()
	return best

func _note_emitter(n: String, pos: Vector3, now: float) -> void:
	if not AUTO_TAIL.has(n):
		return
	var k := "%d,%d" % [roundi(pos.x / 3.0), roundi(pos.z / 3.0)]
	_tails[k] = {"name": n, "pos": pos, "t": now}

func _play_flat(n: String, vol: float) -> void:
	var u := _ui_pool[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_pool.size()
	u.stream = _pick(n)
	u.volume_db = vol
	u.pitch_scale = 1.0
	u.play()

func _pick(n: String) -> AudioStream:
	var arr: Array = _streams.get(n, [])
	if arr.is_empty():
		return null
	var i := 0
	if arr.size() > 1:
		i = _rng.randi_range(0, arr.size() - 2)
		if i >= int(_last_var.get(n, -1)):
			i += 1
	_last_var[n] = i
	return arr[i]

func _load_all() -> void:
	for n in WORLD:
		_load_set(n, int(WORLD[n][0]), false)
	for n in UI:
		_load_set(n, int(UI[n][0]), false)
	for n in LOOPS:
		_load_set(n, 1, true)

func _load_set(n: String, count: int, looping: bool) -> void:
	var arr: Array = []
	for i in count:
		var path := DIR + (n + ".ogg" if count == 1 else "%s_%d.ogg" % [n, i + 1])
		if not ResourceLoader.exists(path):
			push_warning("Sfx: missing " + path)
			continue
		var s = load(path)
		if s is AudioStreamOggVorbis:
			s.loop = looping
		if s != null:
			arr.append(s)
	_streams[n] = arr

func _make_amb(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambience"
	p.stream = _pick(n)
	p.volume_db = float(LOOPS[n][0]) if n == "amb_wind" else -60.0
	add_child(p)
	return p

func _start_amb() -> void:
	if _amb_wind and not _amb_wind.playing and _amb_wind.stream:
		_amb_wind.play(_rng.randf_range(0.0, 20.0))
	if _amb_horde and not _amb_horde.playing and _amb_horde.stream:
		_amb_horde.play(_rng.randf_range(0.0, 20.0))

func _ensure_buses() -> void:
	for b in ["SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	var a := AudioServer.get_bus_index("Ambience")
	if a >= 0 and AudioServer.get_bus_volume_db(a) == 0.0:
		AudioServer.set_bus_volume_db(a, -3.0)
var _warned := {}

func _warn_once(n: String) -> void:
	if not _warned.has(n):
		_warned[n] = true
		push_warning("Sfx: unknown sound '%s'" % n)

func _now() -> float:
	return Time.get_ticks_msec() * 0.001
