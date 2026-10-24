class_name FenceRun
extends RefCounted
var kind := "wood"
var pts: Array = []
var cells := PackedInt32Array()
var pieces: Array = []
var claimed := false
var map = null

static func model_of(k: String) -> String:
	match k:
		"picket":
			return "suburb/fence_picket"
		"hedge":
			return "suburb/hedge"
		"brick":
			return "suburb/garden_wall_brick"
	return "suburb/fence_wood"

static func wall_kind(k: String) -> String:
	match k:
		"wood":
			return "fence"
		"picket":
			return "picket"
		"hedge":
			return "hedge"
	return "brickwall"

func length() -> float:
	var l := 0.0
	for i in pts.size() - 1:
		l += (pts[i] as Vector3).distance_to(pts[i + 1])
	return l

func distance(p: Vector3) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best

func claim_cost() -> int:
	return maxi(5, int(ceil(float(Defs.BUILD[wall_kind(kind)]["claim_per_m"]) * length())))

func display_name() -> String:
	return {"wood": "Garden Fence", "picket": "Picket Fence", "hedge": "Hedge", "brick": "Garden Wall"}.get(kind, "Fence")

func card_title() -> String:
	return display_name()

func card_lines() -> Array:
	var d: Dictionary = Defs.BUILD[wall_kind(kind)]
	return ["%.0f m  ·  %s" % [length(), String(d.get("about", ""))], "Claim it: workers make it part of your walls"]

func card_buttons() -> Array:
	var c := claim_cost()
	return [["claim_fence", "CLAIM %d" % c, G.main.supplies >= c]]

func claim() -> String:
	if claimed:
		return "Already yours"
	var c := claim_cost()
	if not G.main.spend(c):
		return "Claiming costs %d" % c
	claimed = true
	var wk := wall_kind(kind)
	var made := []
	var total := length()
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		made.append_array(G.walls.lay(wk, a, b, int(round(c * a.distance_to(b) / maxf(total, 0.1))), false))
	map.unblock(cells, self)
	map.hide_run(self)
	G.walls.last_plan = made
	G.walls.refresh_posts()
	G.grid.notify_paths_changed()
	return ""
