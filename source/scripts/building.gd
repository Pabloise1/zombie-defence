class_name Building
extends Node3D
enum {BLUEPRINT, BUILT, DEAD}
var kind := ""
var def: Dictionary = {}
var cell := Vector2i.ZERO
var size := 1
var state := BLUEPRINT
var hp := 1.0
var max_hp := 1.0
var progress := 0.0
var worker = null
var order := 0
var paid := 0
var model: Node3D
var in_trench := false
var zone := 0
var loader = null
var hit_at := -100.0
var mag := 0
var mag_size := 0
var reserve := 0
var reserve_max := 0
var reload_t := 0.0
var _feed_t := 0.0
var _repair_debt := 0.0
var occupants: Array = []
var incoming: Array = []
var _pop := 0.0
var rect := false
var half := Vector2.ONE
var yaw := 0.0
var nav_list := PackedInt32Array()
var cell_list: Array[Vector2i] = []
var host = null
var on_host := false
var slot_i := -1
var mounted: Array = []
var rest_yaw := 0.0
var port_bonus := 0.0
var _port_t := 0.0
var edit_group = null
var replaced_by = null
var _dmg_stage := 0
var _rise: Node3D
var _scaffold: MeshInstance3D
var move_from = null
var moving_to = null

func init_building(k: String, c: Vector2i, d: Dictionary, blueprint: bool) -> void:
	kind = k
	def = d
	cell = c
	size = int(d.get("size", 1))
	_init_stats(d)
	in_trench = G.grid.is_trench(c)
	position = _footprint_center()
	_make_model()
	if blueprint:
		_as_blueprint()
	else:
		_finish(true)

func init_rect(k: String, p: Vector3, y: float, d: Dictionary, blueprint: bool, fp: Dictionary) -> void:
	kind = k
	def = d
	rect = true
	half = d.get("half", Vector2.ONE)
	yaw = y
	nav_list = fp["nav"]
	cell_list = fp["cells"]
	cell = cell_list[0] if not cell_list.is_empty() else Defs.world_to_cell(p)
	size = 1
	_init_stats(d)
	position = Vector3(p.x, 0, p.z)
	rotation.y = y
	_make_model()
	for i in slot_count():
		mounted.append(null)
	if blueprint:
		_as_blueprint()
	else:
		_finish(true)

func init_mounted(k: String, h, i: int, d: Dictionary, blueprint: bool) -> void:
	kind = k
	def = d
	host = h
	on_host = true
	slot_i = i
	size = 1
	_init_stats(d)
	var xf: Transform3D = h.slot_xform(i)
	position = xf.origin
	rest_yaw = xf.basis.get_euler().y
	h.mounted[i] = self
	_make_model()
	if blueprint:
		_as_blueprint()
	else:
		_finish(true)

func _init_stats(d: Dictionary) -> void:
	max_hp = maxf(1.0, float(d.get("hp", 100.0)))
	hp = max_hp
	mag_size = int(d.get("mag", 0))
	mag = mag_size
	reserve_max = int(d.get("reserve", 0))
	reserve = reserve_max

func _model_name() -> String:
	if host != null and kind == "sniper":
		return "sniper_nest"
	return String(def.get("model", kind))

func _make_model() -> void:
	model = Art.model(_model_name())
	add_child(model)
	_on_model_ready()
	if host == null and not rect:
		_apply_rest()

func _as_blueprint() -> void:
	state = BLUEPRINT
	Art.set_override(model, Art.mat_blueprint)
	Art.set_shadows(model, false)

func _footprint_center() -> Vector3:
	var a := Defs.cell_center(cell)
	var off := (size - 1) * Defs.CELL * 0.5
	var p := a + Vector3(off, 0, off)
	p.y = G.grid.floor_y(cell)
	return p

func _on_model_ready() -> void:
	pass

func set_rest(y: float) -> void:
	rest_yaw = y
	_apply_rest()

func _apply_rest() -> void:
	pass

func is_built() -> bool:
	return state == BUILT

func blocks_now() -> bool:
	return state == BUILT and bool(def.get("blocks", false)) and host == null and not on_host

func cells() -> Array[Vector2i]:
	if host != null or on_host:
		return []
	if rect:
		return cell_list
	var out: Array[Vector2i] = []
	for y in size:
		for x in size:
			out.append(cell + Vector2i(x, y))
	return out

func display_name() -> String:
	return String(def.get("name", kind))

func long_name() -> String:
	if host != null and kind == "sniper":
		return "Sniper Nest"
	return String(def.get("long", def.get("name", kind)))

func is_gun() -> bool:
	return Defs.GUNS.has(kind)

func slot_count() -> int:
	if model == null:
		return 0
	var n := 0
	for i in 8:
		if _slot_marker(i) != null:
			n += 1
		else:
			break
	return n

func _slot_marker(i: int) -> Node3D:
	if model == null:
		return null
	var m := model.find_child("RoofSlot%d" % (i + 1), true, false) as Node3D
	if m == null and i == 0:
		m = model.find_child("Slot", true, false) as Node3D
	return m

func slot_xform(i: int) -> Transform3D:
	var m := _slot_marker(i)
	if m == null:
		return global_transform.translated(Vector3(0, 2.5, 0))
	return m.global_transform

func slot_bonus() -> float:
	return float(def.get("slot_bonus", 0.25))

func free_slot() -> int:
	for i in mounted.size():
		if mounted[i] == null or not is_instance_valid(mounted[i]) or mounted[i].state == DEAD:
			mounted[i] = null
			return i
	return -1

func wreck_mounted() -> void:
	for i in mounted.size():
		var g = mounted[i]
		mounted[i] = null
		if g != null and is_instance_valid(g) and g.state != DEAD:
			g.destroy(true)

func range_mult() -> float:
	var m := 1.0 + port_bonus
	if host != null and is_instance_valid(host):
		m += host.slot_bonus()
	return m

func gun_range() -> float:
	return Defs.gun_range(kind) * range_mult()

func crew_ok() -> bool:
	if host == null:
		return true
	if not occupants.is_empty():
		return true
	if kind == "sniper":
		return false
	return loader != null and is_instance_valid(loader) and loader.crewing == self

func needs_crew() -> bool:
	return host != null and state == BUILT and occupants.is_empty() and incoming.is_empty() and (loader == null or not is_instance_valid(loader))

func access_goals() -> Dictionary:
	if host != null and is_instance_valid(host):
		return host.access_goals()
	return job_goals()

func crew_spot() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, 0.9)

func _port_check(dt: float) -> void:
	_port_t -= dt
	if _port_t > 0.0:
		return
	_port_t = 1.0
	port_bonus = 0.0
	if host == null and is_gun() and G.walls:
		if G.walls.port_near(position, 3.2):
			port_bonus = Defs.PORT_BONUS

func capacity() -> int:
	if host != null:
		return 1
	return int(def.get("capacity", 0))

func free_slots() -> int:
	return capacity() - occupants.size() - incoming.size()

func reserve_slot(s) -> void:
	incoming.append(s)

func entry_point() -> Vector3:
	if host != null and is_instance_valid(host):
		return host.entry_point()
	var door: Node3D = (model.find_child("Door", true, false) as Node3D) if model else null
	if door:
		return door.global_position
	return global_transform * Vector3(0, 0, 1.3)

func soldier_arrived(s) -> bool:
	incoming.erase(s)
	if state != BUILT or occupants.size() >= capacity():
		return false
	occupants.append(s)
	_on_soldier_enter(s)
	return true

func _on_soldier_enter(_s) -> void:
	pass

func perch_for(s):
	if host != null:
		return crew_spot()
	var pts := port_points()
	if pts.is_empty() or bool(def.get("hide_inside", rect and not kind.begins_with("bastion"))):
		return null
	var k := occupants.find(s)
	return pts[clampi(k, 0, pts.size() - 1)] + Vector3(0, -1.2, 0) - _port_out(clampi(k, 0, pts.size() - 1)) * 0.5

func port_points() -> Array:
	var out := []
	if model == null:
		return out
	for i in 12:
		var m := model.find_child("Port%d" % (i + 1), true, false) as Node3D
		if m == null:
			m = model.find_child("Window%d" % (i + 1), true, false) as Node3D
		if m == null:
			break
		out.append(m.global_position)
	return out

func _port_out(i: int) -> Vector3:
	var m: Node3D = null
	if model:
		m = model.find_child("Port%d" % (i + 1), true, false) as Node3D
		if m == null:
			m = model.find_child("Window%d" % (i + 1), true, false) as Node3D
	if m == null:
		return Vector3.FORWARD
	return -m.global_transform.basis.z

func soldier_cancelled(s) -> void:
	incoming.erase(s)
	occupants.erase(s)

func release_soldiers() -> void:
	var out := entry_point()
	for s in occupants + incoming:
		if is_instance_valid(s):
			s.go_idle(out)
	occupants.clear()
	incoming.clear()

func pop_bonus() -> int:
	return int(def.get("pop", 0))

func soldier_range() -> float:
	return Defs.SOLDIER_RANGE + 3.0

func port_tick(dt: float) -> void:
	var pts := port_points()
	if pts.is_empty():
		return
	for s in occupants:
		if not is_instance_valid(s):
			continue
		s.cd -= dt
		if s.cd > 0.0:
			continue
		var srange: float = soldier_range()
		var z = G.soldiers.pick_target(position, srange) if G.soldiers else G.zombies.nearest(position, srange)
		if z == null:
			s.cd = 0.3
			continue
		s.cd = Defs.SOLDIER_INTERVAL * randf_range(0.85, 1.15)
		var from: Vector3 = pts[0]
		var bd := INF
		for p in pts:
			var dd: float = (p as Vector3).distance_squared_to(z.position)
			if dd < bd:
				bd = dd
				from = p
		var tp: Vector3 = z.aim_point() + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		z.hurt(Defs.SOLDIER_DAMAGE, from)
		if s.visible:
			s.face_point(z.position)
			s._fire_t = 0.22
		if G.fx:
			G.fx.tracer(from, tp, 1)
			G.fx.flash(from, 0.9)
			G.fx.hit(tp, (tp - from).normalized(), 1)
		if G.sfx:
			G.sfx.play("rifle", from)

func card_lines() -> Array:
	var out := []
	if state == BLUEPRINT:
		var q := ""
		if G.workers:
			var pos: int = G.workers.queue_pos(self)
			if pos > 0:
				q = "  ·  queue %d of %d" % [pos, G.workers.pending_count()]
		if host != null and host.state != BUILT:
			q = "  ·  waits for its base"
		out.append(("Moving  %d%%" if move_from != null else "Being built  %d%%") % int(progress * 100.0) + q)
		return out
	var about := String(def.get("about", ""))
	if host != null:
		var crew := "Crewed" if crew_ok() else ("NO CREW. Needs a soldier" if kind == "sniper" else "NO CREW. Needs a soldier or loader")
		out.append("Raised +%d%% range  ·  %s" % [int(round((range_mult() - 1.0) * 100.0)), crew])
	elif capacity() > 0:
		if occupants.is_empty() and incoming.is_empty():
			var idle: int = G.soldiers.idle_count() if G.soldiers else 0
			out.append("Empty. Assign soldiers" if idle > 0 else "Empty. Give people the Soldier job")
		else:
			var s := "Soldiers %d/%d" % [occupants.size(), capacity()]
			if not incoming.is_empty():
				s += "  (+%d coming)" % incoming.size()
			out.append(s)
	elif about != "":
		out.append(about)
	if port_bonus > 0.0:
		out.append("Behind a firing port: +%d%% range, half damage" % int(port_bonus * 100.0))
	var al := ammo_line()
	if al != "":
		out.append(al)
	return out

func card_buttons() -> Array:
	var out := []
	if state == BLUEPRINT:
		out.append(["sell", "CANCEL +%d" % paid, true])
		return out
	if capacity() > 0 and (host == null or kind == "sniper" or occupants.is_empty()):
		var idle: int = G.soldiers.idle_count() if G.soldiers else 0
		var can := free_slots() > 0 and idle > 0
		var label := "ASSIGN"
		if free_slots() <= 0:
			label = "FULL"
		elif idle == 0:
			label = "NO SOLDIERS"
		out.append(["assign", label, can])
	if host == null and kind != "hq":
		if rect and not kind.begins_with("bastion"):
			out.append(["move", "MOVE", moving_to == null])
			out.append(["rotate", "ROTATE", moving_to == null])
		elif is_gun() and size == 1:
			out.append(["move", "MOVE", moving_to == null])
			out.append(["rotate", "TURN", true])
	if slot_count() > 0 and free_slot() >= 0 and state == BUILT:
		out.append(["slot", "ADD GUN", true])
	out.append(["sell", "SELL +%d" % int(round(paid * Defs.REFUND_BUILT)), true])
	return out

func has_health() -> bool:
	return max_hp > 1.0 and (float(def.get("hp", 0.0)) > 0.0 or def.has("hp_per_m"))

func has_ammo() -> bool:
	return mag_size > 0

func loader_boost() -> float:
	return 2.0 if loader != null and is_instance_valid(loader) else 1.0

func use_round() -> bool:
	if mag_size <= 0:
		return true
	if mag <= 0 or reload_t > 0.0:
		return false
	mag -= 1
	if mag == mag_size / 4 and G.sfx and mag_size >= 8:
		G.sfx.play("ammo_low", position)
	if mag <= 0:
		_start_reload()
	return true

func _start_reload() -> void:
	if reserve <= 0:
		_zone_feed()
	if reserve > 0:
		reload_t = float(def.get("reload", 3.0))
		if G.sfx:
			G.sfx.play("reload", position)
	else:
		if G.sfx:
			G.sfx.play("no_ammo", position)
		if G.hud and G.main and not G.main.test_mode:
			if zone > 0:
				G.hud.event("ammo", "%s out of ammo! No crates in the zone: build a Workshop and add Crafters" % display_name(), 12.0)
			else:
				G.hud.event("ammo", "%s out of ammo! Loaders need crates" % display_name(), 12.0)

func out_of_ammo() -> bool:
	return mag_size > 0 and mag <= 0 and reload_t <= 0.0 and reserve <= 0

func needs_restock() -> bool:
	if mag_size <= 0 or state != BUILT or reserve >= reserve_max * 0.6:
		return false
	return zone == 0 or G.logi == null or not G.logi.zone_has_crates(zone)

# Inside a sealed zone the supply line is safe: a gun pulls a crate from a
# store in the same zone by itself when its spare ammo gets low.
func _zone_feed() -> bool:
	if zone <= 0 or state != BUILT or G.logi == null:
		return false
	if not G.logi.take_zone_crate(zone):
		return false
	reserve = reserve_max
	G.logi.zone_fed += 1
	return true

func restock() -> void:
	reserve = reserve_max
	if mag <= 0 and reload_t <= 0.0:
		_start_reload()

func ammo_tick(dt: float) -> void:
	if mag_size <= 0:
		return
	if zone > 0 and reserve < mag_size:
		_feed_t -= dt
		if _feed_t <= 0.0:
			_feed_t = 1.0
			_zone_feed()
	if reload_t > 0.0:
		reload_t -= dt * loader_boost()
		if reload_t <= 0.0:
			reload_t = 0.0
			var take := mini(mag_size, reserve)
			reserve -= take
			mag = take
	elif mag <= 0:
		_start_reload()

func ammo_line() -> String:
	if mag_size <= 0:
		return ""
	if out_of_ammo():
		return "NO AMMO. Needs crates in the zone" if zone > 0 else "NO AMMO. Loaders bring crates between waves"
	var r := "%d spare" % reserve
	if zone > 0:
		r += " (fed from zone crates)"
	if reload_t > 0.0:
		return "Reloading...  ·  %s" % r
	return "Ammo %d/%d  ·  %s" % [mag, mag_size, r]

func needs_repair() -> bool:
	return state == BUILT and has_health() and hp < max_hp * 0.98 and not under_attack() and _can_pay_repair()

# What it would cost to put up again: repairs are charged against this.
func build_value() -> float:
	if def.has("per_m") and "length" in self:
		return float(def["per_m"]) * float(get("length"))
	return float(def.get("cost", def.get("claim", 0)))

func _repair_unit() -> float:
	return build_value() * Defs.REPAIR_COST / max_hp

func _can_pay_repair() -> bool:
	return G.main == null or _repair_unit() <= 0.0 or G.main.supplies >= 1

func repair(dt: float) -> bool:
	var add := minf(max_hp - hp, dt * maxf(40.0, max_hp * 0.04))
	var unit := _repair_unit()
	if unit > 0.0 and G.main:
		_repair_debt += add * unit
		if _repair_debt >= 1.0:
			var n := int(_repair_debt)
			if not G.main.spend(n):
				return true
			_repair_debt -= n
			G.main.repair_spent += n
	hp = minf(max_hp, hp + add)
	damage_look()
	return hp >= max_hp

func under_attack() -> bool:
	return G.sim_time - hit_at < 3.0


func is_wallish() -> bool:
	return rect

func job_goals() -> Dictionary:
	if host != null and is_instance_valid(host):
		return host.access_goals()
	var cells: PackedInt32Array = G.grid.building_nav_cells(self)
	if job_adjacent():
		return G.grid.ring_goals(cells)
	var d := {}
	for i in cells:
		d[i] = true
	return d

func edge_distance(p: Vector3) -> float:
	if host != null:
		return Vector2(p.x - position.x, p.z - position.z).length()
	if rect:
		var l := (p - position).rotated(Vector3.UP, -yaw)
		var ex := maxf(absf(l.x) - half.x, 0.0)
		var ez := maxf(absf(l.z) - half.y, 0.0)
		return sqrt(ex * ex + ez * ez)
	var c := position
	var h := size * Defs.CELL * 0.5
	var dx := maxf(absf(p.x - c.x) - h, 0.0)
	var dz := maxf(absf(p.z - c.z) - h, 0.0)
	return sqrt(dx * dx + dz * dz)

func job_adjacent() -> bool:
	return bool(def.get("blocks", false))

func job_cell() -> Vector2i:
	return cell

func job_valid() -> bool:
	return state == BLUEPRINT and is_inside_tree() and not host_lost()

func host_lost() -> bool:
	return on_host and (not is_instance_valid(host) or host.state == DEAD)

func job_ready() -> bool:
	if host != null and is_instance_valid(host):
		return host.state == BUILT
	return true

func job_world_pos() -> Vector3:
	return position

func work(dt: float) -> bool:
	if state != BLUEPRINT:
		return true
	if not job_ready():
		return false
	var t := float(def.get("time", 2.0))
	if move_from != null:
		t *= 0.5
	progress += dt / maxf(0.1, t)
	if progress >= 1.0:
		_finish(false)
		return true
	build_look()
	return false

func build_look() -> void:
	if state != BLUEPRINT or progress <= 0.0 or model == null:
		return
	if _rise == null:
		_rise = _rise_model()
		if _rise == null:
			return
		Art.set_override(_rise, null)
		Art.set_shadows(_rise, false)
		add_child(_rise)
		Art.set_override(model, Art.mat_blueprint_faint)
		_scaffold = _make_scaffold()
		if _scaffold:
			add_child(_scaffold)
	var f := clampf(progress, 0.0, 1.0)
	_rise.transform = Transform3D(Basis.from_scale(Vector3(1.0, lerpf(0.05, 1.0, f), 1.0)), Vector3.ZERO) * model.transform

func _rise_model() -> Node3D:
	if host != null:
		return null
	return Art.model(_model_name())

func _make_scaffold() -> MeshInstance3D:
	var w := size * Defs.CELL * 0.8
	var d := w
	if rect:
		w = half.x * 2.0
		d = half.y * 2.0
	var h := clampf(Art.model_height(model), 1.2, 7.0)
	var mi := MeshInstance3D.new()
	mi.mesh = Art.scaffold_mesh(w, d, h)
	mi.material_override = Art.mat_vc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _clear_build_look() -> void:
	if _rise:
		_rise.queue_free()
		_rise = null
	if _scaffold:
		_scaffold.queue_free()
		_scaffold = null

func damage_look() -> void:
	if state != BUILT or not has_health() or model == null:
		return
	var f := hp / maxf(1.0, max_hp)
	var st := 0
	if f < 0.22:
		st = 3
	elif f < 0.45:
		st = 2
	elif f < 0.7:
		st = 1
	if st == _dmg_stage:
		return
	_dmg_stage = st
	Art.set_overlay(model, Art.damage_mat(st) if st > 0 else null)
	_on_damage_stage(st)
	if G.fx:
		if st >= 2:
			var top := Art.model_height(model) * 0.8
			G.fx.smoke_attach(self, global_position + Vector3(0, maxf(1.0, top), 0), 0.6 + 0.3 * st)
		else:
			G.fx.smoke_detach(self)

func _on_damage_stage(_st: int) -> void:
	pass

func _finish(instant: bool) -> void:
	if move_from != null and is_instance_valid(move_from):
		_take_over(move_from)
	move_from = null
	state = BUILT
	progress = 1.0
	_clear_build_look()
	Art.set_override(model, null)
	Art.set_shadows(model, true)
	_restore_overrides()
	if blocks_now():
		if rect:
			for c in cell_list:
				G.grid.occ[G.grid.idx(c)] = self
		G.grid.mark_nav(G.grid.building_nav_cells(self), Grid.N_BUILD, self)
	G.grid.notify_paths_changed()
	if not instant:
		_pop = 1.0
		if G.fx:
			G.fx.dust(position + Vector3(0, 0.3, 0), 0.8 * maxf(size, half.x))
		if G.sfx:
			G.sfx.play("build", position)
	_on_built()
	if edit_group != null:
		edit_group.check()

func _take_over(old) -> void:
	hp = max_hp * clampf(old.hp / maxf(1.0, old.max_hp), 0.05, 1.0)
	mag = old.mag
	reserve = old.reserve
	var crew: Array = old.occupants.duplicate()
	for i in mini(old.mounted.size(), mounted.size()):
		var g = old.mounted[i]
		if g != null and is_instance_valid(g) and g.state != DEAD:
			g.host = self
			mounted[i] = g
			old.mounted[i] = null
	old.moving_to = null
	old.release_soldiers()
	old.mounted.clear()
	old.destroy(false)
	for i in mounted.size():
		var g2 = mounted[i]
		if g2 != null and is_instance_valid(g2):
			g2.position = slot_xform(i).origin
	if G.soldiers:
		for s in crew:
			if is_instance_valid(s) and not s.dead and free_slots() > 0:
				s.assign(self)

func _restore_overrides() -> void:
	pass

func _on_built() -> void:
	pass

func take_damage(amount: float, _from = null) -> void:
	if state != BUILT or not has_health():
		return
	if port_bonus > 0.0:
		amount *= Defs.PORT_GUARD
	hp -= amount
	hit_at = G.sim_time
	if hp <= 0.0:
		hp = 0.0
		destroy(true)
		return
	damage_look()

func destroy(effects: bool) -> void:
	if state == DEAD:
		return
	state = DEAD
	release_soldiers()
	if loader != null and is_instance_valid(loader) and loader.has_method("release"):
		loader.release()
	if host != null and is_instance_valid(host) and slot_i >= 0 and slot_i < host.mounted.size() and host.mounted[slot_i] == self:
		host.mounted[slot_i] = null
	wreck_mounted()
	if moving_to != null and is_instance_valid(moving_to) and moving_to.state == BLUEPRINT:
		G.buildings.remove_thing(moving_to)
	if host == null and not on_host:
		G.grid.clear_nav(G.grid.building_nav_cells(self), self)
	if G.buildings:
		G.buildings.on_removed(self)
	if G.fx:
		G.fx.smoke_detach(self)
	if effects and G.fx:
		G.fx.debris(position + Vector3(0, 0.6, 0), maxi(size, int(half.x)))
		G.fx.dust(position + Vector3(0, 0.5, 0), 1.4 * maxf(size, half.x))
		G.fx.dust(position + Vector3(0, 1.5, 0), 1.8 * maxf(size, half.x))
		G.fx.smoke(position + Vector3(0, 1.0, 0), 4.0, maxf(1.0, half.x * 0.7))
		G.fx.scorch(position, 2.0 * maxf(size, half.x))
		if G.cam:
			G.cam.shake(0.25)
		if G.sfx:
			G.sfx.play("break", position)
	_on_destroyed(effects)
	if edit_group != null:
		edit_group.check()
	G.grid.notify_paths_changed()
	queue_free()

func _on_destroyed(_effects: bool) -> void:
	pass

func tick(dt: float) -> void:
	if on_host and state != DEAD and host_lost():
		destroy(false)
		return
	if state == BUILT and mag_size > 0:
		ammo_tick(dt)
	if state == BUILT:
		_port_check(dt)
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - dt * 3.0)
		var s := 1.0 + sin(_pop * PI) * 0.12
		model.scale = Vector3(s, 1.0 + sin(_pop * PI) * 0.08, s)
