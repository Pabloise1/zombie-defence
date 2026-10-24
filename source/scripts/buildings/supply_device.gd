class_name SupplyDevice
extends Building
var crates := 0

func store_cap() -> int:
	return int(def.get("store", 0)) if state == BUILT else 0

func card_lines() -> Array:
	if state != BUILT:
		return super.card_lines()
	match kind:
		"ammo_point":
			return ["Ammo crates %d/%d  ·  loaders fill it from the depot" % [crates, store_cap()]]
		"radio":
			return ["Calls in more survivors each wave"]
		"fuel":
			var n := 0
			for b in G.buildings.built_of("flame"):
				if b.position.distance_to(position) <= Defs.FUEL_RANGE:
					n += 1
			return ["Feeds flame bunkers within %d m (%d now)" % [int(Defs.FUEL_RANGE), n], "Explodes if destroyed"]
	return super.card_lines()

func _on_destroyed(effects: bool) -> void:
	if kind != "fuel" or not effects:
		return
	var p := position + Vector3(0, 0.6, 0)
	G.zombies.damage_radius(p, 5.0, 220.0)
	for b in G.buildings.list.duplicate():
		if is_instance_valid(b) and b != self and b.state == BUILT and b.has_health() and b.host == null:
			if b.edge_distance(p) < 4.0:
				b.take_damage(260.0)
	if G.fx:
		G.fx.explosion(p, 1.6)
		G.fx.fire_patch(position, 2.2, 8.0)
	if G.cam:
		G.cam.shake(0.8)
	if G.sfx:
		G.sfx.play("mine_explosion", p)
