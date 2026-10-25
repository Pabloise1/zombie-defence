extends SceneTree
# Clearing map clutter: knock down a suburb house with workers, build on a
# tree cell (suburb) or a rock cell (fields), and save/load a cleared house.
var started := false
func _process(_d):
	if started:
		return false
	started = true
	_run()
	return false
func _run() -> void:
	var g = root.get_node("G")
	var SG = load("res://scripts/save_game.gd")
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var m = current_scene
	m.hud.show_title(false)
	m.phase = "build"
	m.phase_t = 9999.0
	m.supplies = 1000
	var c: Vector3 = Defs.hq_center()
	var clutter: Array = g.grid.clutter_nav.keys()
	print("CLR map=%s clutter cells=%d" % [g.map_id, clutter.size()])
	var near := -1
	var bd := INF
	for ni in clutter:
		var p: Vector3 = Defs.nav_center(g.grid.ncell_of(ni))
		var d := p.distance_to(c)
		var bc := Defs.nav_to_build(g.grid.ncell_of(ni))
		if d < bd and d > 12.0 and m.buildings.check("turret", bc) == "":
			bd = d
			near = ni
	if near >= 0:
		var bc2 := Defs.nav_to_build(g.grid.ncell_of(near))
		var b = m.buildings.place_built("turret", bc2)
		print("CLR built a turret on clutter at %.0fm: %s, still clutter=%s, nav=%d" % [bd, "ok" if b else "FAILED", g.grid.clutter_nav.has(near), g.grid.nblk[near]])
	else:
		print("CLR no buildable clutter found")
	if g.map:
		var houses: Array = g.map.buildings.filter(func(x): return x.kind.begins_with("house"))
		houses.sort_custom(func(a, b): return a.position.distance_to(c) < b.position.distance_to(c))
		var h = houses[0]
		var cell0: Vector2i = h.cell_list[0]
		print("CLR house %s at %.0fm: before, building there says '%s'" % [h.kind, h.position.distance_to(c), m.buildings.check("turret", cell0)])
		var s0: int = m.supplies
		print("CLR start_clear: '%s'" % h.start_clear())
		var t := 0
		while not h.cleared and t < 30 * 120:
			m.sim_step(1.0 / 30.0)
			t += 1
		print("CLR cleared=%s after %.0fs, supplies %+d, building there now says '%s'" % [h.cleared, t / 30.0, m.supplies - s0, m.buildings.check("turret", cell0)])
		SG.write(m)
		g.resume = SG.read()
		var idx: int = g.map.buildings.find(h)
		change_scene_to_file("res://scenes/main.tscn")
		for i in 5:
			await process_frame
		m = current_scene
		var h2 = g.map.buildings[idx]
		print("CLR after reload: cleared=%s visible=%s check='%s'" % [h2.cleared, h2.visible, m.buildings.check("turret", cell0)])
		SG.clear()
	quit()
