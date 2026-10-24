class_name Fx
extends Node3D
const TRACER_SPEED := 140.0
var _tracers: Array[MeshInstance3D] = []
var _tracer_data: Array = []
var _tracer_i := 0
var _sparks: Array[CPUParticles3D] = []
var _spark_i := 0
var _puffs: Array[CPUParticles3D] = []
var _puff_i := 0
var _dusts: Array[CPUParticles3D] = []
var _dust_i := 0
var _dirts: Array[CPUParticles3D] = []
var _dirt_i := 0
var _chips: Array[CPUParticles3D] = []
var _chip_i := 0
var _booms: Array = []
var _boom_i := 0
var _debris: Array[CPUParticles3D] = []
var _debris_i := 0
var _decals: Array[MeshInstance3D] = []
var _decal_mats: Array[StandardMaterial3D] = []
var _decal_life := PackedFloat32Array()
var _decal_i := 0
var _light_t := PackedFloat32Array()
var _flashes: Array[MeshInstance3D] = []
var _flash_t := PackedFloat32Array()
var _flash_i := 0
var _shells: Array = []
var _shell_i := 0
var _burns: Array[CPUParticles3D] = []
var _burn_z: Array = []
var _fires: Array = []
var _fire_lights: Array[OmniLight3D] = []
var _smokes: Array = []
var _quad: QuadMesh
var _cube: BoxMesh

func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_cube = BoxMesh.new()
	_cube.size = Vector3(0.12, 0.12, 0.12)
	var tm := BoxMesh.new()
	tm.size = Vector3(0.05, 0.05, 1.0)
	for i in 64:
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = Art.mat_tracer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_tracers.append(mi)
		_tracer_data.append([Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0.0, 1.0, 2.2])
	for i in 10:
		_sparks.append(_ps(Art.mat_spark, 8, 0.28, _grad([Color(1, 0.95, 0.7, 1), Color(1, 0.6, 0.15, 1), Color(1, 0.3, 0.05, 0)]),
			3.5, 7.0, 0.05, 0.12, Vector3(0, -9.8, 0), 70.0))
	for i in 10:
		_puffs.append(_ps(Art.mat_blood_puff, 6, 0.4, _grad([Color(0.45, 0.03, 0.02, 0.75), Color(0.25, 0.02, 0.02, 0)]),
			0.8, 2.2, 0.1, 0.26, Vector3(0, -6.0, 0), 60.0))
	for i in 6:
		_dusts.append(_ps(Art.mat_dust, 14, 1.4, _grad([Color(0.62, 0.54, 0.42, 0.55), Color(0.55, 0.48, 0.38, 0)]),
			0.6, 2.0, 0.8, 1.8, Vector3(0, 0.3, 0), 80.0))
	for i in 6:
		var d := _ps(null, 6, 0.8, null, 2.0, 3.8, 0.6, 1.0, Vector3(0, -12.0, 0), 35.0)
		d.mesh = _cube
		d.material_override = Art.mat_vc
		d.color = Color(0.4, 0.3, 0.2)
		d.direction = Vector3(0, 1, 0)
		_dirts.append(d)
	for i in 6:
		var c := _ps(null, 5, 0.6, null, 1.5, 3.0, 0.4, 0.8, Vector3(0, -12.0, 0), 50.0)
		c.mesh = _cube
		c.material_override = Art.mat_vc
		c.color = Color(0.62, 0.55, 0.42)
		_chips.append(c)
	for i in 4:
		var d2 := _ps(null, 18, 1.4, null, 4.0, 9.0, 0.7, 1.6, Vector3(0, -14.0, 0), 70.0)
		d2.mesh = _cube
		d2.material_override = Art.mat_vc
		d2.color = Color(0.5, 0.45, 0.38)
		_debris.append(d2)
	for i in 4:
		var fire := _ps(Art.mat_fire, 22, 0.7, _grad([Color(1, 0.95, 0.75, 1), Color(1, 0.55, 0.12, 0.9), Color(0.6, 0.15, 0.05, 0)]),
			2.0, 7.0, 1.6, 3.2, Vector3(0, 2.0, 0), 180.0)
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 0.6
		var smoke := _ps(Art.mat_smoke, 16, 2.6, _grad([Color(0.2, 0.18, 0.16, 0.85), Color(0.35, 0.33, 0.3, 0.5), Color(0.4, 0.38, 0.35, 0)]),
			1.0, 3.5, 2.0, 4.5, Vector3(0, 1.2, 0), 120.0)
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.8
		var deb := _ps(null, 16, 1.3, null, 5.0, 11.0, 0.6, 1.4, Vector3(0, -16.0, 0), 60.0)
		deb.mesh = _cube
		deb.material_override = Art.mat_vc
		deb.color = Color(0.36, 0.27, 0.18)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.omni_range = 12.0
		light.light_energy = 0.0
		light.visible = false
		add_child(light)
		_booms.append([fire, smoke, deb, light])
	_light_t.resize(4)
	var fq := QuadMesh.new()
	fq.size = Vector2(0.55, 0.55)
	for i in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = fq
		mi.material_override = Art.mat_muzzle
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_flashes.append(mi)
	_flash_t.resize(14)
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.22
	sm.radial_segments = 8
	sm.rings = 4
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.32, 0.34, 0.3)
	shell_mat.metallic = 0.4
	shell_mat.roughness = 0.5
	for i in 8:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = shell_mat
		mi.visible = false
		add_child(mi)
		var trail := _ps(Art.mat_smoke, 24, 0.9, _grad([Color(0.85, 0.82, 0.78, 0.5), Color(0.6, 0.58, 0.55, 0)]),
			0.0, 0.3, 0.25, 0.55, Vector3(0, 0.4, 0), 180.0)
		trail.one_shot = false
		trail.explosiveness = 0.0
		_shells.append([mi, trail, Vector3.ZERO, Vector3.ZERO, 0.0, 1.0, 5.0, false])
	for i in 16:
		var b := _ps(Art.mat_fire, 10, 0.55, _grad([Color(1, 0.9, 0.5, 0.9), Color(1, 0.45, 0.1, 0.8), Color(0.3, 0.1, 0.05, 0)]),
			0.6, 1.4, 0.25, 0.6, Vector3(0, 2.5, 0), 25.0)
		b.one_shot = false
		b.explosiveness = 0.0
		b.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		b.emission_sphere_radius = 0.3
		_burns.append(b)
		_burn_z.append(null)
	for i in 14:
		var f := _ps(Art.mat_fire, 14, 0.75, _grad([Color(1, 0.88, 0.5, 0.95), Color(1, 0.45, 0.1, 0.85), Color(0.35, 0.12, 0.05, 0)]),
			0.4, 1.4, 0.45, 1.0, Vector3(0, 2.8, 0), 20.0)
		f.one_shot = false
		f.explosiveness = 0.0
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		f.emission_sphere_radius = 1.0
		_fires.append([f, Vector3.ZERO, 0.0, 1.0, 0.0])
	for i in 4:
		var fl := OmniLight3D.new()
		fl.light_color = Color(1.0, 0.55, 0.2)
		fl.omni_range = 9.0
		fl.light_energy = 0.0
		fl.visible = false
		add_child(fl)
		_fire_lights.append(fl)
	for i in 20:
		var smk := _ps(Art.mat_smoke, 10, 3.2, _grad([Color(0.16, 0.15, 0.14, 0.0), Color(0.2, 0.19, 0.18, 0.55), Color(0.35, 0.34, 0.32, 0)]),
			0.6, 1.4, 1.4, 3.2, Vector3(0.25, 1.1, 0.1), 18.0)
		smk.one_shot = false
		smk.explosiveness = 0.0
		smk.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smk.emission_sphere_radius = 0.6
		_smokes.append([smk, null, 0.0])
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	for i in 96:
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = Art.blood_tex
		m.roughness = 0.4
		m.disable_receive_shadows = false
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_decals.append(mi)
		_decal_mats.append(m)
	_decal_life.resize(96)

func _grad(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g

func _ps(mat: Material, amount: int, life: float, ramp: Gradient, v0: float, v1: float, s0: float, s1: float, grav: Vector3, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.mesh = _quad
	if mat:
		p.material_override = mat
	p.direction = Vector3(0, 1, 0)
	p.spread = spread
	p.gravity = grav
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	p.damping_min = 1.0
	p.damping_max = 2.0
	if ramp:
		p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _fire_ps(p: CPUParticles3D, pos: Vector3, dir: Vector3 = Vector3.UP) -> void:
	p.global_position = pos
	if dir != Vector3.UP and dir.length_squared() > 0.01:
		p.direction = dir
	p.restart()
	p.emitting = true

func tracer(from: Vector3, to: Vector3, style: int = 0) -> void:
	var d := to - from
	var l := d.length()
	if l < 0.5:
		return
	var i := _tracer_i
	_tracer_i = (_tracer_i + 1) % _tracers.size()
	var mi := _tracers[i]
	mi.visible = true
	var k := clampi(style, 0, 2)
	var w: float = [0.7, 1.0, 2.0][k]
	var seg: float = [1.6, 2.2, 6.0][k]
	var spd: float = [1.0, 1.0, 0.75][k]
	var fade: float = [0.04, 0.07, 0.2][k]
	_tracer_data[i] = [from, d / l, l, 0.0, l / (TRACER_SPEED * spd), w, seg, fade, k]
	mi.transparency = 0.0
	_place_tracer(i)

func _place_tracer(i: int) -> void:
	var td: Array = _tracer_data[i]
	var from: Vector3 = td[0]
	var dir: Vector3 = td[1]
	var l: float = td[2]
	var t: float = td[3]
	var w: float = td[5]
	var life: float = td[4]
	var seg := minf(float(td[6]), l)
	var head := l * clampf(t / maxf(life, 0.0001), 0.0, 1.0)
	var tail := maxf(0.0, head - seg)
	var mi := _tracers[i]
	if t > life:
		var f := clampf((t - life) / maxf(0.001, float(td[7])), 0.0, 1.0)
		mi.transparency = f
	var length := maxf(0.05, head - tail)
	var mid := from + dir * (tail + length * 0.5)
	mi.global_transform = tracer_xform(dir, mid, w, length)

static func tracer_xform(dir: Vector3, mid: Vector3, w: float, length: float) -> Transform3D:
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	return Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(w, w, length)), mid)

func tracer_head(i: int) -> Vector3:
	var mi := _tracers[i]
	var fwd := -mi.global_transform.basis.z
	return mi.global_position + fwd * 0.5

func hit(pos: Vector3, dir: Vector3, style: int = 0) -> void:
	if G.sfx:
		G.sfx.play("impact_flesh", pos)
	match style:
		0:
			if randf() < 0.5:
				var p := _sparks[_spark_i]
				_spark_i = (_spark_i + 1) % _sparks.size()
				p.direction = -dir + Vector3(0, 0.6, 0)
				_fire_ps(p, pos)
			if randf() < 0.5:
				blood_puff(pos)
		1:
			blood_puff(pos)
		_:
			blood_puff(pos)
			blood_puff(pos + dir * 0.4)
			if randf() < 0.7:
				blood(Vector3(pos.x + dir.x * 1.2, 0.02, pos.z + dir.z * 1.2), 0.7)

func gore(pos: Vector3) -> void:
	blood_puff(pos + Vector3(0, 0.8, 0))
	blood_puff(pos + Vector3(0, 0.4, 0))
	for k in 2:
		blood(Vector3(pos.x + randf_range(-1.2, 1.2), 0.02, pos.z + randf_range(-1.2, 1.2)), randf_range(0.8, 1.4))

func fire_patch(pos: Vector3, radius: float, time: float) -> void:
	var best := 0
	var least := INF
	for i in _fires.size():
		var t: float = _fires[i][2]
		if t <= 0.0:
			best = i
			break
		if t < least:
			least = t
			best = i
	var f: Array = _fires[best]
	var ps: CPUParticles3D = f[0]
	ps.global_position = Vector3(pos.x, G.grid.n_floor_y(pos) + 0.1 if G.grid else pos.y, pos.z)
	ps.emission_sphere_radius = radius * 0.7
	ps.amount = clampi(int(radius * 9.0), 8, 28)
	ps.emitting = true
	f[1] = pos
	f[2] = time
	f[3] = radius
	f[4] = 0.0

func smoke(pos: Vector3, time: float, size: float = 1.0) -> void:
	for sm in _smokes:
		if sm[1] == null and sm[2] <= 0.0:
			_start_smoke(sm, pos, size)
			sm[2] = time
			return

func smoke_attach(owner: Node, pos: Vector3, size: float = 1.0) -> void:
	for sm in _smokes:
		if sm[1] == owner:
			return
	for sm in _smokes:
		if sm[1] == null and sm[2] <= 0.0:
			_start_smoke(sm, pos, size)
			sm[1] = owner
			sm[2] = 1.0
			return

func smoke_detach(owner: Node) -> void:
	for sm in _smokes:
		if sm[1] == owner:
			sm[1] = null
			sm[2] = 0.0
			(sm[0] as CPUParticles3D).emitting = false

func _start_smoke(sm: Array, pos: Vector3, size: float) -> void:
	var ps: CPUParticles3D = sm[0]
	ps.global_position = pos
	ps.scale_amount_min = 1.2 * size
	ps.scale_amount_max = 3.0 * size
	ps.emission_sphere_radius = 0.5 * size
	ps.emitting = true

func blood_puff(pos: Vector3) -> void:
	var p := _puffs[_puff_i]
	_puff_i = (_puff_i + 1) % _puffs.size()
	_fire_ps(p, pos)

func dust(pos: Vector3, size: float = 1.0) -> void:
	var p := _dusts[_dust_i]
	_dust_i = (_dust_i + 1) % _dusts.size()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 * size
	p.scale_amount_min = 0.8 * size
	p.scale_amount_max = 1.8 * size
	_fire_ps(p, pos)

func dirt(pos: Vector3) -> void:
	var p := _dirts[_dirt_i]
	_dirt_i = (_dirt_i + 1) % _dirts.size()
	_fire_ps(p, pos)

func chips(pos: Vector3) -> void:
	var p := _chips[_chip_i]
	_chip_i = (_chip_i + 1) % _chips.size()
	_fire_ps(p, pos)

func debris(pos: Vector3, size: int = 1) -> void:
	var p := _debris[_debris_i]
	_debris_i = (_debris_i + 1) % _debris.size()
	_fire_ps(p, pos)

func explosion(pos: Vector3, size: float = 1.0) -> void:
	var i := _boom_i
	_boom_i = (_boom_i + 1) % _booms.size()
	var b: Array = _booms[i]
	for k in 3:
		var p: CPUParticles3D = b[k]
		p.scale_amount_min = [1.6, 2.0, 0.6][k] * size
		p.scale_amount_max = [3.2, 4.5, 1.4][k] * size
		_fire_ps(p, pos)
	var light: OmniLight3D = b[3]
	light.global_position = pos + Vector3(0, 1.5, 0)
	light.visible = true
	light.light_energy = 6.0 * size
	_light_t[i] = 0.35
	scorch(pos, 2.6 * size)
	smoke(Vector3(pos.x, maxf(pos.y, 0.5), pos.z), 3.0 + 2.5 * size, clampf(size, 0.6, 2.4))

func blood(pos: Vector3, size: float = 1.0) -> void:
	_decal(pos, Art.blood_tex, randf_range(1.2, 1.9) * size, 9.0)

func scorch(pos: Vector3, size: float) -> void:
	_decal(Vector3(pos.x, G.grid.floor_y(Defs.world_to_cell(pos)) + 0.025, pos.z), Art.scorch_tex, size, 14.0)

func _decal(pos: Vector3, tex: Texture2D, size: float, life: float) -> void:
	var i := _decal_i
	_decal_i = (_decal_i + 1) % _decals.size()
	var mi := _decals[i]
	var m := _decal_mats[i]
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, 1)
	mi.visible = true
	mi.global_transform = Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 0)).scaled(Vector3(size, 1, size)), pos + Vector3(0, 0.012 + i * 0.0002, 0))
	_decal_life[i] = life

func flash(pos: Vector3, size: float = 1.0) -> void:
	var i := _flash_i
	_flash_i = (_flash_i + 1) % _flashes.size()
	var mi := _flashes[i]
	mi.global_position = pos
	var s := size * randf_range(0.8, 1.2)
	mi.scale = Vector3(s, s, s)
	mi.visible = true
	_flash_t[i] = 0.05

func mortar_shell(from: Vector3, to: Vector3) -> float:
	var sh: Array = _shells[_shell_i]
	_shell_i = (_shell_i + 1) % _shells.size()
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	sh[2] = from
	sh[3] = to
	sh[4] = 0.0
	sh[5] = 1.3 + dist / 26.0
	sh[6] = 5.0 + dist * 0.35
	sh[7] = true
	var mi: MeshInstance3D = sh[0]
	mi.visible = true
	mi.global_position = from
	var trail: CPUParticles3D = sh[1]
	trail.global_position = from
	trail.emitting = true
	return sh[5]

func _land_shell(to: Vector3) -> void:
	if G.zombies:
		G.zombies.damage_radius(to, Defs.MORTAR_RADIUS, Defs.MORTAR_DAMAGE)
	explosion(to + Vector3(0, 0.2, 0), 0.75)
	if G.cam:
		G.cam.shake(0.3)
	if G.sfx:
		G.sfx.play("boom", to)

func make_flame_jet() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.material_override = Art.mat_fire
	p.amount = 46
	p.lifetime = 0.5
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3(0, 0, -1)
	p.spread = 9.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, 2.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(1.0, 2.6))
	p.scale_amount_curve = c
	p.color_ramp = _grad([Color(1, 0.78, 0.4, 0.9), Color(1, 0.48, 0.1, 0.85), Color(0.75, 0.2, 0.04, 0.5), Color(0.2, 0.15, 0.12, 0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func burn_attach(z) -> void:
	for i in _burns.size():
		if _burn_z[i] == z:
			return
	for i in _burns.size():
		if _burn_z[i] == null:
			_burn_z[i] = z
			_burns[i].global_position = z.position + Vector3(0, 1.0, 0)
			_burns[i].emitting = true
			return

func make_casings() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.014
	cm.bottom_radius = 0.014
	cm.height = 0.06
	cm.radial_segments = 5
	cm.rings = 1
	p.mesh = cm
	p.material_override = Art.mat_brass
	p.amount = 10
	p.lifetime = 0.9
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3(1, 0.8, 0.2)
	p.spread = 18.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -12.0, 0)
	p.angular_velocity_min = -600.0
	p.angular_velocity_max = 600.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func step(dt: float) -> void:
	for i in _flashes.size():
		if _flash_t[i] > 0.0:
			_flash_t[i] -= dt
			if _flash_t[i] <= 0.0:
				_flashes[i].visible = false
	for sh in _shells:
		if not sh[7]:
			continue
		sh[4] += dt
		var f: float = clampf(sh[4] / sh[5], 0.0, 1.0)
		var a: Vector3 = sh[2]
		var b: Vector3 = sh[3]
		var p := a.lerp(b, f) + Vector3(0, sh[6] * 4.0 * f * (1.0 - f), 0)
		var mi: MeshInstance3D = sh[0]
		var vel := (b - a) / maxf(0.001, float(sh[5])) + Vector3(0, sh[6] * 4.0 * (1.0 - 2.0 * f) / maxf(0.001, float(sh[5])), 0)
		if vel.length_squared() > 0.0001:
			var yv := vel.normalized()
			var xv := yv.cross(Vector3.FORWARD if absf(yv.z) < 0.9 else Vector3.RIGHT).normalized()
			var zv := xv.cross(yv).normalized()
			mi.global_transform = Transform3D(Basis(xv, yv, zv), p)
		else:
			mi.global_position = p
		var trail: CPUParticles3D = sh[1]
		trail.global_position = p
		if f >= 1.0:
			sh[7] = false
			mi.visible = false
			trail.emitting = false
			_land_shell(b)
	_step_fires(dt)
	for sm in _smokes:
		if sm[1] != null:
			if not is_instance_valid(sm[1]):
				sm[1] = null
				sm[2] = 0.0
				(sm[0] as CPUParticles3D).emitting = false
		elif sm[2] > 0.0:
			sm[2] -= dt
			if sm[2] <= 0.0:
				(sm[0] as CPUParticles3D).emitting = false
	for i in _burns.size():
		var z = _burn_z[i]
		if z == null:
			continue
		if not is_instance_valid(z) or not z.alive or z.burn_t <= 0.0:
			_burn_z[i] = null
			_burns[i].emitting = false
			continue
		_burns[i].global_position = z.position + Vector3(0, 0.9 * z.scale.y, 0)
	for i in _tracers.size():
		var mi := _tracers[i]
		if not mi.visible:
			continue
		var td: Array = _tracer_data[i]
		var was: float = td[3]
		td[3] += dt
		if was < float(td[4]) and float(td[3]) >= float(td[4]) and int(td[8]) == 2:
			blood_puff(Vector3(td[0]) + Vector3(td[1]) * float(td[2]))
		if td[3] >= float(td[4]) + float(td[7]):
			mi.visible = false
		else:
			_place_tracer(i)
	for i in _decals.size():
		if _decal_life[i] <= 0.0:
			continue
		_decal_life[i] -= dt
		if _decal_life[i] < 2.5:
			_decal_mats[i].albedo_color.a = maxf(0.0, _decal_life[i] / 2.5)
		if _decal_life[i] <= 0.0:
			_decals[i].visible = false
	for i in _booms.size():
		if _light_t[i] > 0.0:
			_light_t[i] -= dt
			var l: OmniLight3D = _booms[i][3]
			l.light_energy = maxf(0.0, _light_t[i] / 0.35) * 6.0
			if _light_t[i] <= 0.0:
				l.visible = false

func _step_fires(dt: float) -> void:
	var li := 0
	for f in _fires:
		if f[2] <= 0.0:
			continue
		f[2] -= dt
		var ps: CPUParticles3D = f[0]
		if f[2] <= 0.0:
			ps.emitting = false
			continue
		if li < _fire_lights.size():
			var l := _fire_lights[li]
			l.visible = true
			l.global_position = ps.global_position + Vector3(0, 1.2, 0)
			l.light_energy = (1.6 + randf() * 0.8) * clampf(f[2] / 1.5, 0.0, 1.0)
			li += 1
		f[4] -= dt
		if f[4] <= 0.0 and G.zombies:
			f[4] = 0.35
			G.zombies.ignite_radius(f[1], f[3])
	for k in range(li, _fire_lights.size()):
		_fire_lights[k].visible = false
