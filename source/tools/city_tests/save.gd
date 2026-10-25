extends SceneTree
# City save/restore: claim a shop, wall a street mouth, capture, reload with
# G.resume and compare.
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false
func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	var g = root.get_node("G")
	m.manual_clock = true
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	var shop = null
	for mb in g.map.buildings:
		if mb.kind == "corner_shop":
			shop = mb
			break
	shop._claimed(true)
	m.walls.lay("wall", Vector3(-6.6, 0, -24), Vector3(6.6, 0, -24), 0, true)
	for i in 30:
		m.sim_step(1.0 / 30.0)
	var SG = load("res://scripts/save_game.gd")
	var d: Dictionary = SG.capture(m)
	var seed0: int = m.map_seed
	var towers0: int = (g.map.layout["towers"] as Array).size()
	var walls0: int = m.walls.live().size()
	print("SAVE map=%s seed=%d claimed_shop=%s walls=%d" % [d["map"], d["seed"], shop.position, walls0])
	g.resume = d
	change_scene_to_file("res://scenes/main.tscn")
	for i in 8:
		await process_frame
	m = current_scene
	var claimed := 0
	for mb in g.map.buildings:
		if mb.claimed:
			claimed += 1
	print("LOAD map=%s seed=%d (same=%s) towers=%d (same=%s) claimed=%d walls=%d" % [g.map_id, m.map_seed, str(m.map_seed == seed0),
		(g.map.layout["towers"] as Array).size(), str((g.map.layout["towers"] as Array).size() == towers0), claimed, m.walls.live().size()])
	quit()
