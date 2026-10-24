class_name Crafter
extends Person
enum {IDLE, GO, WORK}
var mode := IDLE
var shop = null
var home := Vector3.ZERO
var _t := 0.0
var _think := 0.0
var _tool_t := 0.0

func setup(at: Vector3) -> void:
	kind = "crafter"
	speed = 3.4
	position = at
	setup_model("worker", ["idle", "walk", "work"])
	_go_home()

func _go_home() -> void:
	if G.people:
		home = G.people.home_spot(self)
	walk_to(home, 1)

func release() -> void:
	shop = null
	mode = IDLE

func _on_flee() -> void:
	mode = IDLE

func _on_safe() -> void:
	_think = 0.0
	_go_home()

func step(dt: float) -> void:
	if dead:
		step_dead(dt)
		return
	_moving = false
	scan_threat(dt, 8.0)
	if flee_step(dt):
		settle(dt)
		animate(dt)
		return
	if shop != null and (not is_instance_valid(shop) or shop.state != Building.BUILT):
		shop = null
		mode = IDLE
		_go_home()
	match mode:
		IDLE:
			if not arrived():
				follow(dt)
			_think -= dt
			if _think <= 0.0:
				_think = 1.5
				var s = G.people.workshop_for(self)
				if s != null and walk_to_goals(s.access_goals()):
					shop = s
					mode = GO
		GO:
			if not arrived():
				follow(dt)
			else:
				mode = WORK
				_t = Defs.CRAFT_TIME
		WORK:
			face_point(shop.position)
			var can: bool = G.main.supplies >= Defs.CRATE_COST and G.logi.has_room()
			if can:
				_t -= dt
				_tool_t -= dt
				if _tool_t <= 0.0 and G.sfx:
					_tool_t = randf_range(0.6, 0.9)
					G.sfx.play("hammer", position)
				if _t <= 0.0:
					_t = Defs.CRAFT_TIME
					if G.main.spend(Defs.CRATE_COST):
						G.logi.add_crates(1, shop.position)
						G.logi.crafted += 1
	anim_mode = "work" if mode == WORK and G.main.supplies >= Defs.CRATE_COST else "idle"
	settle(dt)
	animate(dt)
