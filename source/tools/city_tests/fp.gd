extends SceneTree
var started := false
func _process(_d):
	if started:
		return false
	started = true
	var art = root.get_node("Art")
	for k in ["corner_shop", "petrol_station", "house_two_storey", "car_sedan_wreck", "car_hatch_wreck", "van_wreck", "school_bus_wreck", "streetlight", "bench", "bins", "tree_oak", "tree_pine", "tree_birch", "bush_a", "power_pole", "mailbox"]:
		var f = art.footprint("suburb/" + k)
		var root2 = art.model("suburb/" + k)
		var aabb := AABB()
		var first := true
		for mi in root2.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
			aabb = bb if first else aabb.merge(bb)
			first = false
		print(k, " fp=", f, " aabb=", aabb)
		root2.free()
	quit()
	return false
