class_name WorkerManager
extends Node3D
var workers: Array = []
var jobs: Array = []
var completed := 0
var _assign_t := 0.0
var _fail_until := {}

func add_worker(at: Vector3) -> Worker:
	var w := Worker.new()
	w.name = "Worker%d" % workers.size()
	add_child(w)
	w.setup(at)
	workers.append(w)
	return w

func remove_worker(w: Worker) -> void:
	w.drop_job()
	workers.erase(w)

func add_job(j) -> void:
	jobs.append(j)
	_assign_t = 0.0

func remove_job(j) -> void:
	jobs.erase(j)
	for w in workers:
		if w.job == j or w.repairing == j:
			w.drop_job()

func job_done(j) -> void:
	jobs.erase(j)
	completed += 1

func pending_count() -> int:
	return jobs.size()

func queue_pos(j) -> int:
	var order := _ordered()
	var k := order.find(j)
	return k + 1 if k >= 0 else 0

func _ordered() -> Array:
	var first := []
	var rest := []
	for j in jobs:
		if is_instance_valid(j) and j is LinearStructure and j.rebuild_of != "":
			first.append(j)
		else:
			rest.append(j)
	return first + rest

func step(dt: float) -> void:
	_assign_t -= dt
	if _assign_t <= 0.0:
		_assign_t = 0.3
		_assign()
	for w in workers:
		w.step(dt)
	for c in get_children():
		if c is Worker and c.dead and not workers.has(c):
			c.step(dt)

func _taken_repair(b, w) -> bool:
	for o in workers:
		if o != w and o.repairing == b:
			return true
	return false

func _assign() -> void:
	for k in range(jobs.size() - 1, -1, -1):
		if not is_instance_valid(jobs[k]) or not jobs[k].job_valid():
			jobs.remove_at(k)
	var damaged: Array = G.buildings.damaged()
	damaged.sort_custom(func(a, b): return _fix_rank(a) < _fix_rank(b))
	var wall_fix := []
	var other_fix := []
	for b in damaged:
		if b.is_wallish():
			wall_fix.append(b)
		else:
			other_fix.append(b)
	var order := _ordered()
	for w in workers:
		if w.dead or w.is_busy() or w.fleeing or w.hiding:
			continue
		if _try_repair(w, wall_fix):
			continue
		var got := false
		for j in order:
			if j.worker != null and is_instance_valid(j.worker):
				continue
			if j.has_method("job_ready") and not j.job_ready():
				continue
			if _fail_until.get(j, -1.0) > G.sim_time:
				continue
			if w.assign(j):
				got = true
				break
			_fail_until[j] = G.sim_time + 2.0
		if got:
			continue
		_try_repair(w, other_fix)

func _fix_rank(b) -> float:
	var r: float = b.hp / maxf(1.0, b.max_hp)
	if G.sim_time - b.hit_at < 25.0:
		r -= 0.5
	if G.soldiers:
		r -= 0.25 * G.soldiers.threat_at(b.position)
	return r

func _try_repair(w, list: Array) -> bool:
	for b in list:
		if _taken_repair(b, w) or _fail_until.get(b, -1.0) > G.sim_time:
			continue
		if w.assign_repair(b):
			return true
		_fail_until[b] = G.sim_time + 3.0
	return false
