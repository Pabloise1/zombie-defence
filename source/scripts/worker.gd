class_name Worker
extends Person
enum {IDLE, WALK, WORK}
var mode := IDLE
var job = null
var repairing = null
var home := Vector3.ZERO
var _tool_t := 0.0
var _resume = null
var _dust_t := 0.0

func setup(at: Vector3) -> void:
	kind = "worker"
	speed = 3.3
	position = at
	setup_model("worker", ["idle", "walk", "work"])
	_go_home()

func is_busy() -> bool:
	return job != null or repairing != null

func assign(j) -> bool:
	job = j
	j.worker = self
	repairing = null
	if not walk_to_goals(j.job_goals()):
		j.worker = null
		job = null
		return false
	mode = WALK
	return true

func assign_repair(b) -> bool:
	repairing = b
	if not walk_to_goals(b.job_goals()):
		repairing = null
		return false
	mode = WALK
	return true

func drop_job() -> void:
	if job != null and is_instance_valid(job) and job.worker == self:
		job.worker = null
	job = null
	repairing = null
	mode = IDLE
	_go_home()

func _go_home() -> void:
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func _on_death() -> void:
	if job != null and is_instance_valid(job) and job.worker == self:
		job.worker = null
	job = null

func _on_flee() -> void:
	_resume = job if job != null else repairing
	if job != null and is_instance_valid(job) and job.worker == self:
		job.worker = null
	job = null
	repairing = null
	mode = IDLE

func _on_safe() -> void:
	var r = _resume
	_resume = null
	if r != null and is_instance_valid(r):
		if r.has_method("job_valid") and r.job_valid() and (r.worker == null or not is_instance_valid(r.worker)):
			if assign(r):
				return
		elif r is Building and r.needs_repair():
			if assign_repair(r):
				return
	_go_home()

func step(dt: float) -> void:
	if dead:
		step_dead(dt)
		return
	_moving = false
	scan_threat(dt, 8.0)
	if flee_step(dt):
		settle(dt)
		animate(dt)
		return
	if job != null and (not is_instance_valid(job) or not job.job_valid()):
		job = null
		mode = IDLE
		_go_home()
	if repairing != null and (not is_instance_valid(repairing) or not repairing.needs_repair()):
		repairing = null
		mode = IDLE
		_go_home()
	if not arrived():
		follow(dt)
	elif (job != null or repairing != null) and mode == WALK:
		mode = WORK
	if mode == WORK:
		var target = job if job != null else repairing
		if target != null:
			face_point(target.job_world_pos())
			_tool_t -= dt
			if _tool_t <= 0.0 and G.sfx:
				_tool_t = randf_range(0.45, 0.65)
				var snd := "hammer"
				if target is DigMark:
					snd = "dig"
				elif target is LinearStructure and target.kind == "wall" and randf() < 0.4:
					snd = "saw"
				G.sfx.play(snd, position)
			_dust_t -= dt
			if _dust_t <= 0.0 and G.fx and job != null:
				_dust_t = randf_range(1.2, 2.2)
				G.fx.dust(target.job_world_pos().lerp(position, 0.4) + Vector3(0, 0.3, 0), 0.45)
			if job != null:
				if job.work(dt):
					var finished = job
					job = null
					mode = IDLE
					G.workers.job_done(finished)
			elif repairing.repair(dt):
				repairing = null
				mode = IDLE
	anim_mode = "work" if mode == WORK else "idle"
	settle(dt)
	animate(dt)
