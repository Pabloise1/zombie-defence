class_name Heli
extends Node3D
enum {PARKED, SPINUP, LIFT, CRUISE, DESCEND, LANDED, ORBIT, WINCH, DROP, SPINDOWN, DEAD}
const KINDS := {
	"huey": {"model": "helicopter", "name": "Huey", "seats": 6, "crates": 4, "speed": 17.0, "hp": 1800.0, "cool": 25.0,
		"door": 1.45, "doors": ["DoorL", "DoorR"], "gun_dmg": 7.0, "gun_rate": 7.0},
	"mi8": {"model": "mi8", "name": "Mi-8", "seats": 12, "crates": 8, "speed": 14.0, "hp": 3200.0, "cool": 35.0,
		"door": 1.15, "doors": ["DoorL"], "gun_dmg": 9.0, "gun_rate": 7.0},
}
const CRUISE_ALT := 18.0
const PATROL_ALT := 13.0
const PATROL_TIME := 40.0
const MISSION_COST := {"rescue": 30, "patrol": 50, "resupply": 20}
var kind := "huey"
var info: Dictionary = {}
var pad = null
var fly := PARKED
var mission := ""
var hp := 1.0
var max_hp := 1.0
var cooldown := 0.0
var passengers := 0
var crates := 0
var hit_at := -100.0
var model: Node3D
var _rotor: Node3D
var _blades: GeometryInstance3D
var _disc: GeometryInstance3D
var _tail: Node3D
var _doors: Array = []
var _gun_yaw: Node3D
var _gun_pitch: Node3D
var _muzzle: Node3D
var _light_yaw: Node3D
var _light_pitch: Node3D
var _spot: SpotLight3D
var _cable: MeshInstance3D
var rotor := 0.0
var vel := Vector3.ZERO
var yaw := 0.0
var _roll := 0.0
var _pitch := 0.0
var _door_open := 1.0
var _door_want := 1.0
var _dust_t := 0.0
var _gun_cd := 0.0
var _gun_target = null
var _scan_t := 0.0
var dest := Vector3.ZERO
var alt := 0.0
var orbit_t := 0.0
var orbit_c := Vector3.ZERO
var group = null
var drops: Array = []
var _winch_t := 0.0
var _load_t := 0.0
var _arrived_t := 0.0
var _on_mission := false

func setup(k: String, p) -> void:
	kind = k
	info = KINDS[k]
	pad = p
	max_hp = float(info["hp"])
	hp = max_hp
	model = Art.model(String(info["model"]))
	add_child(model)
	_rotor = model.find_child("MainRotor", true, false) as Node3D
	_blades = model.find_child("MainBlades", true, false) as GeometryInstance3D
	_disc = model.find_child("RotorDisc", true, false) as GeometryInstance3D
	_tail = model.find_child("TailRotor", true, false) as Node3D
	for dn in info["doors"]:
		var d := model.find_child(dn, true, false) as Node3D
		if d:
			_doors.append([d, d.position.z])
	_gun_yaw = model.find_child("DoorGunYaw", true, false) as Node3D
	_gun_pitch = model.find_child("DoorGunPitch", true, false) as Node3D
	_muzzle = model.find_child("Muzzle", true, false) as Node3D
	_light_yaw = model.find_child("SearchlightYaw", true, false) as Node3D
	_light_pitch = model.find_child("SearchlightPitch", true, false) as Node3D
	var lamp := model.find_child("Lamp", true, false) as Node3D
	if lamp:
		_spot = SpotLight3D.new()
		_spot.spot_range = 50.0
		_spot.spot_angle = 16.0
		_spot.light_energy = 0.0
		_spot.light_color = Color(1.0, 0.95, 0.85)
		_spot.shadow_enabled = false
		_spot.visible = false
		lamp.add_child(_spot)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		anim.stop()
	if _disc:
		_disc.transparency = 1.0
		_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	park_now()

func display_name() -> String:
	return String(info.get("name", "Heli"))

func park_now() -> void:
	var lt: Transform3D = pad.land_xform()
	position = lt.origin
	yaw = lt.basis.get_euler().y
	rotation = Vector3(0, yaw, 0)
	vel = Vector3.ZERO
	fly = PARKED
	_door_want = 0.0
	_door_open = 0.0
	_apply_doors()

func landed() -> bool:
	return fly == PARKED or fly == LANDED or fly == SPINUP or fly == SPINDOWN
var state: int:
	get:
		return Building.BUILT if landed() and fly != DEAD else Building.DEAD

func edge_distance(p: Vector3) -> float:
	var r := 3.4 if kind == "huey" else 6.2
	return maxf(0.0, Vector2(p.x - position.x, p.z - position.z).length() - r)

func exposed() -> bool:
	return landed() and fly != DEAD

func take_damage(amount: float, _from = null) -> void:
	if not landed() or fly == DEAD:
		return
	hp -= amount
	hit_at = G.sim_time
	if G.fx and randf() < 0.4:
		G.fx.chips(position + Vector3(0, 1.4, 0))
	if hp <= 0.0:
		_crash()

func _crash() -> void:
	fly = DEAD
	if G.fx:
		G.fx.explosion(position + Vector3(0, 1.0, 0), 2.2)
		G.fx.fire_patch(position, 3.0, 12.0)
	if G.sfx:
		G.sfx.stop_loop(self)
		G.sfx.play("boom", position)
	if G.hud:
		G.hud.toast("The %s is down!" % display_name())
	passengers = 0
	if G.helis:
		G.helis.on_lost(self)
	if pad != null and is_instance_valid(pad):
		pad.heli = null
	queue_free()

func ready_why() -> String:
	if fly != PARKED:
		return "The %s is out" % display_name()
	if cooldown > 0.0:
		return "Ready in %d s" % int(ceil(cooldown))
	return ""

func start_rescue(g) -> String:
	var why := ready_why()
	if why != "":
		return why
	if g == null or g.members.is_empty():
		return "Tap a group of survivors (SOS)"
	if not G.main.spend(MISSION_COST["rescue"]):
		return "A rescue costs %d" % MISSION_COST["rescue"]
	mission = "rescue"
	group = g
	g.heli = self
	_take_off(g.pos)
	return ""

func start_patrol(p: Vector3) -> String:
	var why := ready_why()
	if why != "":
		return why
	if not G.main.spend(MISSION_COST["patrol"]):
		return "A patrol costs %d" % MISSION_COST["patrol"]
	mission = "patrol"
	orbit_c = Vector3(p.x, 0, p.z)
	_take_off(orbit_c)
	return ""

func start_resupply() -> String:
	var why := ready_why()
	if why != "":
		return why
	var guns := []
	for gun in G.buildings.guns():
		if gun.zone == 0 and gun.needs_restock() and gun.host == null:
			guns.append(gun)
	if guns.is_empty():
		return "No guns outside the walls need ammo"
	var have: int = G.logi.crates_total() if G.logi else 0
	if have <= 0:
		return "No ammo crates in store"
	if not G.main.spend(MISSION_COST["resupply"]):
		return "A resupply costs %d" % MISSION_COST["resupply"]
	crates = mini(int(info["crates"]), have)
	G.logi.take_crates(crates)
	guns.sort_custom(func(a, b): return a.position.distance_to(position) < b.position.distance_to(position))
	drops = guns.slice(0, crates)
	mission = "resupply"
	_take_off(drops[0].position)
	return ""

func _take_off(to: Vector3) -> void:
	_on_mission = true
	dest = Vector3(to.x, 0, to.z)
	fly = SPINUP
	_door_want = 0.0
	if G.sfx:
		G.sfx.loop("rotor_loop", self)

func _go_home() -> void:
	mission = "home" if mission != "" else mission
	var lt: Transform3D = pad.land_xform()
	dest = lt.origin
	alt = CRUISE_ALT
	fly = CRUISE

func step(dt: float) -> void:
	if fly == DEAD:
		return
	if pad == null or not is_instance_valid(pad) or pad.state == Building.DEAD:
		_crash()
		return
	match fly:
		PARKED:
			rotor = move_toward(rotor, 0.0, dt * 0.4)
			cooldown = maxf(0.0, cooldown - dt)
			if hp < max_hp and G.sim_time - hit_at > 4.0:
				hp = minf(max_hp, hp + 30.0 * dt)
		SPINUP:
			rotor = move_toward(rotor, 1.0, dt / 2.5)
			if rotor >= 1.0:
				fly = LIFT
				alt = 10.0
		LIFT:
			_climb(dt, 10.0)
			if _height() > 8.5:
				fly = CRUISE
				alt = CRUISE_ALT if mission != "patrol" else PATROL_ALT
		CRUISE:
			_fly_to(dt, dest, alt)
			if _flat_dist(dest) < (16.0 if mission == "patrol" else 1.2) and vel.length() < (8.0 if mission == "patrol" else 1.5):
				_arrive()
			elif mission == "patrol" and _flat_dist(dest) < 18.0:
				_arrive()
		DESCEND:
			_fly_to(dt, dest, 0.0, 3.0)
			if _height() < 0.05:
				_touch_down()
		LANDED:
			_landed_step(dt)
		ORBIT:
			_orbit(dt)
		WINCH:
			_winch(dt)
		DROP:
			_drop(dt)
		SPINDOWN:
			rotor = move_toward(rotor, 0.0, dt / 3.0)
			if rotor <= 0.02:
				fly = PARKED
				if _on_mission:
					cooldown = float(info["cool"])
				_on_mission = false
				if G.sfx:
					G.sfx.stop_loop(self, "", 0.6)
	_visuals(dt)

func _ground(p: Vector3) -> float:
	if pad != null and is_instance_valid(pad) and dest.distance_to(pad.land_xform().origin) < 0.5 and Vector2(p.x - dest.x, p.z - dest.z).length() < 8.0:
		return pad.land_xform().origin.y
	return 0.0

func _height() -> float:
	return position.y - _ground(position)

func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()

func _climb(dt: float, to_alt: float) -> void:
	var gy := _ground(position)
	position.y = move_toward(position.y, gy + to_alt, dt * 3.5)
	vel = vel.move_toward(Vector3.ZERO, dt * 4.0)
	_dust(dt)

func _fly_to(dt: float, p: Vector3, height: float, vmax: float = -1.0) -> void:
	var spd: float = float(info["speed"]) if vmax < 0.0 else vmax
	var to := Vector3(p.x - position.x, 0, p.z - position.z)
	var d := to.length()
	var want := Vector3.ZERO
	if d > 0.05:
		want = to / d * minf(spd, d * 0.6 + 0.3)
	var acc := (want - vel)
	var amax := 7.0 * dt
	if acc.length() > amax:
		acc = acc.normalized() * amax
	vel += acc
	position += vel * dt
	var gy := _ground(p) if d < 10.0 else 0.0
	var target_y := gy + height
	var vy := 5.0 if height < 1.0 else 4.0
	if height < 1.0 and d > 2.0:
		target_y = maxf(target_y, gy + 4.0)
	position.y = move_toward(position.y, target_y, dt * vy)
	var old := yaw
	if vel.length() > 2.0:
		yaw = lerp_angle(yaw, atan2(-vel.x, -vel.z), minf(1.0, dt * 1.4))
	var turn := wrapf(yaw - old, -PI, PI) / maxf(dt, 0.001)
	_roll = lerpf(_roll, clampf(-turn * 0.35, -0.4, 0.4), minf(1.0, dt * 3.0))
	var fwd_spd := vel.dot(Vector3(-sin(yaw), 0, -cos(yaw)))
	_pitch = lerpf(_pitch, clampf(-fwd_spd / spd * 0.16 - acc.dot(Vector3(-sin(yaw), 0, -cos(yaw))) / maxf(dt, 0.001) * 0.01, -0.22, 0.12), minf(1.0, dt * 2.5))
	if _height() < 8.0:
		_dust(dt)

func _arrive() -> void:
	match mission:
		"rescue":
			if group == null or not is_instance_valid(group.marker) or group.members.is_empty():
				_go_home()
				return
			var spot: Vector3 = G.helis.landing_spot(group.pos)
			if spot != Vector3.INF:
				dest = spot
				fly = DESCEND
				_door_want = 0.0
			else:
				dest = group.pos
				fly = WINCH
				_winch_t = 0.0
				_door_want = 1.0
		"patrol":
			fly = ORBIT
			orbit_t = PATROL_TIME
			_door_want = 1.0
		"resupply":
			fly = DROP
			_arrived_t = 0.0
		_:
			dest = pad.land_xform().origin
			fly = DESCEND

func _touch_down() -> void:
	vel = Vector3.ZERO
	_pitch = 0.0
	_roll = 0.0
	fly = LANDED
	_door_want = 1.0
	_load_t = 0.0
	if G.fx:
		G.fx.dust(position + Vector3(0, 0.3, 0), 2.4)
	if mission == "home" or mission == "":
		_unload()

func _landed_step(dt: float) -> void:
	_load_t += dt
	rotor = move_toward(rotor, 0.6, dt * 0.5)
	if mission == "rescue":
		if group != null and _load_t > 0.6:
			group.call_to(position + Vector3(-sin(yaw + PI * 0.5), 0, -cos(yaw + PI * 0.5)) * 2.4)
			for c in group.members.duplicate():
				if not is_instance_valid(c) or c.dead:
					group.members.erase(c)
					continue
				if c.position.distance_to(position) < 3.2 and passengers < int(info["seats"]):
					_board(c)
		var done: bool = group == null or group.members.is_empty() or passengers >= int(info["seats"])
		if (done and _load_t > 1.5) or _load_t > 25.0:
			_leave_rescue()
	elif mission == "home" or mission == "":
		if _load_t > 1.2:
			mission = ""
			fly = SPINDOWN
			_door_want = 0.0
			park_now_soft()

func park_now_soft() -> void:
	var lt: Transform3D = pad.land_xform()
	position = lt.origin
	vel = Vector3.ZERO

func _board(c) -> void:
	passengers += 1
	group.members.erase(c)
	G.people.civilians.erase(c)
	c.queue_free()
	if G.sfx:
		G.sfx.play_ui("ui_assign")

func _leave_rescue() -> void:
	if group != null:
		group.heli = null
		if group.members.is_empty():
			G.people.remove_group(group)
	group = null
	_door_want = 0.0
	fly = LIFT
	mission = "home"

func _unload() -> void:
	if passengers <= 0:
		return
	var n := passengers
	var side := Vector3(-sin(yaw + PI * 0.5), 0, -cos(yaw + PI * 0.5))
	for i in passengers:
		var c = G.people.spawn_civilian(position + side * (2.5 + (i % 3) * 0.6) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), true)
		G.people.on_joined(c)
	passengers = 0
	if G.hud:
		G.hud.toast("The %s brought %d survivor%s home" % [display_name(), n, "" if n == 1 else "s"])

func _winch(dt: float) -> void:
	_fly_to(dt, dest, 9.0, 4.0)
	_winch_t += dt
	if group == null or group.members.is_empty() or passengers >= int(info["seats"]):
		_cable_show(false)
		_leave_rescue()
		fly = CRUISE
		_go_home()
		return
	var c = group.members[0]
	if not is_instance_valid(c) or c.dead:
		group.members.erase(c)
		return
	group.call_to(Vector3(position.x, 0, position.z))
	var wp := _winch_point()
	if Vector2(c.position.x - position.x, c.position.z - position.z).length() < 2.5:
		c.position = c.position.move_toward(wp - Vector3(0, 1.6, 0), dt * 3.0)
		c.state = Building.DEAD
		_cable_show(true, wp, c.position + Vector3(0, 1.7, 0))
		if c.position.distance_to(wp - Vector3(0, 1.6, 0)) < 0.2:
			_board(c)
	else:
		_cable_show(true, wp, Vector3(wp.x, 1.0, wp.z))

func _winch_point() -> Vector3:
	var w := model.find_child("Winch", true, false) as Node3D
	return w.global_position if w else position + Vector3(0, 2.0, 0)

func _cable_show(on: bool, a: Vector3 = Vector3.ZERO, b: Vector3 = Vector3.ZERO) -> void:
	if not on:
		if _cable:
			_cable.visible = false
		return
	if _cable == null:
		_cable = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		_cable.mesh = cm
		_cable.material_override = Art.mat_vc_metal
		G.helis.add_child(_cable)
	_cable.visible = true
	var mid := (a + b) * 0.5
	var l := maxf(0.05, a.distance_to(b))
	_cable.global_transform = Transform3D(Basis(Vector3.RIGHT, 0.0).scaled(Vector3(1, l, 1)), mid)

func _orbit(dt: float) -> void:
	orbit_t -= dt
	var ang := atan2(position.z - orbit_c.z, position.x - orbit_c.x) + dt * 0.55
	var r := 14.0
	var p := orbit_c + Vector3(cos(ang), 0, sin(ang)) * r
	_fly_to(dt, p, PATROL_ALT, 9.0)
	_shoot(dt, orbit_c, 30.0)
	if orbit_t <= 0.0:
		_door_want = 0.0
		_go_home()

func _drop(dt: float) -> void:
	if drops.is_empty():
		_go_home()
		return
	var gun = drops[0]
	if not is_instance_valid(gun) or gun.state != Building.BUILT:
		drops.pop_front()
		if not drops.is_empty():
			dest = drops[0].position
			fly = CRUISE
		return
	_fly_to(dt, gun.position, 8.0, 4.0)
	_arrived_t += dt
	_shoot(dt, gun.position, 24.0)
	if _flat_dist(gun.position) < 1.5 and _height() < 9.0 and _arrived_t > 1.0:
		gun.restock()
		crates -= 1
		if G.fx:
			G.fx.dust(gun.position + Vector3(0, 0.3, 0), 0.8)
		if G.sfx:
			G.sfx.play("impact_metal", gun.position)
		drops.pop_front()
		_arrived_t = 0.0
		if not drops.is_empty() and crates > 0:
			dest = drops[0].position
			fly = CRUISE
		else:
			if crates > 0 and G.logi:
				G.logi.add_crates(crates, pad.position)
			crates = 0
			_go_home()

func _shoot(dt: float, p: Vector3, r: float) -> void:
	_gun_cd -= dt
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.3
		_gun_target = G.zombies.nearest_r(Vector3(position.x, 0, position.z), r) if G.zombies else null
	var z = _gun_target
	if z == null or not is_instance_valid(z) or not z.alive:
		return
	var aim: Vector3 = z.aim_point()
	_aim_at(_gun_yaw, _gun_pitch, aim)
	_aim_at(_light_yaw, _light_pitch, aim)
	if _gun_cd <= 0.0 and _muzzle:
		_gun_cd = 1.0 / float(info["gun_rate"])
		var from := _muzzle.global_position
		z.hurt(float(info["gun_dmg"]), from)
		if G.fx:
			G.fx.tracer(from, aim + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), 0)
			G.fx.flash(from, 0.9)
			G.fx.hit(aim, (aim - from).normalized(), 0)
		if G.sfx:
			G.sfx.play("shot", from)

func _aim_at(yn: Node3D, pn: Node3D, p: Vector3) -> void:
	if yn == null or pn == null:
		return
	var parent := yn.get_parent() as Node3D
	var lp := parent.global_transform.affine_inverse() * p
	var d := lp - yn.position
	yn.rotation.y = lerp_angle(yn.rotation.y, atan2(-d.x, -d.z), 0.3)
	var flat := Vector2(d.x, d.z).length()
	pn.rotation.x = lerp_angle(pn.rotation.x, clampf(atan2(d.y, flat), -1.2, 0.3), 0.3)

func _dust(dt: float) -> void:
	_dust_t -= dt
	if _dust_t > 0.0 or G.fx == null or rotor < 0.5:
		return
	_dust_t = 0.22
	var gy := _ground(position)
	var h := position.y - gy
	if h > 9.0:
		return
	var r := 3.5 + h * 0.4
	for k in 3:
		var a := randf() * TAU
		G.fx.dust(Vector3(position.x + cos(a) * r, gy + 0.2, position.z + sin(a) * r), 0.9 + (9.0 - h) * 0.06)

func _apply_doors() -> void:
	var travel: float = float(info["door"])
	for d in _doors:
		var node: Node3D = d[0]
		node.position.z = float(d[1]) - travel * (1.0 - _door_open)

func _visuals(dt: float) -> void:
	rotation = Vector3(_pitch, yaw, _roll)
	if _rotor:
		_rotor.rotation.y -= dt * TAU * (0.15 + 4.2 * rotor) * (1.0 if rotor > 0.01 else 0.0)
	if _tail:
		_tail.rotation.x += dt * TAU * 18.0 * rotor
	var spin := smoothstep(0.45, 0.85, rotor)
	if _blades:
		_blades.transparency = spin * 0.85
		_blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if spin > 0.3 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _disc:
		_disc.transparency = 1.0 - spin * 0.85
	_door_open = move_toward(_door_open, _door_want, dt / 1.2)
	_apply_doors()
	var flying := fly != PARKED and fly != SPINDOWN
	if _spot:
		var on := flying and (mission == "patrol" or mission == "rescue")
		_spot.visible = on
		_spot.light_energy = move_toward(_spot.light_energy, 5.0 if on else 0.0, dt * 8.0)
		if on and _gun_target == null and _light_yaw:
			_light_yaw.rotation.y = sin(G.sim_time * 0.7) * 0.9
			_light_pitch.rotation.x = -0.6 + sin(G.sim_time * 0.43) * 0.25

func status_line() -> String:
	match fly:
		PARKED:
			if cooldown > 0.0:
				return "%s on the pad  ·  ready in %d s" % [display_name(), int(ceil(cooldown))]
			return "%s ready  ·  %d seats, %d crates" % [display_name(), int(info["seats"]), int(info["crates"])]
		ORBIT:
			return "On patrol: %d s left" % int(ceil(orbit_t))
		WINCH:
			return "Winching survivors up (%d aboard)" % passengers
		LANDED:
			return "Down: loading (%d aboard)" % passengers if mission == "rescue" else "Landing"
		DROP:
			return "Dropping crates (%d left)" % crates
	if mission == "home":
		return "Flying home" + ("  (%d aboard)" % passengers if passengers > 0 else "")
	return "In the air: %s" % mission
