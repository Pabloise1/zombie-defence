class_name QualityManager
extends Node
enum {AUTO, HIGH, MEDIUM, LOW}
const MODE_NAMES := ["Auto", "High", "Medium", "Low"]
const PINNED := {HIGH: 0, MEDIUM: 2, LOW: 5}
const TOP := 5
const BUDGET_MS := 1000.0 / 28.0
const UP_FRACTION := 0.7
# Under a frame cap the frame time sits at the cap, so climbing back up is
# judged on how busy the frame was (sim + render setup) instead.
const UP_BUSY_FRACTION := 0.55
const UP_HOLD := 3.5
const UP_HOLD_MAX := 60.0
const WINDOW := 2.0
const SETTINGS_PATH := "user://settings.cfg"
const ZOMBIE_SHADOWS := [true, false, false, false, false, false]
const LOD_BOOST := [0, 0, 1, 1, 2, 2]
const RES_SCALE := [1.0, 1.0, 0.85, 0.75, 0.7, 0.6]
const SUN_SHADOWS := [true, true, true, true, true, false]
const SHADOW_REACH := [1.0, 0.85, 0.75, 0.65, 0.55, 0.5]
const MESH_LOD := [1.0, 1.0, 2.0, 2.0, 4.0, 4.0]
const MSAA := [true, true, false, false, false, false]
const GLOW := [true, true, true, true, false, false]
const SHADOW_SIZE := [2048, 2048, 1024, 1024, 1024, 1024]
# Most zombies on the field at once. The rest of the wave waits its turn.
const HORDE := [640, 640, 560, 480, 420, 360]
# Phones and tablets: start at Medium and never climb above it on Auto,
# so a cool phone doesn't push itself until it overheats.
const MOBILE_CEILING := 2
const FPS_CHOICES := [30, 60]
var mode := AUTO
var level := 0
var forced_ms := -1.0
var mobile := false
var fps_cap := 0
var _ms := PackedFloat32Array()
var _busy := PackedFloat32Array()
var _span := 0.0
var _sum := 0.0
var _busy_sum := 0.0
var _up_t := 0.0
var _grace := 4.0
var _hold := {}
var _climbed_at := {}
var _clock := 0.0
var _zoom_shadows := true
var _shadow_size := 0
var _vp_rid := RID()

func _ready() -> void:
	mobile = _detect_mobile()
	fps_cap = default_fps()
	if not _testing():
		_load()
	_apply_fps()
	var vp := get_viewport()
	if vp:
		_vp_rid = vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	apply_level(_start_level())

func _testing() -> bool:
	return G.main != null and G.main.test_mode

static func _detect_mobile() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("(navigator.maxTouchPoints || 0) > 0 && window.matchMedia('(pointer: coarse)').matches", true)
		return v is bool and v
	return false

func default_fps() -> int:
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		return 0
	return 30 if mobile else 60

func _apply_fps() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = fps_cap

func next_fps() -> void:
	var i := FPS_CHOICES.find(fps_cap)
	fps_cap = FPS_CHOICES[(i + 1) % FPS_CHOICES.size()]
	_apply_fps()
	_go(level)
	_grace = 2.0
	_save()

func fps_label() -> String:
	return "%d FPS" % fps_cap if fps_cap > 0 else "No cap"

func _ceiling() -> int:
	return MOBILE_CEILING if mobile and mode == AUTO else 0

func _start_level() -> int:
	if mode != AUTO:
		return PINNED.get(mode, 0)
	return _ceiling()

func _frame_ms(dt: float) -> float:
	return forced_ms if forced_ms >= 0.0 else dt * 1000.0

func _busy_ms(ms: float) -> float:
	if forced_ms >= 0.0 or not _vp_rid.is_valid():
		return ms
	var sim := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw := RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu()
	return sim + draw

func tick(dt: float) -> void:
	_clock += dt
	follow_camera()
	var measuring := forced_ms >= 0.0 or DisplayServer.get_name() != "headless"
	if not measuring or mode != AUTO:
		return
	var ms := _frame_ms(dt)
	var busy := _busy_ms(ms)
	_ms.append(ms)
	_busy.append(busy)
	_sum += ms
	_busy_sum += busy
	_span += ms / 1000.0
	while _span > WINDOW and _ms.size() > 1:
		var old := _ms[0]
		_ms.remove_at(0)
		_sum -= old
		_busy_sum -= _busy[0]
		_busy.remove_at(0)
		_span -= old / 1000.0
	if _grace > 0.0:
		_grace -= dt
		return
	if _span < WINDOW * 0.95:
		return
	var avg := _sum / float(_ms.size())
	var avg_busy := _busy_sum / float(_busy.size())
	var capped := fps_cap > 0 and forced_ms < 0.0
	var budget := maxf(BUDGET_MS, 1000.0 / fps_cap * 1.07) if capped else BUDGET_MS
	var roomy := avg < budget * UP_FRACTION
	if capped:
		roomy = avg < budget and avg_busy < 1000.0 / fps_cap * UP_BUSY_FRACTION
	if avg > budget and level < TOP:
		if _climbed_at.has(level) and _clock - float(_climbed_at[level]) < 15.0:
			_hold[level] = minf(UP_HOLD_MAX, float(_hold.get(level, UP_HOLD)) * 2.0)
		_go(level + 1)
	elif roomy and level > _ceiling():
		_up_t += dt
		if _up_t >= float(_hold.get(level - 1, UP_HOLD)):
			_climbed_at[level - 1] = _clock
			_go(level - 1)
	else:
		_up_t = 0.0

func _go(l: int) -> void:
	apply_level(l)
	_ms.clear()
	_busy.clear()
	_sum = 0.0
	_busy_sum = 0.0
	_span = 0.0
	_up_t = 0.0

func apply_level(l: int) -> void:
	level = clampi(l, 0, TOP)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = RES_SCALE[level]
		vp.mesh_lod_threshold = MESH_LOD[level]
		vp.msaa_3d = Viewport.MSAA_2X if MSAA[level] else Viewport.MSAA_DISABLED
	if _shadow_size != SHADOW_SIZE[level]:
		_shadow_size = SHADOW_SIZE[level]
		RenderingServer.directional_shadow_atlas_set_size(_shadow_size, true)
	if G.zombies:
		G.zombies.lod_boost = LOD_BOOST[level]
	if G.main:
		if G.main.sun:
			G.main.sun.shadow_enabled = SUN_SHADOWS[level]
		if G.main.world_env and G.main.world_env.environment:
			G.main.world_env.environment.glow_enabled = GLOW[level]
	_zombie_shadows()
	follow_camera()

func horde_cap() -> int:
	return HORDE[level]

func follow_camera() -> void:
	if G.cam == null or G.main == null or G.main.sun == null:
		return
	var d: float = G.cam.dist
	G.main.sun.directional_shadow_max_distance = clampf(d * 1.7 + 25.0, 50.0, 190.0) * SHADOW_REACH[level]
	var want := _zoom_shadows
	if d > 78.0:
		want = false
	elif d < 70.0:
		want = true
	if want != _zoom_shadows:
		_zoom_shadows = want
		_zombie_shadows()

func _zombie_shadows() -> void:
	if G.zombies:
		var on: bool = ZOMBIE_SHADOWS[level] and _zoom_shadows
		if G.zombies.shadows != on:
			G.zombies.set_shadows(on)

func set_mode(m: int) -> void:
	mode = clampi(m, AUTO, LOW)
	_hold.clear()
	_go(_start_level())
	_grace = 2.0
	_save()

func next_mode() -> void:
	set_mode((mode + 1) % 4)

func label() -> String:
	if mode == AUTO:
		return "Auto (%s now)" % level_name(level)
	return MODE_NAMES[mode]

static func level_name(l: int) -> String:
	if l <= 0:
		return "High"
	if l <= 2:
		return "Medium"
	return "Low"

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		mode = clampi(int(cf.get_value("graphics", "quality", AUTO)), AUTO, LOW)
		var f := int(cf.get_value("graphics", "fps", fps_cap))
		if FPS_CHOICES.has(f):
			fps_cap = f

func _save() -> void:
	if _testing():
		return
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("graphics", "quality", mode)
	cf.set_value("graphics", "fps", fps_cap)
	cf.save(SETTINGS_PATH)
