extends SceneTree
var done = false
func _process(_d):
	if done:
		return false
	done = true
	var f = FileAccess.open(OS.get_environment("LIST"), FileAccess.READ)
	var bad = 0
	var n = 0
	while not f.eof_reached():
		var p = f.get_line().strip_edges()
		if p == "":
			continue
		n += 1
		var s = load(p)
		if s == null or not (s is GDScript):
			print("BAD ", p); bad += 1
	print("checked ", n, " bad=", bad)
	quit()
	return false
