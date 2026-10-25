extends SceneTree
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
	var g = root.get_node("G")
	var t0 := Time.get_ticks_usec()
	var d: Dictionary = load("res://scripts/maps/city_layout.gd").data()
	var t1 := Time.get_ticks_usec()
	g.map._seal_pockets()
	var t2 := Time.get_ticks_usec()
	for t in d["towers"]:
		if not t["out"]:
			g.map._rock_rect(t["r"])
	var t3 := Time.get_ticks_usec()
	var A = load("res://scripts/maps/city_art.gd")
	var b = A.Batch.new()
	for t in d["towers"]:
		A.add_tower(b, t)
	var t4 := Time.get_ticks_usec()
	print("PROF layout=%.1fms seal=%.1fms rock=%.1fms meshes=%.1fms verts=%d tris=%d" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, b.v.size(), b.idx.size() / 3])
	quit()
