class_name WallEdit
extends RefCounted
var new_parts: Array = []
var old_parts: Array = []
var refund := true
var done := false

func add_new(p) -> void:
	new_parts.append(p)
	p.edit_group = self

func add_old(p) -> void:
	old_parts.append(p)
	p.replaced_by = self

func check() -> void:
	if done:
		return
	var alive := 0
	for p in new_parts:
		if not is_instance_valid(p) or p.state == Building.DEAD:
			continue
		alive += 1
		if p.state != Building.BUILT:
			return
	done = true
	if alive == 0:
		for o in old_parts:
			if is_instance_valid(o):
				o.replaced_by = null
		return
	for o in old_parts:
		if is_instance_valid(o) and o.state != Building.DEAD:
			G.walls.demolish(o, refund)
