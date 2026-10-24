class_name CardModels
extends RefCounted

class ZoneInfo:
	extends RefCounted
	var zone_id := 0
	func _init(z: int) -> void:
		zone_id = z
	func card_title() -> String:
		return "Safe zone"
	func card_lines() -> Array:
		var cells := 0
		var reg: PackedInt32Array = G.zones.region
		for i in reg.size():
			if reg[i] == zone_id:
				cells += 1
		var guns := 0
		for b in G.buildings.guns():
			if b.zone == zone_id:
				guns += 1
		var people := 0
		for p in G.people.all_people():
			if not p.dead and G.zones.zone_at(p.position) == zone_id:
				people += 1
		var wood: int = G.walls.zone_walls(zone_id).size()
		var out := ["Area %d m²  ·  guns %d  ·  people %d" % [cells, guns, people]]
		if wood > 0:
			out.append("%d wooden wall piece%s around it" % [wood, "" if wood == 1 else "s"])
		return out
	func card_buttons() -> Array:
		var c: int = G.walls.upgrade_zone_cost(zone_id)
		return [
			["upgrade_zone", "UPGRADE ALL %d" % c if c > 0 else "ALL CONCRETE", c > 0],
			["expand", "EXPAND", true],
			["auto_rebuild", "AUTO REBUILD", true],
		]

class SlotPick:
	extends RefCounted
	var host = null
	var slot := -1
	var seg = null
	var point := Vector3.ZERO
	func _init(h, i: int, s = null, p: Vector3 = Vector3.ZERO) -> void:
		host = h
		slot = i
		seg = s
		point = p
	func bonus() -> float:
		if seg != null:
			return float(Defs.BUILD[seg.kind].get("slot_bonus", 0.25))
		return host.slot_bonus() if host != null else 0.0
	func spot() -> Vector3:
		if seg != null:
			return seg.closest_point(point)
		return host.slot_xform(slot).origin
	func card_title() -> String:
		return "Mount a gun on the wall" if seg != null else "Gun slot"
	func card_lines() -> Array:
		var extra := ""
		if seg != null:
			extra = "  ·  nest %d" % int(Defs.BUILD["nest"]["cost"])
		return ["Raised: +%d%% range, out of zombies' reach%s" % [int(bonus() * 100.0), extra], "Needs a crew: a loader or soldier"]
	func card_buttons() -> Array:
		var out := []
		var extra := int(Defs.BUILD["nest"]["cost"]) if seg != null else 0
		for k in Defs.MOUNTABLE:
			var d: Dictionary = Defs.BUILD[k]
			var locked: bool = int(d.get("unlock", 0)) > G.main.wave
			var cost := int(d["cost"]) + extra
			var label := "%s %d" % [String(d["name"]).to_upper(), cost]
			if locked:
				label = "%s W%d" % [String(d["name"]).to_upper(), int(d.get("unlock", 0))]
			out.append(["mount:" + k, label, not locked and G.main.supplies >= cost])
		return out

class Settings:
	extends RefCounted
	func card_title() -> String:
		return "Settings"
	static func master_volume() -> float:
		return db_to_linear(AudioServer.get_bus_volume_db(0))
	func card_slider() -> float:
		return master_volume()
	func slider_label() -> String:
		return "Volume %d%%" % int(round(master_volume() * 100.0))
	func set_slider(v: float) -> void:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))
		AudioServer.set_bus_mute(0, v <= 0.01)
	static func diagnostic() -> String:
		var mode: int = int(ProjectSettings.get_setting("audio/general/default_playback_type.web", 1))
		var ptype := "Sample" if mode == 1 else "Stream"
		if not OS.has_feature("web"):
			return "Desktop  ·  %d Hz  ·  %s" % [int(AudioServer.get_mix_rate()), "muted" if AudioServer.is_bus_mute(0) else "on"]
		var raw = JavaScriptBridge.eval("window.zdAudioInfo ? window.zdAudioInfo() : '{}'", true)
		var d = JSON.parse_string(String(raw)) if raw != null else null
		if not (d is Dictionary):
			d = {}
		var err := String(d.get("err", ""))
		return "ctx %s  ·  %d Hz  ·  %s\nsession %s  ·  err %s" % [String(d.get("state", "?")), int(d.get("rate", 0)), ptype, String(d.get("session", "n/a")), err if err != "" else "none"]
	func card_lines() -> Array:
		var out := []
		if G.main and G.main.quality:
			out.append("Graphics: %s  ·  %s" % [G.main.quality.label(), G.main.quality.fps_label()])
		out.append_array(Array(diagnostic().split("\n")))
		return out
	func card_buttons() -> Array:
		var q := "AUTO"
		var f := "60"
		if G.main and G.main.quality:
			q = QualityManager.MODE_NAMES[G.main.quality.mode].to_upper()
			f = str(G.main.quality.fps_cap) if G.main.quality.fps_cap > 0 else "MAX"
		return [["quality", "QUALITY: %s" % q, true], ["fps", "FPS: %s" % f, true], ["sound_test", "TEST SOUND", true], ["mute", "UNMUTE" if AudioServer.is_bus_mute(0) else "MUTE", true]]

class Ask:
	extends RefCounted
	var title := ""
	var lines: Array = []
	var yes_id := ""
	var no_id := ""
	var payload = null
	func _init(t: String, l: Array, y: String, n: String, data = null) -> void:
		title = t
		lines = l
		yes_id = y
		no_id = n
		payload = data
	func card_title() -> String:
		return title
	func card_lines() -> Array:
		return lines
	func card_buttons() -> Array:
		return [[yes_id, "YES", true], [no_id, "NO", true]]
