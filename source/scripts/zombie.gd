class_name Zombie
extends Node3D
enum {WALK, ATTACK, FALL, CLIMB, DEAD, VAULT}
const VAULT_TIME := 1.1
const REACH := 0.55
const ATTACK_INTERVAL := 1.15
const SINK_TIME := 1.2
const CLIP_SPEED := {"zombie_a": 0.79, "zombie_b": 0.87, "zombie_brute": 1.27}
var id := 0
var listed := false
var variant := ""
var alive := false
var active := false
var kind := Defs.Z_WALKER
var hp := 1.0
var max_hp := 1.0
var speed := 1.2
var dmg := 10.0
var reward := 5
var st := WALK
var ci := 0
var y := 0.0
var vy := 0.0
var lane := Vector2.ZERO
var heading := 0.0
var flash_t := 0.0
var attack_t := 0.0
var target = null
var climb_t := 0.0
var climb_total := 2.0
var climb_from := 0.0
var climb_dir := Vector3.ZERO
var dead_t := 0.0
var stagger_t := 0.0
var sep := Vector2.ZERO
var anim_acc := 0.0
var scan_t := 0.0
var burn_t := 0.0
var burn_fx := -1
var bob := 0.0
var groan_t := 0.0
var tier := 0
var bucket := -1
var gait := 0
var gait_ph := 0.0
var spread := 0.0
var flinch_t := 0.0
var kb := Vector3.ZERO
var flying := false
var fly_v := Vector3.ZERO
var spin := Vector3.ZERO
var pressing := false
var aimed := 0
var enraged := false
var body_time := 6.0
var clip_speed := 0.8
var _prog_t := 0.0
var _prog_pos := Vector3.ZERO
var _unstick_t := 0.0
var _hit_t := 0.0
var _hit_hp := 0.0
var _ignore = null
var _ignore_t := 0.0
var _no_prey = null
var _no_prey_t := 0.0
var _an_speed := 1.0
var _last_xz := Vector2.ZERO
var _lean := 0.0
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var anim: AnimationPlayer
var an_walk := ""
var an_attack := ""
var an_die := ""
var placeholder := true
var model_h := 1.76
var _mat_state := -1
var _cur_anim := ""
# World War Z piles: zombies pressing on a wall climb on each other; once
# the pile is as tall as the wall the ones on top go over.
var climb_skill := 0.5
var piling := false
var vault_t := 0.0
var vault_from := Vector3.ZERO
var vault_to := Vector3.ZERO
var vault_y0 := 0.0
var vault_h := 2.0

func build(v: String) -> void:
	variant = v
	model = Art.model(v)
	add_child(model)
	placeholder = model.has_meta("placeholder")
	meshes = Art.mesh_instances(model)
	model_h = Art.model_height(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		an_walk = Art.find_anim(anim, "walk")
		an_attack = Art.find_anim(anim, "attack")
		an_die = Art.find_anim(anim, "die")
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	visible = false

func reset(k: int, pos: Vector3, wave: int) -> void:
	kind = k
	alive = true
	active = true
	visible = true
	st = WALK
	position = pos
	y = 0.0
	vy = 0.0
	target = null
	flash_t = 0.0
	stagger_t = 0.0
	dead_t = 0.0
	burn_t = 0.0
	burn_fx = -1
	attack_t = randf_range(0.2, 0.8)
	climb_skill = randf()
	piling = false
	lane = Vector2(randf_range(-0.45, 0.45), randf_range(-0.45, 0.45))
	stuck_t = 0.0
	lost_t = 0.0
	flinch_t = 0.0
	kb = Vector3.ZERO
	flying = false
	aimed = 0
	enraged = false
	pressing = false
	spread = randf_range(-4.0, 4.0)
	gait_ph = randf() * TAU
	var gr := randf()
	gait = 0 if gr < 0.55 else (1 if gr < 0.8 else 2)
	clip_speed = float(CLIP_SPEED.get(variant, 0.8))
	var hp_scale := Defs.z_hp_scale(wave)
	var s := randf_range(0.9, 1.1)
	match k:
		Defs.Z_RUNNER:
			max_hp = Defs.Z_HP[1] * hp_scale
			speed = randf_range(2.8, 3.7)
			dmg = Defs.Z_DMG[1]
			reward = Defs.REWARD[1]
			s *= 0.95
			gait = 0
		Defs.Z_BRUTE:
			max_hp = Defs.Z_HP[2] * hp_scale
			speed = randf_range(0.8, 0.95)
			dmg = Defs.Z_DMG[2]
			reward = Defs.REWARD[2]
			gait = 2
			s *= 1.45 if placeholder else clampf(2.6 / model_h, 0.8, 1.6)
		_:
			max_hp = Defs.Z_HP[0] * hp_scale
			var r := randf()
			if r < 0.3:
				speed = randf_range(0.75, 1.0)
			elif r < 0.85:
				speed = randf_range(1.0, 1.45)
			else:
				speed = randf_range(1.5, 1.85)
			if gait == 1:
				speed *= 0.9
			dmg = Defs.Z_DMG[0]
			reward = Defs.REWARD[0]
	hp = max_hp
	if G.main:
		speed *= G.main.zombie_speed
	scale = Vector3(s, s, s)
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	_lean = 0.12 if gait == 2 else randf_range(-0.03, 0.05)
	_an_speed = speed / maxf(0.3, clip_speed * s)
	_last_xz = Vector2(pos.x, pos.z)
	var to_hq := Defs.hq_center() - pos
	heading = atan2(-to_hq.x, -to_hq.z)
	rotation.y = heading
	_mat_state = -1
	_cur_anim = ""
	groan_t = randf_range(2.0, 9.0)
	_apply_look()
	if G.sfx:
		if k == Defs.Z_BRUTE:
			G.sfx.play("brute_roar", pos)
		elif k == Defs.Z_RUNNER and randf() < 0.35:
			G.sfx.play("runner_shriek", pos)
	if anim and an_walk != "":
		anim.play(an_walk)
		anim.seek(randf() * 1.2, true)

func aim_point() -> Vector3:
	return position + Vector3(0, 1.15 * scale.y, 0)

func hurt(amount: float, from: Vector3 = Vector3.ZERO) -> void:
	if not alive:
		return
	hp -= amount
	flash_t = 0.07
	var heavy := 60.0 if kind == Defs.Z_BRUTE else 4.0
	if amount >= heavy:
		flinch_t = 0.22 if kind != Defs.Z_BRUTE else 0.14
	if amount >= 25.0 and from != Vector3.ZERO and kind != Defs.Z_BRUTE:
		var away := Vector3(position.x - from.x, 0, position.z - from.z)
		if away.length_squared() > 0.01:
			kb = away.normalized() * clampf(amount / 35.0, 0.6, 2.6)
	_apply_look()
	if hp <= 0.0:
		_die(from)

func blast(amount: float, p: Vector3) -> void:
	if not alive:
		return
	hurt(amount, p)
	stagger_t = 0.8
	if not alive and amount >= 60.0 and kind != Defs.Z_BRUTE:
		var away := Vector3(position.x - p.x, 0, position.z - p.z)
		if away.length_squared() < 0.01:
			away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		flying = true
		fly_v = away.normalized() * randf_range(2.5, 5.5) + Vector3(0, randf_range(3.5, 6.5), 0)
		spin = Vector3(randf_range(-9, 9), randf_range(-4, 4), randf_range(-9, 9))
		if G.fx:
			G.fx.gore(position)

func hurt_dot(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		_die(position)

func ignite(t: float) -> void:
	if not alive:
		return
	if burn_t <= 0.0 and G.fx:
		G.fx.burn_attach(self)
	burn_t = maxf(burn_t, t)

func _die(from: Vector3) -> void:
	alive = false
	st = DEAD
	dead_t = 0.0
	target = null
	G.zombies.on_killed(self)
	var dying: int = G.zombies.dying_count
	body_time = randf_range(5.0, 7.5) if dying < 60 else (randf_range(3.0, 4.5) if dying < 150 else 2.0)
	if from != Vector3.ZERO and from.distance_squared_to(position) > 0.01 and kind != Defs.Z_BRUTE:
		var away := Vector3(position.x - from.x, 0, position.z - from.z).normalized()
		kb = away * randf_range(0.8, 1.8)
		heading = atan2(away.x, away.z)
	model.rotation.y = randf_range(-0.6, 0.6)
	_apply_look()
	if anim and an_die != "":
		anim.play(an_die, 0.1)
		anim.speed_scale = randf_range(0.8, 1.3)
	if G.fx:
		G.fx.blood(Vector3(position.x, y + 0.03, position.z), scale.x * randf_range(0.8, 1.25))
		if randf() < 0.5:
			G.fx.blood_puff(position + Vector3(0, 1.0 * scale.y, 0))
	if G.sfx and (near or kind == Defs.Z_BRUTE):
		G.sfx.play("zombie_death", position)

func vanish() -> void:
	if not alive:
		return
	alive = false
	st = DEAD
	target = null
	G.zombies.alive_count -= 1
	G.zombies.recycle(self)
var near := true
var radius := 0.35
var stuck_t := 0.0
var lost_t := 0.0
var chase_t := 0.0
var chase_best := 1000000000.0
var dbg_goal := Vector3.ZERO

func step(dt: float) -> void:
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			_apply_look()
	if st == DEAD:
		_step_dead(dt)
		return
	if burn_t > 0.0:
		burn_t -= dt
		hurt_dot(Defs.BURN_DPS * dt)
		if not alive:
			return
	var g: Grid = G.grid
	var nc := Vector2i(floori(position.x + Defs.HALF), floori(position.z + Defs.HALF))
	var inside := nc.x >= 0 and nc.y >= 0 and nc.x < Defs.NW and nc.y < Defs.NH
	nc.x = clampi(nc.x, 0, Defs.NW - 1)
	nc.y = clampi(nc.y, 0, Defs.NH - 1)
	ci = nc.y * Defs.NW + nc.x
	var bi := (nc.y >> 1) * Defs.W + (nc.x >> 1)
	var tr: int = g.terrain[bi]
	var fy := -Defs.TRENCH_DEPTH if inside and (tr == Defs.T_TRENCH or tr == Defs.T_TUNNEL) else 0.0
	if inside and G.flow.dist[ci] >= 1.0e+19:
		lost_t += dt
		if lost_t > 12.0:
			vanish()
			return
	else:
		lost_t = 0.0
	if st == VAULT:
		vault_t += dt
		var vf := clampf(vault_t / VAULT_TIME, 0.0, 1.0)
		var vp := vault_from.lerp(vault_to, vf)
		position.x = vp.x
		position.z = vp.z
		y = lerpf(vault_y0, fy, vf) + sin(vf * PI) * maxf(0.4, vault_h + 0.4 - lerpf(vault_y0, fy, vf))
		if vf >= 1.0:
			y = fy
			st = WALK
			stagger_t = 0.4
		_finish_step(dt, false)
		return
	var was_piling := piling
	piling = false
	if st == CLIMB:
		climb_t += dt
		var f := clampf(climb_t / climb_total, 0.0, 1.0)
		y = lerpf(climb_from, 0.0, f * f * (3.0 - 2.0 * f))
		if climb_t >= climb_total:
			y = 0.0
			st = WALK
			position += climb_dir * 0.6
		_finish_step(dt, false)
		return
	if y > fy + 0.02 and not was_piling:
		if st != FALL:
			st = FALL
			vy = 0.0
			stagger_t = 0.6
		vy -= 20.0 * dt
		y = maxf(fy, y + vy * dt)
		if y <= fy:
			y = fy
			st = WALK
			if G.sfx:
				G.sfx.play("thud", position)
	elif y < fy:
		y = fy
	var flow: FlowField = G.flow
	var nx: int = flow.next[ci]
	var goal := Vector3.ZERO
	var blocker = null
	if nx < 0:
		var own = g.nown[ci]
		if own != null and is_instance_valid(own) and own is Building and Grid.is_structure(g.nblk[ci]) and own.state == Building.BUILT:
			blocker = own
			goal = own.position
		else:
			goal = Defs.hq_center()
	else:
		var own2 = g.nown[nx]
		if own2 != null and Grid.is_structure(g.nblk[nx]) and is_instance_valid(own2):
			blocker = own2
		elif _unstick_t <= 0.0 and (own2 == null or not Grid.is_structure(g.nblk[nx])):
			var j: int = flow.next[nx]
			for k in 3:
				if j < 0:
					break
				var o3 = g.nown[j]
				if o3 != null and Grid.is_structure(g.nblk[j]) and o3 is LinearStructure and is_instance_valid(o3) and o3.state == Building.BUILT:
					blocker = o3
					break
				j = flow.next[j]
		goal = Defs.nav_center(g.ncell_of(nx)) + Vector3(lane.x, 0, lane.y)
	if _no_prey_t > 0.0:
		_no_prey_t -= dt
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = randf_range(0.5, 0.9) if tier <= 1 else randf_range(1.2, 2.0)
		if fy > -0.5 and (target == null or not is_instance_valid(target) or target.state != Building.BUILT):
			target = null
			if kind == Defs.Z_BRUTE and G.helis:
				target = G.helis.landed_near(position, 10.0)
			if target == null and G.people:
				target = G.people.prey_near(self, 9.0, _no_prey if _no_prey_t > 0.0 else null)
			chase_best = 1000000000.0
			chase_t = 0.0
	if target != null:
		if is_instance_valid(target) and target.state == Building.BUILT and fy > -0.5 and target.edge_distance(position) <= 10.0 and (not (target is Person) or target.exposed()):
			if target is Building:
				if target.edge_distance(position) <= 2.0:
					blocker = target
			else:
				blocker = target
				var dd: float = target.edge_distance(position)
				if dd < chase_best - 0.25:
					chase_best = dd
					chase_t = 0.0
				else:
					chase_t += dt
					if chase_t > 4.0:
						_no_prey = target
						_no_prey_t = 30.0
						target = null
						blocker = null
						scan_t = randf_range(5.0, 8.0)
		else:
			target = null
	if _ignore_t > 0.0:
		_ignore_t -= dt
		if blocker == _ignore:
			blocker = null
			if target == _ignore:
				target = null
			goal = Defs.hq_center() if nx < 0 else goal
	elif blocker is Building and not (blocker is LinearStructure) and not blocker.has_health():
		_ignore = blocker
		_ignore_t = 10.0
		blocker = null
	pressing = blocker != null
	if blocker != null:
		var reach := REACH * scale.x
		if blocker.edge_distance(position) <= reach:
			_attack(blocker, dt)
			if blocker is LinearStructure and kind != Defs.Z_BRUTE and fy > -0.5:
				_pile(blocker, dt, fy)
				if st == VAULT:
					_finish_step(dt, false)
					return
			if sep.length_squared() > 0.01:
				if blocker is LinearStructure:
					var along: Vector3 = blocker.dir * (sep.x * blocker.dir.x + sep.y * blocker.dir.z)
					_move(along * dt * 1.6, ci, fy)
				elif not (blocker is Person):
					_move(Vector3(sep.x, 0, sep.y) * dt * 0.5, ci, fy)
			_finish_step(dt, false)
			return
		if blocker is LinearStructure:
			var ap := Vector3(position.x - blocker.a.x, 0, position.z - blocker.a.z)
			var tt: float = clampf(ap.dot(blocker.dir) + spread, -1.5, blocker.length + 1.5)
			goal = blocker.a + blocker.dir * tt
		else:
			goal = blocker.position
	if st == ATTACK:
		st = WALK
	var spd := speed
	if fy < -0.5:
		spd *= 0.45
	var here = g.occ[bi]
	if here != null and here.state == Building.BUILT:
		if here.kind == "spikes":
			spd *= 0.5
		elif here.kind == "wire":
			spd *= Defs.WIRE_SLOW
	if stagger_t > 0.0:
		stagger_t -= dt
		spd *= 0.35
	var crowd := sep.length()
	if crowd > 0.8:
		spd *= clampf(1.25 - crowd * 0.3, 0.35, 1.0)
	if inside and g.nblk[ci] == Grid.N_SLOW:
		spd *= 0.45
	if flinch_t > 0.0:
		flinch_t -= dt
		spd *= 0.3
	gait_ph += dt * speed * 2.4
	if gait == 1:
		spd *= 0.7 + 0.5 * absf(sin(gait_ph))
	if not near and flow.dist[ci] > 40.0:
		spd *= 1.6
	if kb.length_squared() > 0.01:
		_move(kb * dt, ci, fy)
		kb = kb.move_toward(Vector3.ZERO, dt * 9.0)
	if fy < -0.5 and nx >= 0 and blocker == null and not g.n_trench_i(nx) and st == WALK:
		var ncen := Defs.nav_center(g.ncell_of(nx))
		var dx := maxf(absf(position.x - ncen.x) - 0.5, 0.0)
		var dz := maxf(absf(position.z - ncen.z) - 0.5, 0.0)
		if dx * dx + dz * dz < 0.06:
			st = CLIMB
			climb_t = 0.0
			climb_from = y
			var dir := Vector3(ncen.x - position.x, 0, ncen.z - position.z).normalized()
			climb_dir = dir
			climb_total = randf_range(0.9, 1.3) if kind == Defs.Z_RUNNER else randf_range(1.8, 2.7)
			if kind == Defs.Z_BRUTE:
				climb_total = 3.2
			heading = atan2(-dir.x, -dir.z)
			_finish_step(dt, false)
			return
	_prog_t += dt
	if _unstick_t > 0.0:
		_unstick_t -= dt
	if _prog_t > 2.0:
		if st == WALK and position.distance_to(_prog_pos) < 0.4 and blocker == null:
			_unstick_t = 3.0
		_prog_t = 0.0
		_prog_pos = position
	if _unstick_t > 1.8 and blocker == null:
		goal = position + Vector3(goal.x - position.x, 0, goal.z - position.z).rotated(Vector3.UP, 1.2 if (id & 1) == 0 else -1.2)
	dbg_goal = goal
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var dist := to.length()
	var mv := Vector3.ZERO
	if dist > 0.01:
		mv = to / dist * minf(spd * dt, dist)
		if blocker == null and target == null and inside and flow.dist[ci] > 12.0:
			mv = mv.rotated(Vector3.UP, sin(G.sim_time * 0.33 + id * 1.37) * 0.38)
	if near:
		mv.x += sep.x * dt
		mv.z += sep.y * dt
	_move(mv, ci, fy)
	if mv.length_squared() > 1.0e-06:
		heading = atan2(-mv.x, -mv.z)
	_finish_step(dt, true)

func _pile(w, dt: float, fy: float) -> void:
	var h := float(w.def.get("height", 2.2))
	var f := clampf(float(w.press) / float(w.pile_need()), 0.0, 1.0)
	var want := fy + h * f * (0.2 + 0.8 * climb_skill)
	piling = true
	y = move_toward(y, maxf(fy, want), dt * 1.8)
	if f >= 1.0 and y >= fy + h * 0.7:
		_start_vault(w, h, fy)

func _start_vault(w, h: float, fy: float) -> void:
	var n := Vector3(-w.dir.z, 0, w.dir.x)
	var side := signf((position - w.position).dot(n))
	if side == 0.0:
		side = 1.0
	var along := clampf((position - w.a).dot(w.dir), 0.0, w.length)
	var base: Vector3 = w.a + w.dir * along
	for d in [1.4, 2.0, 2.7]:
		var to: Vector3 = base - n * side * d
		var c := Vector2i(floori(to.x + Defs.HALF), floori(to.z + Defs.HALF))
		if c.x < 0 or c.y < 0 or c.x >= Defs.NW or c.y >= Defs.NH:
			continue
		var b: int = G.grid.nblk[c.y * Defs.NW + c.x]
		if b != Grid.N_OPEN and b != Grid.N_SLOW:
			continue
		vault_from = position
		vault_to = Vector3(to.x, 0, to.z)
		vault_y0 = y
		vault_h = h
		vault_t = 0.0
		st = VAULT
		target = null
		piling = false
		return

func _move(mv: Vector3, cur: int, fy: float) -> void:
	var np := position + mv
	if not _can_enter(np, cur, fy):
		var a := Vector3(np.x, position.y, position.z)
		var b := Vector3(position.x, position.y, np.z)
		if _can_enter(a, cur, fy):
			np = a
		elif _can_enter(b, cur, fy):
			np = b
		else:
			return
	position = _push_walls(np)

func _push_walls(p: Vector3) -> Vector3:
	var g: Grid = G.grid
	var c := Vector2i(floori(p.x + Defs.HALF), floori(p.z + Defs.HALF))
	if c.x < 0 or c.y < 0 or c.x >= Defs.NW or c.y >= Defs.NH:
		return p
	if g.wall_near.size() == Defs.NW * Defs.NH and g.wall_near[c.y * Defs.NW + c.x] == 0:
		return p
	var r := radius * scale.x
	var seen0 = null
	var seen1 = null
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= Defs.NW or n.y >= Defs.NH:
				continue
			var i := n.y * Defs.NW + n.x
			var b := g.nblk[i]
			if b != Grid.N_WALL and b != Grid.N_GATE:
				continue
			var s = g.nown[i]
			if s == null or s == seen0 or s == seen1:
				continue
			if seen0 == null:
				seen0 = s
			else:
				seen1 = s
			p = s.push_out(p, r)
	return p

func _can_enter(p: Vector3, cur: int, fy: float) -> bool:
	var cx := floori(p.x + Defs.HALF)
	var cy := floori(p.z + Defs.HALF)
	if cx < 0 or cy < 0 or cx >= Defs.NW or cy >= Defs.NH:
		return true
	var i := cy * Defs.NW + cx
	if i == cur:
		return true
	var g: Grid = G.grid
	var b := g.nblk[i]
	if b == Grid.N_BUILD or b == Grid.N_ROCK or b == Grid.N_STATIC:
		return false
	if fy < -0.5:
		var t: int = g.terrain[(cy >> 1) * Defs.W + (cx >> 1)]
		if t != Defs.T_TRENCH and t != Defs.T_TUNNEL:
			return false
	return true

func enrage() -> void:
	if enraged or not alive:
		return
	enraged = true
	dmg *= 4.0
	speed *= 1.5

func _attack(b, dt: float) -> void:
	if st != ATTACK or target != b:
		_hit_t = 0.0
		_hit_hp = b.hp if "hp" in b else 0.0
	st = ATTACK
	target = b
	_hit_t += dt
	if _hit_t > 9.0:
		var hp_now: float = b.hp if "hp" in b else 0.0
		if hp_now >= _hit_hp - 0.5:
			_ignore = b
			_ignore_t = 10.0
			target = null
			st = WALK
			return
		_hit_t = 0.0
		_hit_hp = hp_now
	dbg_goal = b.position
	var to: Vector3 = b.position - position
	heading = atan2(-to.x, -to.z)
	attack_t -= dt
	if attack_t <= 0.0:
		attack_t = ATTACK_INTERVAL
		b.take_damage(dmg, self)
		if b is Person:
			if G.sfx:
				G.sfx.play("zombie_attack", position)
		else:
			if G.fx and randf() < 0.5:
				G.fx.chips(position + Vector3(0, 1.0, 0) + (to.normalized() * 0.4))
			if G.sfx:
				G.sfx.hit_structure(b.kind, position)

func _finish_step(dt: float, moving: bool) -> void:
	position.y = y
	var xz := Vector2(position.x, position.z)
	var v := xz.distance_to(_last_xz) / maxf(dt, 0.001)
	_last_xz = xz
	if st == WALK or st == FALL:
		var want := clampf(v / maxf(0.2, clip_speed * scale.x), 0.25, 2.8)
		_an_speed = lerpf(_an_speed, want, minf(1.0, dt * 6.0))
	if not placeholder and tier == 0:
		var fl := flinch_t / 0.22
		var sway := sin(gait_ph) * (0.07 if gait == 1 else 0.025)
		model.rotation.x = _lean - fl * 0.32 if st != ATTACK else -fl * 0.3
		model.rotation.z = sway
	if G.sfx and tier == 0:
		groan_t -= dt
		if groan_t <= 0.0:
			groan_t = randf_range(4.0, 8.0)
			if id % 6 == 0:
				G.sfx.play("zombie_groan", position)
		if kind == Defs.Z_BRUTE and moving:
			if fmod(G.sim_time + id * 0.13, 0.6) < dt:
				G.sfx.play("brute_step", position)
	rotation.y = lerp_angle(rotation.y, heading, minf(1.0, dt * 8.0))
	if placeholder:
		if st == WALK or st == FALL:
			bob += dt * speed * 3.2
			model.position.y = absf(sin(bob)) * 0.05
			model.rotation.z = sin(bob * 0.5) * 0.07
			model.rotation.x = 0.0
		elif st == ATTACK or st == CLIMB:
			bob += dt * 7.5
			model.position.y = 0.0
			model.rotation.x = -0.12 + sin(bob) * 0.08
			model.rotation.z = 0.0
		_apply_look()
		return
	var want_look := 0
	if flash_t > 0.0:
		want_look = 3
	elif st == ATTACK or st == CLIMB or st == VAULT:
		want_look = 1
	if want_look != _mat_state or (want_look == 0 and _cur_anim != an_walk):
		_apply_look()
	elif anim and tier <= 1 and want_look == 0 and absf(anim.speed_scale - _an_speed) > 0.04:
		anim.speed_scale = _an_speed

func _step_dead(dt: float) -> void:
	dead_t += dt
	if flying:
		fly_v.y -= 18.0 * dt
		position += Vector3(fly_v.x, 0, fly_v.z) * dt
		y += fly_v.y * dt
		model.rotation += spin * dt
		var fy: float = G.grid.n_floor_y(position) if G.grid else 0.0
		if y <= fy and fly_v.y < 0.0:
			y = fy
			flying = false
			model.rotation.x = clampf(model.rotation.x, -0.4, 0.4)
			model.rotation.z = clampf(model.rotation.z, -0.4, 0.4)
			if G.fx:
				G.fx.blood(Vector3(position.x, y + 0.03, position.z), scale.x)
			if G.sfx and near:
				G.sfx.play("thud", position)
		position.y = y
		return
	if kb.length_squared() > 0.01:
		position += kb * dt
		kb = kb.move_toward(Vector3.ZERO, dt * 5.0)
	rotation.y = lerp_angle(rotation.y, heading, minf(1.0, dt * 6.0))
	if placeholder:
		var f := clampf(dead_t / 0.55, 0.0, 1.0)
		model.rotation.x = f * f * PI * 0.48
		model.position.y = 0.0
	if dead_t > body_time:
		y -= dt * 0.7
		position.y = y
	if dead_t >= body_time + SINK_TIME:
		G.zombies.recycle(self)

func _apply_look() -> void:
	var want := 0
	if flash_t > 0.0 and st != DEAD:
		want = 3
	elif st == DEAD:
		want = 2
	elif st == ATTACK or st == CLIMB:
		want = 1
	if placeholder:
		if want != _mat_state:
			_mat_state = want
			var m: Material = Art.zmat_walk
			match want:
				1: m = Art.zmat_attack
				2: m = Art.zmat_still
				3: m = Art.zmat_flash
			for mi in meshes:
				mi.material_override = m
		return
	if want != _mat_state:
		var was_flash := _mat_state == 3
		_mat_state = want
		if want == 3:
			for mi in meshes:
				mi.material_override = Art.mat_flash
		elif was_flash:
			for mi in meshes:
				mi.material_override = null
	if anim:
		var a := an_walk
		var sp := _an_speed
		if st == ATTACK or st == CLIMB or st == VAULT:
			a = an_attack if an_attack != "" else an_walk
			sp = 1.0
		elif st == DEAD:
			if a != _cur_anim and an_die != "":
				_cur_anim = an_die
			return
		if a != "" and a != _cur_anim:
			_cur_anim = a
			anim.play(a, 0.12)
		anim.speed_scale = sp
