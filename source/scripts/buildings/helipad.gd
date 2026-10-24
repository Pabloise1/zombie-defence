class_name Helipad
extends PrefabBuilding
var heli = null

func land_xform() -> Transform3D:
	var m := model.find_child("Land", true, false) as Node3D if model else null
	if m:
		return m.global_transform
	return global_transform.translated(Vector3(0, 0.6, 0))

func heli_kind() -> String:
	return String(def.get("heli", "huey"))

func heli_cost() -> int:
	return int(def.get("heli_cost", 450))

func buy_heli() -> String:
	if state != BUILT:
		return "Finish the pad first"
	if heli != null and is_instance_valid(heli):
		return "There's one here already"
	var c := heli_cost()
	if not G.main.spend(c):
		return "It costs %d" % c
	heli = G.helis.add_heli(heli_kind(), self)
	return ""

func _on_destroyed(effects: bool) -> void:
	if heli != null and is_instance_valid(heli):
		heli._crash()
	super._on_destroyed(effects)

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	var hk: String = Heli.KINDS[heli_kind()]["name"]
	if heli == null or not is_instance_valid(heli):
		return ["Buy a %s for this pad" % hk, "Rescue, patrol and resupply from the air"]
	var out := [heli.status_line()]
	out.append("Hull %d/%d  ·  mends on the pad" % [int(heli.hp), int(heli.max_hp)])
	return out

func card_buttons() -> Array:
	if state != BUILT:
		return super.card_buttons()
	if heli == null or not is_instance_valid(heli):
		var hk: String = Heli.KINDS[heli_kind()]["name"]
		var out := [["buy_heli", "BUY %s %d" % [hk.to_upper(), heli_cost()], G.main.supplies >= heli_cost()]]
		out.append(["move", "MOVE", true])
		return out
	var ready: bool = heli.ready_why() == ""
	var c: Dictionary = Heli.MISSION_COST
	return [
		["heli_rescue", "RESCUE %d" % c["rescue"], ready and G.people.stranded_count() > 0],
		["heli_patrol", "PATROL %d" % c["patrol"], ready],
		["heli_resupply", "RESUPPLY %d" % c["resupply"], ready],
	]
