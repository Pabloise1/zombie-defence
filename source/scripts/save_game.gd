class_name SaveGame
extends RefCounted
# Autosave and continue. The game is saved between waves (when a wave is
# cleared, when the next one starts, and every so often while building), so
# a reload or crash puts you back at the start of the wave you were on.
# Everything is rebuilt through the normal placement code, in dependency
# order: map claims, trenches, walls, buildings, mounted guns, people, posts.
const PATH := "user://save.dat"
const TMP := "user://save.tmp"
const VERSION := 1

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return {}
	return d

static func summary() -> Dictionary:
	var d := read()
	if d.is_empty():
		return {}
	return {"wave": int(d["wave"]), "map": String(d["map"]), "people": int(d.get("people_total", 0))}

static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)

static func write(m) -> void:
	var d := capture(m)
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(d)
	f.close()
	DirAccess.rename_absolute(TMP, PATH)

static func _common(b) -> Dictionary:
	var d := {"kind": b.kind, "state": b.state, "hp": b.hp, "progress": b.progress, "paid": b.paid,
		"mag": b.mag, "reserve": b.reserve, "rest": b.rest_yaw}
	if "crates" in b:
		d["crates"] = b.crates
	return d

static func _in_flux(b) -> bool:
	# Half-done wall upgrades and moves can't be rebuilt exactly: drop them
	# and give their supplies back instead.
	return b.state == Building.BLUEPRINT and (b.edit_group != null or b.move_from != null)

static func capture(m) -> Dictionary:
	var refund := 0
	var d := {"version": VERSION, "map": G.map_id, "seed": m.map_seed, "wave": m.wave, "waves_cleared": m.waves_cleared,
		"phase_t": m.phase_t if m.phase == "build" else 0.0, "kills": G.zombies.kills, "repair_spent": m.repair_spent,
		"hq_hp": G.buildings.hq.hp, "hq_crates": G.logi.hq_crates, "auto_rebuild": G.walls.auto_rebuild}
	var scrap := []
	for s in G.logi.salvage:
		scrap.append(s.scrap)
	d["scrap"] = scrap
	var claims := []
	var fences := []
	if G.map:
		for i in G.map.buildings.size():
			var mb = G.map.buildings[i]
			if is_instance_valid(mb) and mb.cleared:
				claims.append({"i": i, "cleared": true})
			elif is_instance_valid(mb) and (mb.claimed or mb.exploded or mb.state == Building.DEAD):
				claims.append({"i": i, "claimed": mb.claimed, "hp": mb.hp, "dead": mb.state == Building.DEAD, "exploded": mb.exploded})
		for i in G.map.fences.size():
			if G.map.fences[i].claimed:
				fences.append(i)
	d["claims"] = claims
	d["fences"] = fences
	var trench := []
	for i in G.grid.terrain.size():
		if G.grid.terrain[i] == Defs.T_TRENCH:
			trench.append(i)
	d["trench"] = trench
	var segs := []
	for s in G.walls.segments:
		if not is_instance_valid(s) or s.state == Building.DEAD:
			continue
		if _in_flux(s):
			refund += s.paid
			continue
		var e := _common(s)
		e["a"] = s.a
		e["b"] = s.b
		e["ported"] = s.ported
		e["heavy"] = s.heavy
		segs.append(e)
	d["segs"] = segs
	var ids := {}
	var things := []
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state == Building.DEAD or b == G.buildings.hq:
			continue
		if b is LinearStructure or b is MapBuilding or b.host != null:
			continue
		if _in_flux(b) or (b.moving_to != null and b.state == Building.BLUEPRINT):
			refund += b.paid
			continue
		var e2 := _common(b)
		if b is WallNest:
			e2["type"] = "nest"
			e2["pos"] = b.position
			e2["dir"] = b.line_dir
			e2["wall"] = b.wall_kind
		elif b is RoofBridge:
			e2["type"] = "bridge"
			e2["pa"] = b.pa
			e2["pb"] = b.pb
		elif b.rect:
			e2["type"] = "rect"
			e2["pos"] = b.position
			e2["yaw"] = b.yaw
			if b is RoomBlock:
				e2["storeys"] = b.storeys
			if b is Helipad and b.heli != null and is_instance_valid(b.heli):
				e2["heli"] = b.heli.kind
		else:
			e2["type"] = "ground"
			e2["cell"] = b.cell
			if b is FortModule:
				e2["levels"] = b.levels
				if b.raising:
					refund += b.raise_cost()
		ids[b] = "b%d" % things.size()
		things.append(e2)
	d["things"] = things
	if G.map:
		for i in G.map.buildings.size():
			ids[G.map.buildings[i]] = "m%d" % i
	var guns := []
	var crews := []
	for b in G.buildings.list:
		if not is_instance_valid(b) or b.state == Building.DEAD:
			continue
		if b.host != null and ids.has(b.host):
			if _in_flux(b):
				refund += b.paid
				continue
			var e3 := _common(b)
			e3["host"] = ids[b.host]
			e3["slot"] = b.slot_i
			guns.append(e3)
		if ids.has(b) and not b.occupants.is_empty():
			crews.append({"host": ids[b], "n": b.occupants.filter(func(o): return o is Soldier).size()})
	d["guns"] = guns
	d["crews"] = crews
	var jobs := {}
	for j in Defs.JOBS:
		jobs[j] = G.people.count_job(j)
	d["jobs"] = jobs
	d["idle"] = G.people.owned_civilians().size()
	d["people_total"] = G.people.population()
	d["supplies"] = m.supplies + refund
	return d

static func _v3(v) -> Vector3:
	return v if v is Vector3 else Vector3.ZERO

static func _apply_common(b, e: Dictionary) -> void:
	if b == null:
		return
	b.paid = int(e.get("paid", 0))
	if b.state == Building.BLUEPRINT:
		b.progress = float(e.get("progress", 0.0))
	else:
		b.hp = clampf(float(e.get("hp", b.max_hp)), 1.0, b.max_hp)
		if b.has_method("damage_look"):
			b.damage_look()
	if b.mag_size > 0:
		b.mag = int(e.get("mag", b.mag))
		b.reserve = int(e.get("reserve", b.reserve))
	if e.has("crates") and "crates" in b:
		b.crates = int(e["crates"])

static func _built(e: Dictionary) -> bool:
	return int(e.get("state", Building.BUILT)) == Building.BUILT

# Called from main._ready after the world is set up (map already built with
# the saved seed). Returns false if the save couldn't be used.
static func restore(m, d: Dictionary) -> bool:
	if d.is_empty():
		return false
	m.supplies = 1000000000
	m.wave = int(d["wave"])
	G.zombies.wave = m.wave
	m.waves_cleared = int(d.get("waves_cleared", m.wave - 1))
	m.repair_spent = int(d.get("repair_spent", 0))
	G.zombies.kills = int(d.get("kills", 0))
	G.walls.auto_rebuild = bool(d.get("auto_rebuild", true))
	var scrap: Array = d.get("scrap", [])
	for i in mini(scrap.size(), G.logi.salvage.size()):
		G.logi.salvage[i].scrap = int(scrap[i])
		G.logi.salvage[i].refresh()
	if G.map:
		for i in d.get("fences", []):
			if int(i) < G.map.fences.size():
				var run = G.map.fences[int(i)]
				run.claimed = true
				G.map.unblock(run.cells, run)
				G.map.hide_run(run)
		for c in d.get("claims", []):
			var mb = G.map.buildings[int(c["i"])] if int(c["i"]) < G.map.buildings.size() else null
			if mb == null:
				continue
			if bool(c.get("cleared", false)):
				mb._cleared(true)
				continue
			if bool(c.get("claimed", false)) or bool(c.get("dead", false)):
				mb.contents = {}
				mb._claimed(true)
				mb.hp = clampf(float(c.get("hp", mb.max_hp)), 1.0, mb.max_hp)
				if bool(c.get("dead", false)):
					mb.destroy(false)
			elif bool(c.get("exploded", false)):
				mb.exploded = true
				mb.def = mb.def.duplicate()
				mb.def["claim"] = 0
				mb.model.scale = Vector3(1, 0.7, 1)
	for i in d.get("trench", []):
		var c2 := Vector2i(int(i) % Defs.W, int(i) / Defs.W)
		G.grid.set_trench(c2)
		if G.terrain:
			G.terrain.cell_changed(c2)
		if m.decor:
			m.decor.clear_cell(c2)
	for e in d.get("segs", []):
		var s: LinearStructure = G.walls._make(e["kind"], _v3(e["a"]), _v3(e["b"]), _built(e), bool(e.get("ported", false)), bool(e.get("heavy", false)))
		_apply_common(s, e)
	G.walls.refresh_posts()
	var ids := {}
	if G.map:
		for i in G.map.buildings.size():
			ids["m%d" % i] = G.map.buildings[i]
	var things: Array = d.get("things", [])
	for k in things.size():
		var e2: Dictionary = things[k]
		var b = _restore_thing(m, e2)
		if b != null:
			ids["b%d" % k] = b
			_apply_common(b, e2)
	m.zones.compute_now()
	G.buildings.refresh_zones()
	for e3 in d.get("guns", []):
		var host = ids.get(e3["host"], null)
		if host == null or not is_instance_valid(host) or host.state != Building.BUILT:
			continue
		var g = G.buildings.mount(host, int(e3["slot"]), e3["kind"], false, _built(e3))
		_apply_common(g, e3)
	if G.buildings.hq:
		G.buildings.hq.hp = clampf(float(d.get("hq_hp", G.buildings.hq.max_hp)), 1.0, G.buildings.hq.max_hp)
	G.logi.hq_crates = int(d.get("hq_crates", G.logi.hq_crates))
	_restore_people(d)
	for c3 in d.get("crews", []):
		var post = ids.get(c3["host"], null)
		if post == null or not is_instance_valid(post):
			continue
		for n in int(c3["n"]):
			var idle: Array = G.soldiers.idle_soldiers()
			if idle.is_empty() or post.free_slots() <= 0:
				break
			idle[0].assign(post)
	m.zones.compute_now()
	G.buildings.refresh_zones()
	m.flow.compute_now()
	if G.net:
		G.net.dirty = true
	m.supplies = int(d.get("supplies", Defs.START_SUPPLIES))
	return true

static func _restore_thing(m, e: Dictionary):
	var kind: String = e["kind"]
	var built := _built(e)
	var b = null
	match String(e.get("type", "")):
		"ground":
			var c: Vector2i = e["cell"]
			if built:
				b = G.buildings.place_built(kind, c)
			elif G.buildings.place(kind, c, float(e.get("rest", 0.0))):
				b = G.buildings.last_placed
			if b != null and b.is_gun():
				b.set_rest(float(e.get("rest", 0.0)))
			if b is FortModule and built:
				for i in int(e.get("levels", 1)) - 1:
					b.finish_raise()
		"rect":
			var p := _v3(e["pos"])
			var yaw := float(e.get("yaw", 0.0))
			b = G.buildings.place_rect(kind, p, yaw, built)
			if b == null:
				var near := []
				for s in G.walls.live():
					if s.seg_distance(p) < 4.0:
						near.append(s)
				b = G.buildings.place_rect(kind, p, yaw, built, near)
			if b is RoomBlock and built:
				for i in int(e.get("storeys", 1)) - 1:
					b.finish_floor()
			if b is Helipad and built and e.has("heli"):
				b.heli = G.helis.add_heli(String(e["heli"]), b)
				b.heli.park_now()
				b.heli.rotor = 0.0
				if G.sfx:
					G.sfx.stop_loop(b.heli)
		"nest":
			var n := WallNest.new()
			G.buildings.add_child(n)
			n.setup_nest(_v3(e["pos"]), _v3(e["dir"]), String(e["wall"]), not built)
			G.buildings.list.append(n)
			if not built:
				G.workers.add_job(n)
			b = n
		"bridge":
			var pa := _v3(e["pa"])
			var pb := _v3(e["pb"])
			G.net.dirty = true
			var aa: Dictionary = G.net.anchor_near(pa, pb)
			var ab: Dictionary = G.net.anchor_near(pb, pa)
			if not aa.is_empty() and not ab.is_empty():
				b = G.buildings.place_bridge({"pos": pa, "ref": aa["ref"]}, {"pos": pb, "ref": ab["ref"]}, built)
	return b

static func _restore_people(d: Dictionary) -> void:
	var p = G.people
	for j in Defs.JOBS:
		while p.count_job(j) > 0:
			if p.remove_job(j) != "":
				break
	for c in p.civilians.duplicate():
		if is_instance_valid(c):
			c.queue_free()
	p.civilians.clear()
	var jobs: Dictionary = d.get("jobs", {})
	var total := int(d.get("idle", 0))
	for j in jobs:
		total += int(jobs[j])
	var door := Defs.hq_center() + Vector3(0, 0, 4.0)
	for i in total:
		p.spawn_civilian(door + Vector3(randf_range(-2.0, 2.0), 0, randf_range(0.0, 1.5)), true)
	for j in jobs:
		for i in int(jobs[j]):
			p.add_job(j)
