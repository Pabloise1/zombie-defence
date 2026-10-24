class_name HQBuilding
extends Building
var _radar: Node3D

func _on_model_ready() -> void:
	_radar = model.find_child("Radar", true, false) as Node3D

func tick(dt: float) -> void:
	super.tick(dt)
	if _radar:
		_radar.rotation.y += dt * 0.9

func destroy(effects: bool) -> void:
	if state == DEAD:
		return
	if G.fx:
		G.fx.explosion(position + Vector3(0, 1.5, 0), 2.2)
		G.fx.debris(position + Vector3(0, 1.0, 0), 3)
	if G.cam:
		G.cam.shake(1.2)
	if G.sfx:
		G.sfx.play("boom", position)
	state = DEAD
	model.visible = false
	if G.main:
		G.main.on_hq_destroyed()

func card_lines() -> Array:
	if G.people == null:
		return []
	var out := ["People %d/%d  ·  idle %d" % [G.people.population(), G.people.pop_cap(), G.people.idle_count()]]
	if G.workers and G.workers.pending_count() > 0:
		out.append("Build queue: %d job%s (wall repairs go first)" % [G.workers.pending_count(), "" if G.workers.pending_count() == 1 else "s"])
	return out

func card_buttons() -> Array:
	return []

func access_goals() -> Dictionary:
	return G.grid.point_goals(position + Vector3(0, 0, 4.0), 2)

func card_rows() -> Array:
	if G.people == null:
		return []
	var idle: int = G.people.idle_count()
	var rows := []
	for job in Defs.JOBS:
		var n: int = G.people.count_job(job)
		var label: String = Defs.JOB_NAMES[job]
		var note := ""
		match job:
			"worker":
				note = "Build and repair"
			"soldier":
				note = "Arm for %d" % G.logi.soldier_cost()
			"loader":
				note = "Feed and crew the guns"
			"fetcher":
				note = "Bring scrap home"
			"crafter":
				note = "Make ammo at a workshop" if G.buildings.count_built("workshop") > 0 else "Needs a workshop"
		var can_plus := idle > 0
		if job == "soldier":
			can_plus = can_plus and G.main.supplies >= G.logi.soldier_cost()
		rows.append([job, label, n, n > 0, can_plus, note])
	return rows
