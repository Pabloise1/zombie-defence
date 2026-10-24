class_name Fetcher
extends Person
enum {IDLE, GO, SEARCH, CARRY, FLEE, RESCUE, LEAD}
var mode := IDLE
var spot = null
var carrying := 0
var home := Vector3.ZERO
var _t := 0.0
var _bundle: Node3D
var _think := 0.0
var group = null

func setup(at: Vector3) -> void:
	kind = "fetcher"
	speed = 3.9
	position = at
	setup_model("fetcher", ["idle", "walk", "run", "carry"])
	_bundle = Art.model("scrap_bundle")
	_bundle.visible = false
	var back := model.find_child("Back", true, false) as Node3D
	if back:
		back.add_child(_bundle)
	else:
		_bundle.position = Vector3(0, 1.2, 0.32)
		add_child(_bundle)
	_go_home()

func _go_home() -> void:
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func _leave_spot() -> void:
	if spot != null and is_instance_valid(spot):
		spot.fetchers = maxi(0, spot.fetchers - 1)
	spot = null

func _drop_group() -> void:
	if group != null and group.rescuer == self:
		group.rescuer = null
	group = null

func _on_death() -> void:
	_leave_spot()
	_drop_group()

func is_out() -> bool:
	return mode == GO or mode == SEARCH or mode == CARRY or mode == RESCUE or mode == LEAD or (mode == FLEE and not G.people.is_safe(position))

func step(dt: float) -> void:
	if dead:
		step_dead(dt)
		return
	_moving = false
	var building: bool = G.main != null and G.main.phase == "build"
	var active: bool = building or (G.main != null and G.main.phase == "wave")
	if not building and (mode == GO or mode == SEARCH or mode == CARRY):
		_leave_spot()
		mode = FLEE
		_go_home()
	if mode == GO or mode == SEARCH or mode == CARRY:
		if scan_threat(dt, 12.0):
			_leave_spot()
			mode = FLEE
			if G.people:
				home = G.people.home_spot(self)
			if not walk_to_avoiding(G.grid.point_goals(home, 1)):
				_go_home()
	elif mode == RESCUE or mode == LEAD:
		# Braver than on a scrap run: only a zombie right on top turns them back.
		if scan_threat(dt, 5.0):
			_drop_group()
			mode = FLEE
			if not walk_to_avoiding(G.people.refuge_goals(position)):
				_go_home()
	elif alert_t > 0.0:
		scan_threat(dt, 12.0)
	match mode:
		IDLE:
			if not arrived():
				follow(dt)
			_think -= dt
			if active and _think <= 0.0:
				_think = 1.0
				var g = G.people.group_to_rescue(position)
				if g != null and walk_to_avoiding(G.grid.point_goals(g.pos, 2)):
					group = g
					g.rescuer = self
					mode = RESCUE
					if G.hud:
						G.hud.toast("A fetcher is running out for the survivors")
			if building and _think <= 0.0:
				var s = G.logi.pick_salvage(position) if G.logi else null
				if s != null:
					var goals: Dictionary = s.goals()
					if walk_to_avoiding(goals):
						spot = s
						s.fetchers += 1
						mode = GO
		GO:
			if spot == null or not is_instance_valid(spot) or spot.scrap <= 0:
				_leave_spot()
				mode = IDLE
				_go_home()
			elif not arrived():
				follow(dt)
			else:
				mode = SEARCH
				_t = 2.5
				face_point(spot.position)
		SEARCH:
			_t -= dt
			if _t <= 0.0:
				carrying = spot.take(Defs.FETCH_LOAD) if spot != null and is_instance_valid(spot) else 0
				if randf() < Defs.FETCH_FIND and G.people.room() > 0 and spot != null:
					var n := mini(randi_range(1, 2), G.people.room())
					G.people.spawn_group(position + Vector3(1.5, 0, 0), n)
					if G.hud:
						G.hud.toast("A fetcher found %d survivor%s" % [n, "" if n == 1 else "s"])
				_leave_spot()
				mode = CARRY
				_bundle.visible = carrying > 0
				_go_home()
		CARRY:
			if not arrived():
				follow(dt, 3.2)
			else:
				if carrying > 0:
					G.main.add_supplies(carrying)
					G.logi.fetched += carrying
					if G.sfx:
						G.sfx.play("impact_metal", position)
				carrying = 0
				_bundle.visible = false
				mode = IDLE
				_think = 0.5
		RESCUE:
			if group == null or group.members.is_empty() or group.heli != null:
				_drop_group()
				mode = IDLE
				_go_home()
			elif position.distance_to(group.pos) < 3.5 or arrived():
				var n: int = G.people.release_group(group)
				group = null
				mode = LEAD
				if not walk_to_avoiding(G.people.refuge_goals(position, true)):
					walk_to_goals(G.people.refuge_goals(position, true))
				if G.hud and n > 0:
					G.hud.toast("Fetcher reached %d survivor%s. Cover them on the way in!" % [n, "" if n == 1 else "s"])
			else:
				follow(dt, 4.6)
		LEAD:
			if G.people.is_safe(position) or arrived():
				mode = IDLE
				_think = 2.0
				_go_home()
			else:
				follow(dt, 4.2)
		FLEE:
			_bundle.visible = false
			carrying = 0
			if not arrived():
				follow(dt, 5.2)
			else:
				mode = IDLE
	if mode == SEARCH:
		anim_mode = "work"
	elif mode == CARRY:
		anim_mode = "carry"
	elif mode == FLEE or mode == RESCUE or mode == LEAD:
		anim_mode = "run"
	else:
		anim_mode = "idle"
	settle(dt)
	animate(dt)
