extends Node
const MODEL_DIR := "res://art/models/"
const MODEL_KINDS := [
	"hq", "wall", "spike_trap", "mine", "turret_mg", "worker", "zombie_a", "zombie_b",
	"mortar_pit", "sniper_tower", "garrison_bunker", "soldier", "barbed_wire", "flame_bunker", "zombie_brute",
	"concrete_wall", "concrete_gate", "civilian_a", "civilian_b", "loader", "ammo_crate",
	"wall_post_wood", "wall_post_concrete",
	"house", "depot", "workshop", "barracks", "watchtower_concrete",
	"gun_platform", "wall_mount_nest", "wall_port_wood", "concrete_wall_port", "bastion_wood", "bastion_concrete",
	"ammo_point", "radio_mast", "fuel_tank", "salvage_wreck_a", "salvage_wreck_b", "scrap_bundle", "fetcher",
	"sniper_nest",
]
const C_CONCRETE := Color(0.58, 0.57, 0.53)
const C_CONCRETE_DK := Color(0.4, 0.4, 0.38)
const C_OLIVE := Color(0.33, 0.37, 0.18)
const C_OLIVE_LT := Color(0.45, 0.48, 0.27)
const C_SAND := Color(0.72, 0.63, 0.45)
const C_FABRIC := Color(0.7, 0.62, 0.45)
const C_WIRE := Color(0.24, 0.24, 0.22)
const C_DIRT := Color(0.4, 0.3, 0.2)
const C_METAL := Color(0.22, 0.23, 0.24)
const C_GUNMETAL := Color(0.3, 0.31, 0.32)
const C_WOOD := Color(0.42, 0.3, 0.18)
const C_WOOD_DK := Color(0.3, 0.21, 0.13)
const C_RUST := Color(0.48, 0.28, 0.16)
const C_DARK := Color(0.08, 0.08, 0.08)
var noise_tex: Texture2D
var grime_tex: Texture2D
var blob_tex: Texture2D
var blood_tex: Texture2D
var scorch_tex: Texture2D
var mat_vc: StandardMaterial3D
var mat_vc_metal: StandardMaterial3D
var mat_lamp: StandardMaterial3D
var mat_lamp_red: StandardMaterial3D
var mat_ghost_ok: ShaderMaterial
var mat_ghost_bad: ShaderMaterial
var mat_blueprint: ShaderMaterial
var mat_blueprint_faint: ShaderMaterial
var mat_flash: StandardMaterial3D
var mat_dig_mark: ShaderMaterial
var mat_spawn_arrow: ShaderMaterial
var mat_select: ShaderMaterial
var mat_ground: ShaderMaterial
var mat_dirt: ShaderMaterial
var mat_tracer: StandardMaterial3D
var mat_fire: StandardMaterial3D
var mat_smoke: StandardMaterial3D
var mat_spark: StandardMaterial3D
var mat_blood_puff: StandardMaterial3D
var mat_dust: StandardMaterial3D
var mat_muzzle: StandardMaterial3D
var mat_brass: StandardMaterial3D
var zmat_walk: ShaderMaterial
var zmat_attack: ShaderMaterial
var zmat_still: ShaderMaterial
var zmat_flash: ShaderMaterial
var _scenes := {}
var _meshes := {}
var present := {}

func _ready() -> void:
	_make_textures()
	_make_materials()
	for k in MODEL_KINDS:
		var p: String = MODEL_DIR + k + ".glb"
		if ResourceLoader.exists(p):
			var s = load(p)
			if s is PackedScene:
				_scenes[k] = s
				present[k] = true
				continue
		_scenes[k] = null

func has_model(kind: String) -> bool:
	_lazy(kind)
	return _scenes.get(kind) != null

func _lazy(kind: String) -> void:
	if _scenes.has(kind):
		return
	_scenes[kind] = null
	var p: String = MODEL_DIR + kind + ".glb"
	if ResourceLoader.exists(p):
		var sc = load(p)
		if sc is PackedScene:
			_scenes[kind] = sc
			present[kind] = true
var _mesh_info := {}

func mesh_info(kind: String) -> Dictionary:
	if _mesh_info.has(kind):
		return _mesh_info[kind]
	var root := model(kind)
	var out := {"mesh": null, "xf": Transform3D.IDENTITY}
	var mis := mesh_instances(root)
	if not mis.is_empty():
		var mi: MeshInstance3D = mis[0]
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var mesh: Mesh = mi.mesh
		if mi.material_override != null or mi.get_surface_override_material_count() > 0:
			var dup := mesh.duplicate() as Mesh
			for si in dup.get_surface_count():
				var m: Material = mi.get_active_material(si)
				if m:
					dup.surface_set_material(si, m)
			mesh = dup
		out = {"mesh": mesh, "xf": xf}
	root.free()
	_mesh_info[kind] = out
	return out
var _footprints := {}

func footprint(kind: String) -> Dictionary:
	if _footprints.has(kind):
		return _footprints[kind]
	var root := model(kind)
	var f := root.find_child("Footprint", true, false) as Node3D
	var out := {"off": Vector3.ZERO, "half": Vector2(1, 1), "found": f != null}
	if f:
		out = {"off": f.position, "half": Vector2(absf(f.scale.x), absf(f.scale.z)), "found": true}
	var marks := {}
	for n in root.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("Door") or nm.begins_with("Pump") or nm == "Lamp":
			marks[nm] = (n as Node3D).position
	out["marks"] = marks
	root.free()
	_footprints[kind] = out
	return out
var _surf := {}

func surface_mat(set_name: String, tile: float) -> ShaderMaterial:
	var key := "%s@%s" % [set_name, tile]
	if _surf.has(key):
		return _surf[key]
	var m := ShaderMaterial.new()
	m.shader = _surf_shader()
	var tex = load("res://art/models/suburb/textures/%s_albedo.png" % set_name)
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("half_size", Defs.HALF)
	m.set_shader_parameter("cell", Defs.CELL)
	m.set_shader_parameter("zone_tex", mat_ground.get_shader_parameter("zone_tex"))
	_surf[key] = m
	return m

func grid_materials() -> Array:
	var out: Array = [mat_ground]
	out.append_array(_surf.values())
	return out
var _surf_sh: Shader

func _surf_shader() -> Shader:
	if _surf_sh:
		return _surf_sh
	_surf_sh = Shader.new()
	_surf_sh.code = "\nshader_type spatial;\nrender_mode cull_back, diffuse_burley;\nuniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;\nuniform float tile = 4.0;\nuniform float grid_alpha = 0.0;\nuniform float half_size = 97.0;\nuniform float cell = 2.0;\nuniform sampler2D zone_tex : filter_linear, repeat_disable;\nuniform float zone_on = 1.0;\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tvec3 col = texture(albedo_tex, UV / tile).rgb;\n\tvec2 p = wp.xz;\n\tvec2 gp = (p + vec2(half_size)) / cell;\n\tvec2 f = abs(fract(gp) - 0.5);\n\tvec2 w = fwidth(gp) * 1.2;\n\tfloat line = max(smoothstep(0.5 - w.x, 0.5, f.x), smoothstep(0.5 - w.y, 0.5, f.y));\n\tcol = mix(col, vec3(0.95, 0.92, 0.80), line * grid_alpha * 0.4);\n\tvec2 zuv = (p + vec2(half_size)) / (half_size * 2.0);\n\tfloat zm = texture(zone_tex, zuv).r * zone_on;\n\tfloat tint = smoothstep(0.35, 0.65, zm);\n\tcol = mix(col, col * vec3(0.8, 1.1, 0.82), tint * 0.5);\n\tfloat edge_line = 1.0 - smoothstep(0.0, 0.12, abs(zm - 0.5));\n\tcol = mix(col, vec3(0.55, 0.95, 0.55), edge_line * 0.5 * step(0.02, zm));\n\tALBEDO = col;\n\tROUGHNESS = 0.92;\n\tSPECULAR = 0.25;\n}\n"
	return _surf_sh

func use_lawn(on: bool) -> void:
	mat_ground.set_shader_parameter("lawn_on", 1.0 if on else 0.0)
	if on:
		mat_ground.set_shader_parameter("lawn_tex", load("res://art/models/suburb/textures/lawn_albedo.png"))

func present_list() -> Array:
	var out := []
	for k in MODEL_KINDS:
		if present.has(k):
			out.append(k)
	return out

func model(kind: String) -> Node3D:
	_lazy(kind)
	var s: PackedScene = _scenes.get(kind)
	if s != null:
		var n := s.instantiate()
		if n is Node3D:
			_prepare_imported(n)
			return n
		n.free()
	return _placeholder(kind)

func _prepare_imported(root: Node) -> void:
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		for an in player.get_animation_list():
			var a := player.get_animation(an)
			var low := String(an).to_lower()
			if low.contains("walk") or low.contains("idle") or low.contains("work") or low.contains("run") or low.contains("attack") or low.contains("aim") or low.contains("fire") or low.contains("carry") or low.contains("cower"):
				a.loop_mode = Animation.LOOP_LINEAR
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func find_anim(player: AnimationPlayer, want: String) -> String:
	if player == null:
		return ""
	if player.has_animation(want):
		return want
	for an in player.get_animation_list():
		var s := String(an)
		if s.to_lower().ends_with(want) or s.to_lower().contains(want):
			return s
	return ""

static func mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out

static func model_height(root: Node) -> float:
	var top := 0.0
	var bottom := 0.0
	var first := true
	for mi in mesh_instances(root):
		if mi.mesh == null:
			continue
		var a: AABB = mi.mesh.get_aabb()
		var lo := a.position.y
		var hi := a.end.y
		if first or hi > top:
			top = hi
		if first or lo < bottom:
			bottom = lo
		first = false
	return maxf(0.1, top - bottom)

static func set_override(root: Node, mat: Material) -> void:
	for mi in mesh_instances(root):
		mi.material_override = mat

static func set_shadows(root: Node, on: bool) -> void:
	for mi in mesh_instances(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_textures() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 7
	n.frequency = 0.018
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 5
	var img := n.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	noise_tex = ImageTexture.create_from_image(img)
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.seed = 11
	n2.frequency = 0.06
	n2.fractal_type = FastNoiseLite.FRACTAL_FBM
	n2.fractal_octaves = 3
	var g := n2.get_seamless_image(128, 128)
	g.convert(Image.FORMAT_RGBA8)
	for y in g.get_height():
		for x in g.get_width():
			var v := g.get_pixel(x, y).r
			var m := 0.72 + 0.28 * v
			g.set_pixel(x, y, Color(m, m, m, 1.0))
	g.generate_mipmaps()
	grime_tex = ImageTexture.create_from_image(g)
	blob_tex = _radial_tex(64, 1.6)
	blood_tex = _splat_tex(64, 4242, Color(0.35, 0.02, 0.02), 10)
	scorch_tex = _splat_tex(64, 99, Color(0.05, 0.04, 0.03), 7)

func _radial_tex(size: int, power: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - h, y + 0.5 - h).length() / h
			var a := pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _splat_tex(size: int, sd: int, col: Color, blobs: int) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var cs: Array[Vector3] = []
	cs.append(Vector3(0.5, 0.5, 0.26))
	for i in blobs:
		var ang := r.randf() * TAU
		var dd := r.randf_range(0.12, 0.36)
		cs.append(Vector3(0.5 + cos(ang) * dd, 0.5 + sin(ang) * dd, r.randf_range(0.03, 0.12)))
	var nz := FastNoiseLite.new()
	nz.seed = sd
	nz.frequency = 0.15
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size
			var v := (y + 0.5) / size
			var a := 0.0
			for c in cs:
				var d := Vector2(u - c.x, v - c.y).length()
				a = maxf(a, 1.0 - d / c.z)
			a += nz.get_noise_2d(x, y) * 0.35
			a = smoothstep(0.0, 0.25, a)
			var edge := 1.0 - a * 0.35
			img.set_pixel(x, y, Color(col.r * edge, col.g * edge, col.b * edge, a * 0.92))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
var _dmg_mats: Array = []
var _scaffolds := {}

func damage_mat(stage: int) -> ShaderMaterial:
	if _dmg_mats.is_empty():
		var sh := Shader.new()
		sh.code = "\nshader_type spatial;\nrender_mode blend_mix, depth_draw_never, cull_back, specular_disabled;\nuniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;\nuniform float amount = 0.5;\nvarying vec3 wp;\nvarying vec3 wn;\nvoid vertex() {\n\twp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\twn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);\n}\nfloat tri(vec3 p, vec3 n, float sc) {\n\tvec3 b = abs(n);\n\tb /= (b.x + b.y + b.z + 0.0001);\n\treturn texture(noise_tex, p.yz * sc).r * b.x + texture(noise_tex, p.xz * sc).r * b.y + texture(noise_tex, p.xy * sc).r * b.z;\n}\nvoid fragment() {\n\tfloat n1 = tri(wp, wn, 0.33);\n\tfloat n2 = tri(wp + vec3(13.1, 7.7, 3.3), wn, 0.8);\n\tfloat crack = 1.0 - smoothstep(0.0, 0.04 + 0.04 * amount, abs(n1 - 0.5));\n\tcrack *= step(0.55 - amount * 0.5, n2);\n\tfloat soot = smoothstep(0.58 - amount * 0.28, 0.7 - amount * 0.22, n2) * (0.35 + amount * 0.65);\n\tfloat holes = smoothstep(0.74 - amount * 0.12, 0.77 - amount * 0.12, tri(wp + vec3(5.3, 1.1, 9.9), wn, 0.5)) * step(0.66, amount);\n\tfloat a = max(max(crack * (0.65 + amount * 0.35), soot * 0.8), holes);\n\tALBEDO = mix(vec3(0.07, 0.06, 0.05), vec3(0.008), holes);\n\tROUGHNESS = 1.0;\n\tALPHA = clamp(a, 0.0, 0.95);\n}\n"
		for amt in [0.45, 0.75, 1.0]:
			var m := ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter("noise_tex", noise_tex)
			m.set_shader_parameter("amount", amt)
			m.render_priority = 1
			_dmg_mats.append(m)
	return _dmg_mats[clampi(stage, 1, 3) - 1]

static func set_overlay(root: Node, mat: Material) -> void:
	for mi in mesh_instances(root):
		mi.material_overlay = mat

func scaffold_mesh(w: float, d: float, h: float) -> ArrayMesh:
	var key := "%.1f_%.1f_%.1f" % [snappedf(w, 0.5), snappedf(d, 0.5), snappedf(h, 0.5)]
	if _scaffolds.has(key):
		return _scaffolds[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pole := Color(0.55, 0.42, 0.26)
	var rail := Color(0.62, 0.5, 0.32)
	var hw := w * 0.5 + 0.35
	var hd := d * 0.5 + 0.35
	var poles: Array = []
	var nx := maxi(1, int(ceil(w / 2.5)))
	var nz := maxi(1, int(ceil(d / 2.5)))
	for i in nx + 1:
		var x := -hw + 2.0 * hw * i / nx
		poles.append(Vector2(x, -hd))
		poles.append(Vector2(x, hd))
	for j in range(1, nz):
		var z := -hd + 2.0 * hd * j / nz
		poles.append(Vector2(-hw, z))
		poles.append(Vector2(hw, z))
	for p in poles:
		_box(st, Vector3(p.x, h * 0.5, p.y), Vector3(0.09, h, 0.09), pole)
	var levels := maxi(1, int(h / 1.3))
	for k in levels:
		var y := h * float(k + 1) / levels - 0.05
		_box(st, Vector3(0, y, -hd), Vector3(hw * 2.0, 0.06, 0.06), rail)
		_box(st, Vector3(0, y, hd), Vector3(hw * 2.0, 0.06, 0.06), rail)
		_box(st, Vector3(-hw, y, 0), Vector3(0.06, 0.06, hd * 2.0), rail)
		_box(st, Vector3(hw, y, 0), Vector3(0.06, 0.06, hd * 2.0), rail)
		_box(st, Vector3(0, y - 0.08, -hd + 0.25), Vector3(hw * 2.0, 0.04, 0.42), pole)
		_box(st, Vector3(0, y - 0.08, hd - 0.25), Vector3(hw * 2.0, 0.04, 0.42), pole)
	st.generate_normals()
	var m := st.commit()
	_scaffolds[key] = m
	return m

func _box(st: SurfaceTool, c: Vector3, sz: Vector3, col: Color) -> void:
	var h := sz * 0.5
	var v := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
	st.set_color(col)
	for f in faces:
		st.add_vertex(v[f[0]])
		st.add_vertex(v[f[1]])
		st.add_vertex(v[f[2]])
		st.add_vertex(v[f[0]])
		st.add_vertex(v[f[2]])
		st.add_vertex(v[f[3]])
var _rubble_mats := {}
var _chunk: BoxMesh

func rubble_mat(hard: bool, hedge: bool = false) -> StandardMaterial3D:
	var key := "h" if hedge else ("c" if hard else "w")
	if not _rubble_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.24, 0.3, 0.14) if hedge else (Color(0.42, 0.41, 0.39) if hard else Color(0.3, 0.22, 0.15))
		m.albedo_texture = grime_tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(1.4, 1.4, 1.4)
		m.roughness = 0.95
		_rubble_mats[key] = m
	return _rubble_mats[key]

func rubble_chunk() -> BoxMesh:
	if _chunk == null:
		_chunk = BoxMesh.new()
		_chunk.size = Vector3.ONE
	return _chunk

func _std(col: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

func _particle_mat(col: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.albedo_texture = blob_tex
	m.disable_receive_shadows = true
	return m

func _make_materials() -> void:
	mat_vc = StandardMaterial3D.new()
	mat_vc.vertex_color_use_as_albedo = true
	mat_vc.vertex_color_is_srgb = true
	mat_vc.albedo_texture = grime_tex
	mat_vc.uv1_triplanar = true
	mat_vc.uv1_world_triplanar = true
	mat_vc.uv1_scale = Vector3(0.6, 0.6, 0.6)
	mat_vc.roughness = 0.88
	mat_vc_metal = mat_vc.duplicate()
	mat_vc_metal.metallic = 0.55
	mat_vc_metal.roughness = 0.45
	mat_lamp = StandardMaterial3D.new()
	mat_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_lamp.albedo_color = Color(1.0, 0.82, 0.45)
	mat_lamp_red = StandardMaterial3D.new()
	mat_lamp_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_lamp_red.albedo_color = Color(1.0, 0.15, 0.1)
	mat_ghost_ok = _ghost(Color(0.35, 1.0, 0.55, 0.38))
	mat_ghost_bad = _ghost(Color(1.0, 0.25, 0.2, 0.38))
	var bp := Shader.new()
	bp.code = "\nshader_type spatial;\nrender_mode unshaded, cull_back, depth_draw_never, blend_mix;\nuniform vec4 tint : source_color = vec4(0.35, 0.85, 1.0, 0.3);\nuniform float rim_k = 0.45;\nuniform float stripe_k = 0.12;\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tfloat rim = 1.0 - abs(dot(NORMAL, VIEW));\n\tfloat sl = step(0.55, fract(wp.y * 5.0 - TIME * 0.8));\n\tALBEDO = tint.rgb + vec3(rim * 0.35);\n\tALPHA = clamp(tint.a + sl * stripe_k + rim * rim_k, 0.0, 0.85);\n}\n"
	mat_blueprint = ShaderMaterial.new()
	mat_blueprint.shader = bp
	mat_blueprint_faint = ShaderMaterial.new()
	mat_blueprint_faint.shader = bp
	mat_blueprint_faint.set_shader_parameter("tint", Color(0.35, 0.85, 1.0, 0.05))
	mat_blueprint_faint.set_shader_parameter("rim_k", 0.22)
	mat_blueprint_faint.set_shader_parameter("stripe_k", 0.04)
	mat_flash = StandardMaterial3D.new()
	mat_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flash.albedo_color = Color(1.0, 0.92, 0.85)
	var dm := Shader.new()
	dm.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;\nuniform vec4 tint : source_color = vec4(1.0, 0.62, 0.15, 0.9);\nuniform float progress = 0.0;\nvoid fragment() {\n\tvec2 q = abs(UV - 0.5) * 2.0;\n\tfloat edge = max(q.x, q.y);\n\tfloat border = smoothstep(0.80, 0.84, edge) * (1.0 - smoothstep(0.96, 1.0, edge));\n\tfloat along = (q.x > q.y) ? UV.y : UV.x;\n\tfloat dash = step(0.5, fract(along * 4.0 - TIME * 0.6));\n\tfloat fill = 0.10 + 0.08 * sin(TIME * 3.0);\n\tALBEDO = tint.rgb;\n\tALPHA = max(border * dash * tint.a, fill * step(edge, 0.84));\n}\n"
	mat_dig_mark = ShaderMaterial.new()
	mat_dig_mark.shader = dm
	var sa := Shader.new()
	sa.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;\nuniform vec4 tint : source_color = vec4(1.0, 0.18, 0.1, 1.0);\nvoid fragment() {\n\t// Chevrons pointing toward -V (inward), scrolling.\n\tvec2 uv = UV;\n\tfloat x = abs(uv.x - 0.5) * 2.0;\n\tfloat y = uv.y + x * 0.35;\n\tfloat band = fract(y * 3.0 + TIME * 1.2);\n\tfloat chev = smoothstep(0.0, 0.08, band) * (1.0 - smoothstep(0.38, 0.46, band));\n\tfloat fade = (1.0 - x) * smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.7, uv.y);\n\tALBEDO = tint.rgb * chev * fade * (0.6 + 0.4 * sin(TIME * 4.0));\n}\n"
	mat_spawn_arrow = ShaderMaterial.new()
	mat_spawn_arrow.shader = sa
	var rs := Shader.new()
	rs.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;\nuniform vec4 tint : source_color = vec4(0.97, 0.65, 0.22, 1.0);\nvoid fragment() {\n\tvec2 q = abs(UV - 0.5) * 2.0;\n\tfloat e = max(q.x, q.y);\n\tfloat band = smoothstep(0.78, 0.84, e) * (1.0 - smoothstep(0.94, 1.0, e));\n\tfloat corner = step(0.55, min(q.x, q.y));\n\tfloat pulse = 0.65 + 0.35 * sin(TIME * 5.0);\n\tALBEDO = tint.rgb;\n\tALPHA = band * mix(0.35, 1.0, corner) * pulse;\n}\n"
	mat_select = ShaderMaterial.new()
	mat_select.shader = rs
	var gs := Shader.new()
	gs.code = "\nshader_type spatial;\nrender_mode cull_back, diffuse_burley;\nuniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;\nuniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;\nuniform vec3 grass_a : source_color = vec3(0.25, 0.30, 0.13);\nuniform vec3 grass_b : source_color = vec3(0.35, 0.37, 0.17);\nuniform vec3 dry : source_color = vec3(0.52, 0.46, 0.28);\nuniform vec3 dirt : source_color = vec3(0.34, 0.26, 0.17);\nuniform float grid_alpha = 0.0;\nuniform float half_size = 49.0;\nuniform float cell = 2.0;\nuniform sampler2D zone_tex : filter_linear, repeat_disable;\nuniform float zone_on = 1.0;\nuniform sampler2D lawn_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;\nuniform float lawn_on = 0.0;\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tvec2 p = wp.xz;\n\tfloat n1 = texture(noise_tex, p * 0.0065).r;\n\tfloat n2 = texture(noise_tex, p * 0.031 + vec2(0.37, 0.11)).r;\n\tfloat n3 = texture(noise_tex, p * 0.11 + vec2(0.7, 0.2)).r;\n\tfloat g = texture(grime_tex, p * 0.21).r;\n\tvec3 col = mix(grass_a, grass_b, smoothstep(0.35, 0.65, n1));\n\tcol = mix(col, dry, smoothstep(0.58, 0.8, n2) * 0.55);\n\tif (lawn_on > 0.5) {\n\t\tvec3 lawn = texture(lawn_tex, p / 4.0).rgb;\n\t\t// Large-scale straw tint and a second, rotated lookup break the repeat.\n\t\tvec3 lawn2 = texture(lawn_tex, vec2(p.x * 0.6 - p.y * 0.8, p.x * 0.8 + p.y * 0.6) / 5.3).rgb;\n\t\tlawn = mix(lawn, lawn2, 0.35);\n\t\tlawn = mix(lawn, lawn * vec3(1.18, 1.06, 0.72), smoothstep(0.4, 0.75, n1) * 0.7);\n\t\tcol = mix(lawn, lawn * 0.85, smoothstep(0.55, 0.85, n2) * 0.4);\n\t}\n\tfloat worn = smoothstep(0.72, 0.88, n1 * 0.5 + n3 * 0.6) * 0.6;\n\t// Trampled earth around the HQ.\n\tfloat hq = 1.0 - smoothstep(5.0, 13.0, length(p));\n\tcol = mix(col, dirt, clamp(worn + hq * 0.85, 0.0, 1.0));\n\tcol *= 0.78 + 0.32 * g;\n\tcol *= 0.92 + 0.16 * n3;\n\t// Outside the play area the ground darkens a touch.\n\tfloat outside = max(abs(p.x), abs(p.y)) - half_size;\n\tcol *= 1.0 - smoothstep(0.0, 6.0, outside) * 0.18;\n\t// Build grid.\n\tvec2 gp = (p + vec2(half_size)) / cell;\n\tvec2 f = abs(fract(gp) - 0.5);\n\tvec2 w = fwidth(gp) * 1.2;\n\tfloat line = max(smoothstep(0.5 - w.x, 0.5, f.x), smoothstep(0.5 - w.y, 0.5, f.y));\n\tfloat inside = 1.0 - step(0.0, outside);\n\tcol = mix(col, vec3(0.95, 0.92, 0.80), line * grid_alpha * 0.45 * inside);\n\t// Safe zones: green tint and a soft border line.\n\tvec2 zuv = (p + vec2(half_size)) / (half_size * 2.0);\n\tfloat zm = texture(zone_tex, zuv).r * zone_on;\n\tfloat tint = smoothstep(0.35, 0.65, zm);\n\tcol = mix(col, col * vec3(0.78, 1.12, 0.8) + vec3(0.0, 0.03, 0.0), tint * 0.6);\n\tfloat edge_line = 1.0 - smoothstep(0.0, 0.12, abs(zm - 0.5));\n\tcol = mix(col, vec3(0.55, 0.95, 0.55), edge_line * 0.55 * step(0.02, zm));\n\t// Border line of the play area.\n\tfloat b = smoothstep(0.35, 0.0, abs(outside)) * 0.5;\n\tcol = mix(col, vec3(0.75, 0.25, 0.12), b);\n\tALBEDO = col;\n\tROUGHNESS = 0.96;\n\tSPECULAR = 0.2;\n}\n"
	mat_ground = ShaderMaterial.new()
	mat_ground.shader = gs
	mat_ground.set_shader_parameter("noise_tex", noise_tex)
	mat_ground.set_shader_parameter("grime_tex", grime_tex)
	mat_ground.set_shader_parameter("half_size", Defs.HALF)
	mat_ground.set_shader_parameter("cell", Defs.CELL)
	var ds := Shader.new()
	ds.code = "\nshader_type spatial;\nrender_mode cull_back, diffuse_burley;\nuniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;\nuniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;\nuniform vec3 dirt_top : source_color = vec3(0.33, 0.25, 0.17);\nuniform vec3 dirt_low : source_color = vec3(0.15, 0.11, 0.075);\nuniform vec3 mud : source_color = vec3(0.17, 0.13, 0.09);\nvarying vec3 wp;\nvarying vec3 wn;\nvoid vertex() {\n\twp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\twn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);\n}\nvoid fragment() {\n\tvec2 uv = abs(wn.y) > 0.5 ? wp.xz : vec2(wp.x + wp.z, wp.y * 1.6);\n\tfloat n = texture(noise_tex, uv * 0.09).r;\n\tfloat g = texture(grime_tex, uv * 0.35).r;\n\tfloat depth = clamp(-wp.y / 1.5, 0.0, 1.0);\n\tvec3 col = mix(dirt_top, dirt_low, pow(depth, 0.7));\n\t// Fresh-cut lip along the top edge.\n\tcol = mix(col, dirt_top * 1.35, smoothstep(0.12, 0.0, depth) * step(wn.y, 0.5));\n\tif (wn.y > 0.5) { col = mix(mud, dirt_low, n); }\n\t// Strata bands on the walls.\n\tfloat strata = sin(wp.y * 9.0 + n * 6.0) * 0.5 + 0.5;\n\tcol *= 0.85 + 0.2 * strata * (1.0 - step(0.5, wn.y));\n\tcol *= 0.75 + 0.35 * g;\n\tALBEDO = col;\n\tROUGHNESS = 0.98;\n\tSPECULAR = 0.15;\n}\n"
	mat_dirt = ShaderMaterial.new()
	mat_dirt.shader = ds
	mat_dirt.set_shader_parameter("noise_tex", noise_tex)
	mat_dirt.set_shader_parameter("grime_tex", grime_tex)
	mat_tracer = StandardMaterial3D.new()
	mat_tracer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_tracer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_tracer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_tracer.albedo_color = Color(1.0, 0.78, 0.35, 0.95)
	mat_tracer.disable_receive_shadows = true
	mat_fire = _particle_mat(Color(1, 1, 1, 1), true)
	mat_smoke = _particle_mat(Color(1, 1, 1, 1), false)
	mat_spark = _particle_mat(Color(1, 1, 1, 1), true)
	mat_blood_puff = _particle_mat(Color(1, 1, 1, 1), false)
	mat_dust = _particle_mat(Color(1, 1, 1, 1), false)
	mat_muzzle = StandardMaterial3D.new()
	mat_muzzle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_muzzle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_muzzle.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_muzzle.albedo_color = Color(1.0, 0.75, 0.35, 1.0)
	mat_muzzle.albedo_texture = blob_tex
	mat_muzzle.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_muzzle.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_muzzle.billboard_keep_scale = true
	mat_muzzle.disable_receive_shadows = true
	mat_brass = _std(Color(0.86, 0.66, 0.28), 0.35)
	mat_brass.metallic = 0.8
	var zs := Shader.new()
	zs.code = "\nshader_type spatial;\nrender_mode cull_back, diffuse_burley;\nuniform float mode = 0.0;   // 0 walk, 1 attack/climb, 2 still\nuniform float flash = 0.0;\nuniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;\nvarying vec3 wp;\nvoid vertex() {\n\tfloat s = length(MODEL_MATRIX[0].xyz);\n\tfloat seed = fract(s * 7919.0);\n\tfloat rate = mode > 0.5 ? 7.5 : (4.0 + seed * 2.5);\n\tfloat t = TIME * rate + seed * 6.2831;\n\tfloat tag = COLOR.a;\n\tfloat ang = 0.0;\n\tvec3 pv = vec3(0.0, 0.88, 0.0);\n\tif (tag > 0.1 && tag < 0.3) { ang = sin(t) * 0.5; }\n\telse if (tag > 0.3 && tag < 0.5) { ang = -sin(t) * 0.5; }\n\telse if (tag > 0.5 && tag < 0.7) { pv = vec3(0.0, 1.45, -0.08); ang = mode > 0.5 ? (sin(t) * 0.55 + 0.25) : sin(t + 1.3) * 0.12; }\n\telse if (tag > 0.7 && tag < 0.9) { pv = vec3(0.0, 1.45, -0.08); ang = mode > 0.5 ? (sin(t + 2.6) * 0.55 + 0.25) : -sin(t + 1.3) * 0.12; }\n\tif (mode > 0.5 && tag < 0.5) { ang *= 0.15; }\n\tif (mode > 1.5) { ang = 0.0; }\n\tfloat c = cos(ang);\n\tfloat sn = sin(ang);\n\tvec3 v = VERTEX - pv;\n\tVERTEX = pv + vec3(v.x, v.y * c - v.z * sn, v.y * sn + v.z * c);\n\tNORMAL = vec3(NORMAL.x, NORMAL.y * c - NORMAL.z * sn, NORMAL.y * sn + NORMAL.z * c);\n\twp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tCOLOR.a = 1.0;\n}\nvoid fragment() {\n\tvec3 base = pow(COLOR.rgb, vec3(2.2));\n\tfloat g = texture(grime_tex, wp.xz * 1.3 + vec2(wp.y * 0.9)).r;\n\tALBEDO = mix(base * (0.7 + 0.45 * g), vec3(1.0, 0.92, 0.85), flash);\n\tEMISSION = vec3(flash * 0.6, flash * 0.5, flash * 0.45);\n\tROUGHNESS = 0.85;\n}\n"
	zmat_walk = _zmat(zs, 0.0, 0.0)
	zmat_attack = _zmat(zs, 1.0, 0.0)
	zmat_still = _zmat(zs, 2.0, 0.0)
	zmat_flash = _zmat(zs, 0.0, 1.0)

func _zmat(sh: Shader, mode: float, flash: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("grime_tex", grime_tex)
	return m

func _ghost(col: Color) -> ShaderMaterial:
	var s := Shader.new()
	s.code = "\nshader_type spatial;\nrender_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;\nuniform vec4 tint : source_color;\nvoid fragment() {\n\tfloat rim = 1.0 - abs(dot(NORMAL, VIEW));\n\tALBEDO = tint.rgb + vec3(rim * 0.25);\n\tALPHA = clamp(tint.a + rim * 0.4, 0.0, 0.9);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = s
	m.set_shader_parameter("tint", col)
	return m

func _mi(mesh: Mesh, mat: Material, parent: Node3D, name_: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = null
	mi.set_surface_override_material(0, mat)
	if name_ != "":
		mi.name = name_
	parent.add_child(mi)
	return mi

func _cached(key: String, f: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = f.call()
	return _meshes[key]

func _placeholder(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	match kind:
		"hq":
			_mi(_cached("hq", _mesh_hq), mat_vc, root, "Body")
			var dish := Node3D.new()
			dish.name = "Radar"
			dish.position = Vector3(-1.5, 2.75, 1.5)
			root.add_child(dish)
			_mi(_cached("hq_dish", _mesh_hq_dish), mat_vc_metal, dish)
			var lamp := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.09
			lm.height = 0.18
			lamp.mesh = lm
			lamp.set_surface_override_material(0, mat_lamp)
			lamp.position = Vector3(0, 2.0, -2.45)
			root.add_child(lamp)
		"wall":
			_mi(_cached("wall", _mesh_wall), mat_vc, root, "Body")
		"turret_mg":
			_mi(_cached("turret_base", _mesh_turret_base), mat_vc, root, "Base")
			var yaw := Node3D.new()
			yaw.name = "Yaw"
			yaw.position = Vector3(0, 0.95, 0)
			root.add_child(yaw)
			_mi(_cached("turret_yaw", _mesh_turret_yaw), mat_vc_metal, yaw)
			var barrel := Node3D.new()
			barrel.name = "Barrel"
			barrel.position = Vector3(0, 0.05, -0.35)
			yaw.add_child(barrel)
			_mi(_cached("turret_barrel", _mesh_turret_barrel), mat_vc_metal, barrel)
			var muzzle := Marker3D.new()
			muzzle.name = "Muzzle"
			muzzle.position = Vector3(0, 0, -1.12)
			barrel.add_child(muzzle)
		"spike_trap":
			_mi(_cached("spike_base", _mesh_spike_base), mat_vc, root, "Base")
			var sp := Node3D.new()
			sp.name = "Spikes"
			root.add_child(sp)
			_mi(_cached("spike_spikes", _mesh_spike_spikes), mat_vc_metal, sp)
		"mine":
			_mi(_cached("mine", _mesh_mine), mat_vc, root, "Body")
			var lamp := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.045
			lm.height = 0.09
			lamp.mesh = lm
			lamp.set_surface_override_material(0, mat_lamp_red)
			lamp.position = Vector3(0.12, 0.2, 0.0)
			lamp.name = "Light"
			root.add_child(lamp)
		"worker":
			_build_worker(root)
		"zombie_a":
			_mi(_cached("zombie_a", _mesh_zombie_a), zmat_walk, root, "Body")
		"zombie_b":
			_mi(_cached("zombie_b", _mesh_zombie_b), zmat_walk, root, "Body")
		"zombie_brute":
			_mi(_cached("zombie_brute", _mesh_zombie_brute), zmat_walk, root, "Body")
		"soldier":
			_build_soldier(root)
		"mortar_pit":
			_mi(_cached("mortar_base", _mesh_mortar_base), mat_vc, root, "Base")
			var myaw := Node3D.new()
			myaw.name = "Yaw"
			myaw.position = Vector3(0, 0.22, 0)
			root.add_child(myaw)
			_mi(_cached("mortar_yaw", _mesh_mortar_yaw), mat_vc_metal, myaw)
			var tube := Node3D.new()
			tube.name = "Tube"
			tube.position = Vector3(0, 0.12, 0.12)
			tube.rotation.x = deg_to_rad(58.0)
			myaw.add_child(tube)
			_mi(_cached("mortar_tube", _mesh_mortar_tube), mat_vc_metal, tube)
			var mm := Marker3D.new()
			mm.name = "Muzzle"
			mm.position = Vector3(0, 0, -1.05)
			tube.add_child(mm)
		"sniper_tower":
			_mi(_cached("sniper_tower", _mesh_sniper_tower), mat_vc, root, "Body")
			var perch := Marker3D.new()
			perch.name = "Perch"
			perch.position = Vector3(0, 4.28, -0.2)
			root.add_child(perch)
		"garrison_bunker":
			_mi(_cached("garrison", _mesh_garrison), mat_vc, root, "Body")
			for i in 4:
				var a := PI * 0.25 + i * PI * 0.5 + PI
				var sm := Marker3D.new()
				sm.name = "Slot%d" % (i + 1)
				sm.position = Vector3(sin(a) * 1.9, 1.35, cos(a) * 1.9)
				sm.rotation.y = a + PI
				root.add_child(sm)
			var door := Marker3D.new()
			door.name = "Door"
			door.position = Vector3(0, 0, 2.3)
			root.add_child(door)
		"barbed_wire":
			_mi(_cached("barbed_wire", _mesh_wire), mat_vc_metal, root, "Body")
		"concrete_wall":
			_mi(_cached("concrete_wall", _mesh_concrete_wall), mat_vc, root, "Wall")
		"wall_post_wood":
			_mi(_cached("post_wood", _mesh_post_wood), mat_vc, root, "Post")
		"wall_post_concrete":
			_mi(_cached("post_concrete", _mesh_post_concrete), mat_vc, root, "Post")
		"concrete_gate":
			_mi(_cached("gate_frame", _mesh_gate_frame), mat_vc, root, "Frame")
			for side in [-1, 1]:
				var hinge := Node3D.new()
				hinge.name = "LeafL" if side < 0 else "LeafR"
				hinge.position = Vector3(side * 1.9, 0, 0)
				root.add_child(hinge)
				_mi(_cached("gate_leaf%d" % side, func(): return _mesh_gate_leaf(side)), mat_vc_metal, hinge)
		"civilian_a", "civilian_b":
			_build_civilian(root, kind == "civilian_b")
		"loader":
			_build_worker(root, true)
		"ammo_crate":
			_mi(_cached("ammo_crate", _mesh_ammo_crate), mat_vc, root, "Crate")
		"flame_bunker":
			_mi(_cached("flame_base", _mesh_flame_base), mat_vc, root, "Base")
			var fyaw := Node3D.new()
			fyaw.name = "Yaw"
			fyaw.position = Vector3(0, 1.0, 0)
			root.add_child(fyaw)
			_mi(_cached("flame_yaw", _mesh_flame_yaw), mat_vc_metal, fyaw)
			var nz := Marker3D.new()
			nz.name = "Nozzle"
			nz.position = Vector3(0, 0.16, -1.0)
			fyaw.add_child(nz)
			var pilot := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 0.05
			pm.height = 0.1
			pilot.mesh = pm
			pilot.set_surface_override_material(0, mat_lamp)
			pilot.position = Vector3(0, 0, 0.02)
			nz.add_child(pilot)
		"gun_platform":
			_mi(_cached("gun_platform", _mesh_platform), mat_vc, root, "Body")
			_marker(root, "Slot", Vector3(0, 2.75, 0))
		"wall_mount_nest":
			_mi(_cached("nest", func(): return _mesh_sandbag_ring(0.95, 0.55)), mat_vc, root, "Body")
			_marker(root, "Slot", Vector3(0, 0.12, 0))
		"sniper_nest":
			_mi(_cached("sniper_nest", func(): return _mesh_sandbag_ring(0.8, 0.7)), mat_vc, root, "Body")
			_marker(root, "Perch", Vector3(0, 0.1, 0.15))
		"wall_port_wood":
			_mi(_cached("wall_port_wood", func(): return _mesh_port_wall(false)), mat_vc, root, "Wall")
			_marker(root, "Port1", Vector3(0, 1.45, 0))
		"concrete_wall_port":
			_mi(_cached("concrete_wall_port", func(): return _mesh_port_wall(true)), mat_vc, root, "Wall")
			_marker(root, "Port1", Vector3(0, 1.7, 0))
		"bastion_wood", "bastion_concrete":
			var conc := kind == "bastion_concrete"
			_mi(_cached(kind, func(): return _mesh_bastion(conc)), mat_vc, root, "Body")
			var top := 4.0 if conc else 3.0
			_marker(root, "Slot", Vector3(0, top + 0.05, 0))
			_marker(root, "Port1", Vector3(-0.7, top - 1.4, -1.5))
			_marker(root, "Port2", Vector3(0.7, top - 1.4, -1.5))
		"house", "depot", "workshop", "barracks", "watchtower_concrete":
			_build_prefab(root, kind)
		"ammo_point":
			_mi(_cached("ammo_point", _mesh_ammo_point), mat_vc, root, "Body")
		"radio_mast":
			_mi(_cached("radio_mast", _mesh_radio_mast), mat_vc_metal, root, "Body")
			var rl := MeshInstance3D.new()
			var rlm := SphereMesh.new()
			rlm.radius = 0.12
			rlm.height = 0.24
			rl.mesh = rlm
			rl.set_surface_override_material(0, mat_lamp_red)
			rl.position = Vector3(0, 7.1, 0)
			root.add_child(rl)
		"fuel_tank":
			_mi(_cached("fuel_tank", _mesh_fuel_tank), mat_vc, root, "Body")
		"salvage_wreck_a", "salvage_wreck_b":
			var vb := kind == "salvage_wreck_b"
			_mi(_cached(kind, func(): return _mesh_wreck(vb)), mat_vc, root, "Body")
		"scrap_bundle":
			_mi(_cached("scrap_bundle", _mesh_scrap_bundle), mat_vc_metal, root, "Body")
		"fetcher":
			_build_worker(root, true)
		"decoy":
			_mi(_cached("decoy", _mesh_decoy), mat_vc_metal, root, "Body")
			var dl := MeshInstance3D.new()
			var dlm := SphereMesh.new()
			dlm.radius = 0.12
			dlm.height = 0.24
			dl.mesh = dlm
			dl.set_surface_override_material(0, mat_lamp_red)
			dl.position = Vector3(0, 3.55, 0)
			root.add_child(dl)
		"greenhouse":
			_mi(_cached("greenhouse", _mesh_greenhouse), mat_vc, root, "Body")
			_marker(root, "Door", Vector3(0, 0, 1.9))
		"clinic":
			_mi(_cached("clinic", _mesh_clinic), mat_vc, root, "Body")
			_marker(root, "Door", Vector3(0, 0, 1.9))
		"water_tower":
			_mi(_cached("water_tower", _mesh_water_tower), mat_vc, root, "Body")
			_marker(root, "RoofSlot1", Vector3(0, 10.75, 0))
			_marker(root, "Door", Vector3(0, 0, 2.2))
		"container":
			var cv := randi() % 4
			_mi(_cached("container_%d" % cv, func(): return _mesh_container(cv)), mat_vc, root, "Body")
			_marker(root, "RoofSlot1", Vector3(0, 2.62, 0))
		"pillbox":
			_mi(_cached("pillbox", _mesh_pillbox), mat_vc, root, "Body")
			_marker(root, "Port1", Vector3(0, 1.15, -1.7))
			_marker(root, "Port2", Vector3(1.7, 1.15, 0), -PI * 0.5)
			_marker(root, "Port3", Vector3(-1.7, 1.15, 0), PI * 0.5)
			_marker(root, "Door", Vector3(0, 0, 2.1))
		"armory":
			_mi(_cached("armory", _mesh_armory), mat_vc, root, "Body")
			_marker(root, "Door", Vector3(0, 0, 1.9))
		"scrapyard":
			_mi(_cached("scrapyard", _mesh_scrapyard), mat_vc_metal, root, "Body")
			_marker(root, "Door", Vector3(0, 0, 2.4))
		_:
			var k := MeshKit.new()
			k.box(Vector3(1.6, 1.6, 1.6), Vector3(0, 0.8, 0), Color.MAGENTA)
			_mi(k.build(), mat_vc, root)
	for mi in mesh_instances(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.set_meta("placeholder", true)
	return root

func _marker(root: Node3D, n: String, p: Vector3, rot_y: float = 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = rot_y
	root.add_child(m)
	return m

func _mesh_platform() -> ArrayMesh:
	var k := MeshKit.new()
	for x in [-0.75, 0.75]:
		for z in [-0.75, 0.75]:
			k.box(Vector3(0.14, 2.6, 0.14), Vector3(x, 1.3, z), C_WOOD)
	k.box(Vector3(1.8, 0.04, 0.08), Vector3(0, 1.2, 0.75), C_WOOD_DK, Vector3(0, 0, 0.9))
	k.box(Vector3(1.8, 0.04, 0.08), Vector3(0, 1.2, -0.75), C_WOOD_DK, Vector3(0, 0, -0.9))
	k.box(Vector3(1.9, 0.14, 1.9), Vector3(0, 2.62, 0), C_WOOD_DK)
	for i in 8:
		var a := i * TAU / 8.0
		k.box(Vector3(0.62, 0.3, 0.36), Vector3(sin(a) * 0.82, 2.84, cos(a) * 0.82), C_FABRIC, Vector3(0, a, 0))
	k.box(Vector3(0.06, 2.6, 0.06), Vector3(-0.22, 1.3, 1.0), C_WOOD)
	k.box(Vector3(0.06, 2.6, 0.06), Vector3(0.22, 1.3, 1.0), C_WOOD)
	for i in 6:
		k.box(Vector3(0.44, 0.05, 0.05), Vector3(0, 0.3 + i * 0.4, 1.0), C_WOOD)
	return k.build()

func _mesh_sandbag_ring(r: float, h: float) -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(r * 2.0, 0.08, r * 2.0), Vector3(0, 0.04, 0), C_WOOD_DK)
	var rows := maxi(1, int(round(h / 0.25)))
	for row in rows:
		for i in 9:
			var a := (i + row * 0.5) * TAU / 9.0
			if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45:
				continue
			k.box(Vector3(0.6, 0.24, 0.34), Vector3(sin(a) * r, 0.2 + row * 0.24, cos(a) * r), C_FABRIC.darkened(0.08 * (row % 2)), Vector3(0, a, 0))
	return k.build()

func _mesh_port_wall(concrete: bool) -> ArrayMesh:
	var k := MeshKit.new()
	if concrete:
		k.box(Vector3(1.96, 3.5, 0.5), Vector3(0, 1.75, 0), C_CONCRETE)
		k.box(Vector3(1.96, 0.5, 0.8), Vector3(0, 0.25, 0), C_CONCRETE_DK)
		k.box(Vector3(0.9, 0.16, 0.56), Vector3(0, 1.7, 0), C_DARK)
	else:
		k.box(Vector3(1.96, 2.2, 0.5), Vector3(0, 1.1, 0), C_WOOD)
		k.box(Vector3(0.9, 0.16, 0.56), Vector3(0, 1.45, 0), C_DARK)
		for x in [-0.8, 0.8]:
			k.box(Vector3(0.14, 2.3, 0.6), Vector3(x, 1.15, 0), C_WOOD_DK)
	return k.build()

func _mesh_bastion(concrete: bool) -> ArrayMesh:
	var k := MeshKit.new()
	var top := 4.0 if concrete else 3.0
	var col := C_CONCRETE if concrete else C_WOOD
	k.box(Vector3(3.0, top, 3.0), Vector3(0, top * 0.5, 0), col)
	for i in 4:
		var a := i * PI * 0.5
		k.box(Vector3(3.0, 0.6, 0.3), Vector3(sin(a) * 1.35, top + 0.3, cos(a) * 1.35), col.darkened(0.1), Vector3(0, a, 0))
	for x in [-0.7, 0.7]:
		k.box(Vector3(0.7, 0.14, 0.1), Vector3(x, top - 1.4, -1.52), C_DARK)
	return k.build()

func _build_prefab(root: Node3D, kind: String) -> void:
	var d: Dictionary = Defs.BUILD.get("watchtower" if kind == "watchtower_concrete" else kind, {})
	var h: Vector2 = d.get("half", Vector2(2, 2))
	var height: float = {"house": 6.0, "depot": 4.6, "workshop": 4.2, "barracks": 4.0, "watchtower_concrete": 7.8}.get(kind, 4.0)
	var col: Color = {"house": Color(0.62, 0.5, 0.4), "depot": C_CONCRETE, "workshop": Color(0.5, 0.45, 0.38), "barracks": C_OLIVE_LT, "watchtower_concrete": C_CONCRETE}.get(kind, C_CONCRETE)
	var k := MeshKit.new()
	k.box(Vector3(h.x * 2.0, height, h.y * 2.0), Vector3(0, height * 0.5, 0), col)
	k.box(Vector3(h.x * 2.0 + 0.1, 0.5, h.y * 2.0 + 0.1), Vector3(0, height + 0.25, 0), col.darkened(0.15))
	k.box(Vector3(1.0, 2.0, 0.1), Vector3(0, 1.0, -h.y - 0.02), C_DARK)
	_mi(k.build(), mat_vc, root, "Body")
	var slots := 1
	if kind == "house" or kind == "barracks":
		slots = 2
	for i in slots:
		var off := Vector3(-h.x * 0.5, 0, -h.y * 0.4) if i == 0 else Vector3(h.x * 0.5, 0, h.y * 0.4)
		if slots == 1:
			off = Vector3.ZERO
		_marker(root, "RoofSlot%d" % (i + 1), Vector3(off.x, height + 0.05, off.z), 0.0 if i == 0 else PI)
	var wins := [Vector3(-h.x * 0.5, 1.5, -h.y + 0.1), Vector3(h.x * 0.5, 1.5, -h.y + 0.1), Vector3(0, 1.5, h.y - 0.1), Vector3(-h.x + 0.1, 1.5, 0), Vector3(h.x - 0.1, 1.5, 0)]
	var rots := [0.0, 0.0, PI, PI * 0.5, -PI * 0.5]
	for i in wins.size():
		_marker(root, "Window%d" % (i + 1), wins[i], rots[i])
	_marker(root, "Door", Vector3(0, 0, -h.y - 0.4))

func _mesh_ammo_point() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(1.6, 0.12, 1.4), Vector3(0, 0.06, 0), C_WOOD_DK)
	for i in 6:
		var x := -0.45 + (i % 3) * 0.45
		var z := -0.3 + (i / 3) * 0.6
		k.box(Vector3(0.4, 0.3, 0.55), Vector3(x, 0.27, z), C_OLIVE)
	for i in 3:
		k.box(Vector3(0.4, 0.3, 0.55), Vector3(-0.45 + i * 0.45, 0.57, 0.0), C_OLIVE.darkened(0.1))
	k.box(Vector3(1.7, 0.05, 1.5), Vector3(0, 0.95, 0), C_FABRIC, Vector3(0.05, 0, 0.04))
	return k.build()

func _mesh_radio_mast() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(1.4, 0.2, 1.4), Vector3(0, 0.1, 0), C_CONCRETE)
	for i in 3:
		var a := i * TAU / 3.0
		k.cyl(0.04, 0.06, 7.0, Vector3(sin(a) * 0.25, 3.6, cos(a) * 0.25), C_METAL)
	for j in 10:
		k.box(Vector3(0.5, 0.03, 0.03), Vector3(0, 0.6 + j * 0.65, 0), C_METAL, Vector3(0, j * 0.6, 0))
	k.cyl(0.02, 0.02, 1.4, Vector3(0, 7.6, 0), C_METAL)
	k.box(Vector3(0.6, 0.4, 0.5), Vector3(0.5, 0.45, 0.4), C_OLIVE)
	return k.build()

func _mesh_decoy() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(1.2, 0.25, 1.2), Vector3(0, 0.12, 0), C_CONCRETE_DK)
	k.box(Vector3(0.7, 0.5, 0.5), Vector3(0.25, 0.5, 0.25), C_OLIVE)
	k.cyl(0.07, 0.09, 3.4, Vector3(0, 1.8, 0), C_METAL)
	for i in 3:
		var a := i * TAU / 3.0
		var d := Vector3(sin(a), 0, cos(a))
		k.cyl(0.26, 0.08, 0.55, Vector3(0, 3.1, 0) + d * 0.3, C_GUNMETAL, Vector3(PI * 0.5, a, 0), 10)
	k.box(Vector3(0.5, 0.06, 0.06), Vector3(0, 2.6, 0), Color(0.85, 0.65, 0.1))
	return k.build()

func _mesh_greenhouse() -> ArrayMesh:
	var k := MeshKit.new()
	var glass := Color(0.6, 0.78, 0.72)
	var frame := Color(0.85, 0.86, 0.82)
	var w := 4.8
	var d := 2.8
	k.box(Vector3(w + 0.2, 0.3, d + 0.2), Vector3(0, 0.15, 0), C_CONCRETE)
	k.box(Vector3(w, 1.9, d), Vector3(0, 1.25, 0), glass)
	k.prism(Vector3(d, 1.0, w), Vector3(0, 2.7, 0), glass, Vector3(0, PI * 0.5, 0))
	for x in [-2.4, -1.2, 0.0, 1.2, 2.4]:
		k.box(Vector3(0.08, 1.95, d + 0.06), Vector3(x, 1.25, 0), frame)
	for z in [-1.4, 1.4]:
		k.box(Vector3(w + 0.06, 0.08, 0.08), Vector3(0, 2.2, z), frame)
		k.box(Vector3(w + 0.06, 0.08, 0.08), Vector3(0, 0.32, z), frame)
	k.box(Vector3(w + 0.06, 0.1, 0.1), Vector3(0, 3.2, 0), frame)
	for z in [-0.75, 0.75]:
		k.box(Vector3(w - 0.6, 0.35, 0.6), Vector3(0, 0.48, z), C_DIRT)
		for i in 7:
			k.sphere(0.22, Vector3(-1.8 + i * 0.6, 0.78, z), Color(0.24, 0.5, 0.18), Vector3(1, 0.8, 1), Vector3.ZERO, 6, 4)
	k.box(Vector3(0.9, 1.8, 0.06), Vector3(0, 1.2, 1.42), Color(0.5, 0.62, 0.58))
	return k.build()

func _mesh_clinic() -> ArrayMesh:
	var k := MeshKit.new()
	var white := Color(0.86, 0.85, 0.8)
	var red := Color(0.75, 0.12, 0.1)
	k.box(Vector3(4.1, 0.25, 3.1), Vector3(0, 0.12, 0), C_CONCRETE)
	k.box(Vector3(3.8, 2.6, 2.8), Vector3(0, 1.55, 0), white)
	k.box(Vector3(4.0, 0.2, 3.0), Vector3(0, 2.95, 0), Color(0.62, 0.62, 0.6))
	k.box(Vector3(1.6, 0.04, 0.45), Vector3(0, 3.07, 0), red)
	k.box(Vector3(0.45, 0.04, 1.6), Vector3(0, 3.07, 0), red)
	k.box(Vector3(0.9, 0.28, 0.04), Vector3(0, 2.3, 1.42), red)
	k.box(Vector3(0.28, 0.9, 0.04), Vector3(0, 2.3, 1.42), red)
	k.box(Vector3(1.0, 1.9, 0.06), Vector3(0, 1.2, 1.41), Color(0.3, 0.42, 0.45))
	for x in [-1.4, 1.4]:
		k.box(Vector3(0.7, 0.6, 0.05), Vector3(x, 1.7, 1.42), Color(0.45, 0.6, 0.65))
	k.box(Vector3(1.6, 0.08, 0.9), Vector3(0, 2.25, 1.85), white)
	return k.build()

func _mesh_water_tower() -> ArrayMesh:
	var k := MeshKit.new()
	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			k.box(Vector3(0.5, 0.3, 0.5), Vector3(x, 0.15, z), C_CONCRETE)
			k.cyl(0.11, 0.14, 8.6, Vector3(x * 0.9, 4.4, z * 0.9), C_METAL, Vector3(-z * 0.03, 0, x * 0.03))
	for y in [2.6, 5.4]:
		for side in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			var along := Vector3(0, PI * 0.5, 0) if side.x != 0.0 else Vector3.ZERO
			k.box(Vector3(2.0, 0.07, 0.07), Vector3(side.x, y, side.z) * Vector3(0.98, 1, 0.98), C_METAL, along)
	k.cyl(1.35, 1.35, 1.9, Vector3(0, 9.6, 0), Color(0.55, 0.6, 0.62), Vector3.ZERO, 16)
	k.cyl(1.45, 1.45, 0.12, Vector3(0, 8.65, 0), C_METAL, Vector3.ZERO, 16)
	k.cyl(1.5, 1.5, 0.16, Vector3(0, 10.62, 0), C_CONCRETE_DK, Vector3.ZERO, 16)
	for i in 10:
		var a := i * TAU / 10.0
		k.box(Vector3(0.55, 0.28, 0.3), Vector3(sin(a) * 1.3, 10.84, cos(a) * 1.3), C_FABRIC, Vector3(0, a, 0))
	for j in 14:
		k.box(Vector3(0.5, 0.05, 0.05), Vector3(0, 0.6 + j * 0.62, 1.12), C_METAL)
	k.box(Vector3(0.05, 8.6, 0.05), Vector3(-0.25, 4.6, 1.12), C_METAL)
	k.box(Vector3(0.05, 8.6, 0.05), Vector3(0.25, 4.6, 1.12), C_METAL)
	return k.build()

func _mesh_container(v: int) -> ArrayMesh:
	var k := MeshKit.new()
	var col: Color = [Color(0.55, 0.18, 0.12), Color(0.16, 0.32, 0.48), Color(0.3, 0.42, 0.2), Color(0.62, 0.5, 0.18)][v % 4]
	var dk := col.darkened(0.3)
	k.box(Vector3(6.0, 2.5, 2.4), Vector3(0, 1.3, 0), col)
	for i in 13:
		var x := -2.8 + i * 0.467
		k.box(Vector3(0.08, 2.3, 2.46), Vector3(x, 1.3, 0), dk)
	for x in [-2.98, 2.98]:
		for z in [-1.18, 1.18]:
			k.box(Vector3(0.14, 2.6, 0.14), Vector3(x, 1.3, z), C_METAL)
	k.box(Vector3(0.06, 2.2, 1.0), Vector3(3.02, 1.3, -0.55), dk)
	k.box(Vector3(0.06, 2.2, 1.0), Vector3(3.02, 1.3, 0.55), dk)
	k.box(Vector3(0.04, 2.0, 0.06), Vector3(3.06, 1.3, -0.3), C_METAL)
	k.box(Vector3(0.04, 2.0, 0.06), Vector3(3.06, 1.3, 0.3), C_METAL)
	return k.build()

func _mesh_pillbox() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(3.3, 0.2, 3.3), Vector3(0, 0.1, 0), C_CONCRETE_DK)
	k.box(Vector3(3.0, 0.8, 3.0), Vector3(0, 0.6, 0), C_CONCRETE)
	k.box(Vector3(3.0, 0.22, 3.0), Vector3(0, 1.11, 0), C_DARK)
	for p in [Vector3(0, 1.11, -1.38), Vector3(1.38, 1.11, 0), Vector3(-1.38, 1.11, 0), Vector3(0, 1.11, 1.38)]:
		k.box(Vector3(0.5, 0.24, 0.5), p, C_CONCRETE)
	k.box(Vector3(3.0, 0.5, 3.0), Vector3(0, 1.47, 0), C_CONCRETE)
	k.box(Vector3(3.4, 0.25, 3.4), Vector3(0, 1.82, 0), C_CONCRETE_DK)
	k.box(Vector3(0.9, 1.0, 0.06), Vector3(0, 0.6, 1.52), C_METAL)
	for i in 8:
		var a := i * TAU / 8.0
		k.box(Vector3(0.7, 0.3, 0.4), Vector3(sin(a) * 1.25, 2.1, cos(a) * 1.25), C_FABRIC, Vector3(0, a, 0))
	return k.build()

func _mesh_armory() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(4.1, 0.2, 3.1), Vector3(0, 0.1, 0), C_CONCRETE)
	k.box(Vector3(3.8, 2.4, 2.8), Vector3(0, 1.4, 0), C_OLIVE)
	k.prism(Vector3(3.1, 0.8, 4.0), Vector3(0, 3.0, 0), C_OLIVE_LT, Vector3(0, PI * 0.5, 0))
	k.box(Vector3(1.4, 1.8, 0.06), Vector3(0, 1.1, 1.42), C_METAL)
	k.box(Vector3(1.0, 0.5, 0.06), Vector3(0, 2.3, 1.42), C_SAND)
	k.box(Vector3(0.7, 0.07, 0.07), Vector3(0, 2.3, 1.46), C_DARK, Vector3(0, 0, 0.6))
	k.box(Vector3(0.7, 0.07, 0.07), Vector3(0, 2.3, 1.46), C_DARK, Vector3(0, 0, -0.6))
	for x in [-1.5, -1.0, 1.0, 1.5]:
		k.box(Vector3(0.45, 0.32, 0.32), Vector3(x, 0.36, 1.75), C_OLIVE_LT)
	return k.build()

func _mesh_scrapyard() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(5.0, 0.08, 4.0), Vector3(0, 0.04, 0), C_DIRT)
	for i in 11:
		var x := -2.5 + i * 0.5
		k.box(Vector3(0.08, 1.6, 0.08), Vector3(x, 0.8, -2.0), C_METAL)
	for z in [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0]:
		k.box(Vector3(0.08, 1.6, 0.08), Vector3(-2.5, 0.8, z), C_METAL)
		k.box(Vector3(0.08, 1.6, 0.08), Vector3(2.5, 0.8, z), C_METAL)
	k.box(Vector3(5.0, 0.05, 0.05), Vector3(0, 1.5, -2.0), C_WIRE)
	k.box(Vector3(0.05, 0.05, 4.0), Vector3(-2.5, 1.5, 0), C_WIRE)
	k.box(Vector3(0.05, 0.05, 4.0), Vector3(2.5, 1.5, 0), C_WIRE)
	for p in [Vector3(-1.4, 0, -1.0), Vector3(0.6, 0, -1.2), Vector3(-0.3, 0, 0.6)]:
		for j in 6:
			k.box(Vector3(0.9 - j * 0.1, 0.25, 0.7), p + Vector3(randf_range(-0.2, 0.2), 0.15 + j * 0.2, randf_range(-0.2, 0.2)), [C_RUST, C_METAL, C_GUNMETAL][j % 3], Vector3(0, j * 0.7, 0.1))
	k.box(Vector3(1.6, 1.9, 1.6), Vector3(1.5, 0.95, 0.9), C_WOOD)
	k.box(Vector3(1.8, 0.1, 1.8), Vector3(1.5, 1.95, 0.9), C_RUST)
	return k.build()

func _mesh_fuel_tank() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(0.2, 0.5, 1.2), Vector3(-0.6, 0.25, 0), C_WOOD_DK)
	k.box(Vector3(0.2, 0.5, 1.2), Vector3(0.6, 0.25, 0), C_WOOD_DK)
	k.cyl(0.55, 0.55, 1.8, Vector3(0, 0.95, 0), Color(0.62, 0.16, 0.12), Vector3(0, 0, PI * 0.5), 14)
	k.box(Vector3(0.12, 0.2, 0.12), Vector3(0.3, 1.55, 0), C_METAL)
	return k.build()

func _mesh_wreck(b: bool) -> ArrayMesh:
	var k := MeshKit.new()
	var car := Color(0.24, 0.2, 0.17) if not b else Color(0.3, 0.26, 0.18)
	if not b:
		k.box(Vector3(1.9, 0.7, 4.2), Vector3(0, 0.55, 0), car)
		k.box(Vector3(1.6, 0.6, 2.0), Vector3(0, 1.15, -0.2), car.darkened(0.2))
		for x in [-0.95, 0.95]:
			for z in [-1.3, 1.3]:
				k.cyl(0.34, 0.34, 0.24, Vector3(x, 0.32, z), C_DARK, Vector3(0, 0, PI * 0.5))
	else:
		k.box(Vector3(2.4, 2.3, 5.5), Vector3(0, 1.2, 0), car, Vector3(0, 0, 0.35))
		k.box(Vector3(2.3, 1.4, 1.6), Vector3(0.3, 0.75, -3.4), C_RUST, Vector3(0, 0.2, 0.3))
	for i in 5:
		k.box(Vector3(0.5, 0.15, 0.4), Vector3(-1.6 + i * 0.7, 0.08, 2.4), C_RUST, Vector3(0, i * 0.9, 0))
	return k.build()

func _mesh_scrap_bundle() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(0.5, 0.3, 0.35), Vector3(0, 0, 0), C_RUST)
	k.box(Vector3(0.6, 0.05, 0.1), Vector3(0, 0.18, 0), C_METAL, Vector3(0, 0.4, 0))
	k.cyl(0.04, 0.04, 0.7, Vector3(0.1, 0.1, 0), C_GUNMETAL, Vector3(0, 0, 1.2))
	return k.build()

func scrap_pile_mesh() -> ArrayMesh:
	return _cached("scrap_pile", func():
		var k := MeshKit.new()
		var r := RandomNumberGenerator.new()
		r.seed = 77
		for i in 12:
			var p := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(0.05, 0.35), r.randf_range(-0.8, 0.8))
			k.box(Vector3(r.randf_range(0.2, 0.6), r.randf_range(0.08, 0.3), r.randf_range(0.2, 0.5)), p, C_RUST.lerp(C_METAL, r.randf()), Vector3(r.randf() * 0.5, r.randf() * TAU, r.randf() * 0.5))
		return k.build())

func _mesh_hq() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(6.0, 0.25, 6.0), Vector3(0, 0.125, 0), C_CONCRETE_DK)
	for side in 4:
		if side == 2:
			continue
		var b := Basis.from_euler(Vector3(0, side * PI * 0.5, 0))
		k.prism(Vector3(0.9, 0.9, 5.6), b * Vector3(0, 0.45, 2.55), C_DIRT, Vector3(0, side * PI * 0.5 + PI * 0.5, 0), 1.0)
	k.box(Vector3(4.6, 2.1, 4.6), Vector3(0, 1.3, 0), C_CONCRETE)
	k.box(Vector3(5.1, 0.32, 5.1), Vector3(0, 2.5, 0), C_CONCRETE_DK)
	k.box(Vector3(4.2, 0.16, 4.2), Vector3(0, 2.72, 0), C_CONCRETE)
	for i in 3:
		k.box(Vector3(4.62, 0.05, 4.62), Vector3(0, 0.6 + i * 0.55, 0), C_CONCRETE_DK.lightened(0.05))
	k.box(Vector3(1.5, 1.75, 0.12), Vector3(0, 1.12, -2.31), C_METAL)
	k.box(Vector3(1.2, 1.55, 0.06), Vector3(0, 1.05, -2.36), Color(0.16, 0.18, 0.15))
	k.box(Vector3(1.8, 0.12, 0.7), Vector3(0, 0.3, -2.6), Color(0.85, 0.62, 0.12))
	for side in 4:
		var rot := Vector3(0, side * PI * 0.5, 0)
		var b := Basis.from_euler(rot)
		var xo := 1.3 if side == 0 else 0.0
		var sw := 0.8 if side == 0 else 1.8
		k.box(Vector3(sw, 0.2, 0.08), b * Vector3(xo, 1.85, -2.31), C_DARK, rot)
	for i in 6:
		k.capsule(0.16, 0.7, Vector3(-1.9 + i * 0.76, 2.82, 2.25), C_SAND, Vector3(0, 0, PI * 0.5), Vector3(0.75, 1, 1))
		k.capsule(0.16, 0.7, Vector3(-2.25, 2.82, -1.9 + i * 0.76), C_SAND, Vector3(PI * 0.5, 0, 0), Vector3(1, 1, 0.75))
	k.cyl(0.035, 0.05, 3.4, Vector3(1.75, 4.4, 1.75), C_METAL)
	k.cyl(0.0, 0.12, 0.25, Vector3(1.75, 6.15, 1.75), Color(0.85, 0.2, 0.15))
	k.cyl(0.03, 0.03, 2.4, Vector3(-1.9, 3.9, -1.9), C_METAL)
	k.box(Vector3(0.9, 0.55, 0.03), Vector3(-1.42, 4.75, -1.9), Color(0.85, 0.55, 0.12))
	k.box(Vector3(0.9, 0.12, 0.035), Vector3(-1.42, 4.6, -1.9), Color(0.15, 0.15, 0.13))
	k.box(Vector3(0.8, 0.6, 0.6), Vector3(2.55, 0.3, -1.9), C_WOOD)
	k.box(Vector3(0.6, 0.5, 0.6), Vector3(2.5, 0.85, -1.85), C_WOOD.darkened(0.1), Vector3(0, 0.3, 0))
	k.cyl(0.3, 0.3, 0.9, Vector3(-2.6, 0.45, -2.1), C_OLIVE)
	k.cyl(0.3, 0.3, 0.9, Vector3(-2.65, 0.45, -1.4), Color(0.55, 0.16, 0.12))
	k.box(Vector3(1.0, 0.45, 0.5), Vector3(-2.6, 0.22, 2.4), C_OLIVE_LT)
	return k.build()

func _mesh_hq_dish() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.05, 0.08, 0.5, Vector3(0, 0.25, 0), C_METAL)
	k.sphere(0.55, Vector3(0, 0.6, -0.1), C_CONCRETE.lightened(0.2), Vector3(1, 1, 0.35), Vector3(-0.4, 0, 0), 12, 5, 1.0, true)
	k.cyl(0.02, 0.02, 0.5, Vector3(0, 0.75, -0.35), C_METAL, Vector3(-1.2, 0, 0))
	return k.build()

func _mesh_wall() -> ArrayMesh:
	var k := MeshKit.new()
	var s := 1.92
	var h := 1.6
	k.box(Vector3(s, h, s), Vector3(0, h * 0.5, 0), C_FABRIC)
	k.box(Vector3(s - 0.12, 0.1, s - 0.12), Vector3(0, h + 0.03, 0), C_DIRT)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			k.box(Vector3(0.06, h + 0.04, 0.06), Vector3(cx * s * 0.5, h * 0.5, cz * s * 0.5), C_WIRE)
	for y in [0.03, h * 0.5, h]:
		k.box(Vector3(s + 0.04, 0.04, 0.04), Vector3(0, y, s * 0.5), C_WIRE)
		k.box(Vector3(s + 0.04, 0.04, 0.04), Vector3(0, y, -s * 0.5), C_WIRE)
		k.box(Vector3(0.04, 0.04, s + 0.04), Vector3(s * 0.5, y, 0), C_WIRE)
		k.box(Vector3(0.04, 0.04, s + 0.04), Vector3(-s * 0.5, y, 0), C_WIRE)
	for t in [-0.32, 0.32]:
		k.box(Vector3(0.035, h, 0.035), Vector3(t * s, h * 0.5, s * 0.5 + 0.005), C_WIRE)
		k.box(Vector3(0.035, h, 0.035), Vector3(t * s, h * 0.5, -s * 0.5 - 0.005), C_WIRE)
		k.box(Vector3(0.035, h, 0.035), Vector3(s * 0.5 + 0.005, h * 0.5, t * s), C_WIRE)
		k.box(Vector3(0.035, h, 0.035), Vector3(-s * 0.5 - 0.005, h * 0.5, t * s), C_WIRE)
	return k.build()

func _mesh_turret_base() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.85, 0.95, 0.12, Vector3(0, 0.06, 0), C_CONCRETE_DK, Vector3.ZERO, 16)
	for layer in 2:
		var n := 9
		for i in n:
			var a := (i + layer * 0.5) / n * TAU
			var r := 0.82
			var p := Vector3(cos(a) * r, 0.24 + layer * 0.27, sin(a) * r)
			k.capsule(0.15, 0.62, p, C_SAND.darkened(0.05 * layer), Vector3(0, PI * 0.5 - a, PI * 0.5), Vector3(0.8, 1, 1))
	k.cyl(0.14, 0.2, 0.86, Vector3(0, 0.5, 0), C_METAL)
	k.cyl(0.3, 0.3, 0.06, Vector3(0, 0.9, 0), C_METAL)
	k.box(Vector3(0.35, 0.3, 0.45), Vector3(0.55, 0.15, 0.35), C_OLIVE)
	return k.build()

func _mesh_turret_yaw() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(0.3, 0.26, 0.8), Vector3(0, 0.05, 0.0), C_GUNMETAL)
	k.box(Vector3(0.95, 0.6, 0.05), Vector3(0, 0.12, -0.42), C_OLIVE, Vector3(-0.08, 0, 0))
	k.box(Vector3(0.28, 0.1, 0.06), Vector3(0, 0.12, -0.45), C_DARK)
	k.box(Vector3(0.2, 0.22, 0.3), Vector3(-0.27, 0.02, 0.0), C_OLIVE_LT)
	k.cyl(0.025, 0.025, 0.3, Vector3(0.1, 0.0, 0.45), C_METAL, Vector3(PI * 0.5, 0, 0))
	k.cyl(0.025, 0.025, 0.3, Vector3(-0.1, 0.0, 0.45), C_METAL, Vector3(PI * 0.5, 0, 0))
	k.cyl(0.07, 0.07, 0.3, Vector3(0, -0.15, 0.05), C_METAL)
	return k.build()

func _mesh_turret_barrel() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.042, 0.042, 1.05, Vector3(0, 0, -0.55), C_METAL, Vector3(PI * 0.5, 0, 0), 8)
	k.cyl(0.075, 0.075, 0.5, Vector3(0, 0, -0.25), C_GUNMETAL, Vector3(PI * 0.5, 0, 0), 10)
	k.cyl(0.06, 0.055, 0.14, Vector3(0, 0, -1.05), C_DARK, Vector3(PI * 0.5, 0, 0), 8)
	return k.build()

func _mesh_spike_base() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(1.8, 0.08, 1.8), Vector3(0, 0.04, 0), C_WOOD_DK)
	for i in 5:
		k.box(Vector3(1.8, 0.05, 0.3), Vector3(0, 0.1, -0.72 + i * 0.36), C_WOOD.darkened(0.05 * (i % 2)))
	k.box(Vector3(1.86, 0.14, 0.1), Vector3(0, 0.08, 0.9), C_WOOD_DK)
	k.box(Vector3(1.86, 0.14, 0.1), Vector3(0, 0.08, -0.9), C_WOOD_DK)
	return k.build()

func _mesh_spike_spikes() -> ArrayMesh:
	var k := MeshKit.new()
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for x in 4:
		for z in 4:
			var p := Vector3(-0.63 + x * 0.42, 0.42, -0.63 + z * 0.42)
			var rot := Vector3(r.randf_range(-0.15, 0.15), 0, r.randf_range(-0.15, 0.15))
			k.cyl(0.0, 0.07, 0.62, p, C_RUST.lerp(C_METAL, r.randf()), rot, 6)
	return k.build()

func _mesh_mine() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(0.6, Vector3(0, 0.0, 0), C_DIRT, Vector3(1, 0.22, 1), Vector3.ZERO, 12, 4)
	k.cyl(0.32, 0.34, 0.12, Vector3(0, 0.12, 0), C_OLIVE, Vector3.ZERO, 14)
	k.cyl(0.13, 0.13, 0.05, Vector3(0, 0.2, 0), C_METAL, Vector3.ZERO, 10)
	for i in 3:
		var a := i * TAU / 3.0
		k.cyl(0.012, 0.012, 0.16, Vector3(cos(a) * 0.07, 0.28, sin(a) * 0.07), C_METAL, Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3), 4)
	return k.build()

func _build_worker(root: Node3D, loader: bool = false) -> void:
	var skin := Color(0.86, 0.66, 0.5)
	var vest := Color(0.95, 0.47, 0.1) if not loader else Color(0.62, 0.55, 0.32)
	var pants := Color(0.2, 0.24, 0.32)
	var body := MeshKit.new()
	body.box(Vector3(0.38, 0.2, 0.22), Vector3(0, 0.9, 0), pants)
	body.box(Vector3(0.42, 0.55, 0.25), Vector3(0, 1.2, 0), vest)
	body.box(Vector3(0.43, 0.05, 0.26), Vector3(0, 1.1, 0), Color(0.9, 0.9, 0.85))
	body.box(Vector3(0.43, 0.05, 0.26), Vector3(0, 1.3, 0), Color(0.9, 0.9, 0.85))
	body.cyl(0.06, 0.07, 0.1, Vector3(0, 1.52, 0), skin)
	body.sphere(0.13, Vector3(0, 1.64, 0), skin)
	body.sphere(0.155, Vector3(0, 1.68, 0), Color(0.98, 0.8, 0.12), Vector3(1, 1, 1), Vector3.ZERO, 12, 4, 1.0, true)
	body.cyl(0.2, 0.2, 0.025, Vector3(0, 1.68, -0.02), Color(0.98, 0.8, 0.12), Vector3.ZERO, 12)
	body.box(Vector3(0.3, 0.35, 0.12), Vector3(0, 1.22, 0.18), C_OLIVE)
	_mi(body.build(), mat_vc, root, "Body")
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side * 0.1, 0.86, 0)
		root.add_child(leg)
		var lk := MeshKit.new()
		lk.box(Vector3(0.15, 0.8, 0.17), Vector3(0, -0.42, 0), pants)
		lk.box(Vector3(0.16, 0.1, 0.27), Vector3(0, -0.82, -0.04), Color(0.18, 0.13, 0.08))
		_mi(lk.build(), mat_vc, leg)
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side * 0.27, 1.43, 0)
		root.add_child(arm)
		var ak := MeshKit.new()
		ak.box(Vector3(0.12, 0.34, 0.13), Vector3(0, -0.15, 0), vest)
		ak.box(Vector3(0.1, 0.3, 0.1), Vector3(0, -0.45, 0), skin)
		ak.sphere(0.06, Vector3(0, -0.63, 0), Color(0.3, 0.25, 0.2))
		if side > 0 and not loader:
			ak.cyl(0.02, 0.02, 1.0, Vector3(0, -0.66, -0.25), C_WOOD, Vector3(PI * 0.5 - 0.3, 0, 0), 6)
			ak.box(Vector3(0.2, 0.26, 0.03), Vector3(0, -0.5, -0.75), C_METAL, Vector3(PI * 0.5 - 0.3, 0, 0))
		_mi(ak.build(), mat_vc, arm)

func _zombie_common(k: MeshKit, skin: Color, shirt: Color, pants: Color, hair: Color, hunch: float, arm_drop: float) -> void:
	var dark := Color(0.12, 0.1, 0.09)
	for side in [-1, 1]:
		var tag := 0.2 if side < 0 else 0.4
		k.box(Vector3(0.16, 0.82, 0.18), Vector3(side * 0.1, 0.47, 0.0), pants, Vector3.ZERO, tag)
		k.box(Vector3(0.15, 0.08, 0.26), Vector3(side * 0.1, 0.04, -0.04), dark, Vector3.ZERO, tag)
	k.box(Vector3(0.38, 0.2, 0.22), Vector3(0, 0.92, 0.02), pants, Vector3.ZERO, 0.0)
	k.box(Vector3(0.44, 0.6, 0.26), Vector3(0, 1.26, -0.06), shirt, Vector3(-hunch, 0, 0), 0.0)
	k.box(Vector3(0.18, 0.22, 0.03), Vector3(0.08, 1.16, -0.2), shirt.darkened(0.35), Vector3(-hunch, 0, 0.2), 0.0)
	k.box(Vector3(0.16, 0.14, 0.03), Vector3(-0.1, 1.33, -0.21), Color(0.45, 0.08, 0.06), Vector3(-hunch, 0, -0.3), 0.0)
	k.cyl(0.06, 0.07, 0.14, Vector3(0, 1.6, -0.14), skin, Vector3(-0.3, 0, 0), 6, 0.0)
	k.sphere(0.145, Vector3(0, 1.72, -0.2), skin, Vector3(0.95, 1.08, 1.0), Vector3(0.15, 0, 0.18), 10, 6, 0.0)
	k.sphere(0.15, Vector3(0, 1.76, -0.19), hair, Vector3(1.0, 0.75, 1.0), Vector3(0.1, 0, 0.18), 10, 4, 0.0, true)
	k.box(Vector3(0.04, 0.025, 0.02), Vector3(-0.055, 1.74, -0.335), Color(0.95, 0.9, 0.55), Vector3.ZERO, 0.0)
	k.box(Vector3(0.04, 0.025, 0.02), Vector3(0.055, 1.74, -0.335), Color(0.95, 0.9, 0.55), Vector3.ZERO, 0.0)
	k.box(Vector3(0.1, 0.035, 0.02), Vector3(0, 1.64, -0.33), Color(0.3, 0.04, 0.04), Vector3.ZERO, 0.0)
	for side in [-1, 1]:
		var tag := 0.6 if side < 0 else 0.8
		var drop := arm_drop * (1.0 if side < 0 else 0.4)
		k.box(Vector3(0.12, 0.12, 0.36), Vector3(side * 0.28, 1.42 - drop * 0.3, -0.28), shirt.darkened(0.1), Vector3(drop, 0, 0), tag)
		k.box(Vector3(0.1, 0.1, 0.34), Vector3(side * 0.28, 1.38 - drop * 0.6, -0.6), skin, Vector3(drop + 0.08, 0, 0), tag)
		k.sphere(0.065, Vector3(side * 0.28, 1.36 - drop * 0.8, -0.8), skin.darkened(0.1), Vector3.ONE, Vector3.ZERO, 6, 4, tag)

func _mesh_zombie_a() -> ArrayMesh:
	var k := MeshKit.new()
	_zombie_common(k, Color(0.5, 0.58, 0.42), Color(0.27, 0.33, 0.42), Color(0.22, 0.22, 0.26), Color(0.16, 0.12, 0.09), 0.22, 0.0)
	return k.build()

func _mesh_zombie_b() -> ArrayMesh:
	var k := MeshKit.new()
	_zombie_common(k, Color(0.58, 0.6, 0.46), Color(0.45, 0.32, 0.2), Color(0.36, 0.33, 0.28), Color(0.45, 0.44, 0.4), 0.35, 0.35)
	return k.build()

func _mesh_zombie_brute() -> ArrayMesh:
	var k := MeshKit.new()
	var skin := Color(0.46, 0.5, 0.4)
	var rag := Color(0.36, 0.18, 0.14)
	var pants := Color(0.24, 0.22, 0.2)
	var dark := Color(0.1, 0.09, 0.08)
	for side in [-1, 1]:
		var tag := 0.2 if side < 0 else 0.4
		k.box(Vector3(0.26, 0.84, 0.28), Vector3(side * 0.17, 0.46, 0.02), pants, Vector3.ZERO, tag)
		k.box(Vector3(0.24, 0.12, 0.34), Vector3(side * 0.17, 0.06, -0.04), dark, Vector3.ZERO, tag)
	k.box(Vector3(0.6, 0.26, 0.36), Vector3(0, 0.92, 0.02), pants, Vector3.ZERO, 0.0)
	k.box(Vector3(0.78, 0.66, 0.48), Vector3(0, 1.3, -0.08), skin, Vector3(-0.3, 0, 0), 0.0)
	k.box(Vector3(0.6, 0.4, 0.05), Vector3(0, 1.22, -0.33), rag, Vector3(-0.3, 0, 0.1), 0.0)
	k.box(Vector3(0.3, 0.18, 0.05), Vector3(0.14, 1.36, -0.37), Color(0.45, 0.07, 0.05), Vector3(-0.3, 0, -0.2), 0.0)
	k.sphere(0.13, Vector3(0, 1.66, -0.3), skin.darkened(0.1), Vector3(1.1, 0.95, 1.0), Vector3.ZERO, 10, 6, 0.0)
	k.box(Vector3(0.05, 0.025, 0.02), Vector3(-0.05, 1.68, -0.42), Color(0.95, 0.75, 0.3), Vector3.ZERO, 0.0)
	k.box(Vector3(0.05, 0.025, 0.02), Vector3(0.05, 1.68, -0.42), Color(0.95, 0.75, 0.3), Vector3.ZERO, 0.0)
	k.box(Vector3(0.12, 0.04, 0.02), Vector3(0, 1.6, -0.42), Color(0.25, 0.03, 0.03), Vector3.ZERO, 0.0)
	for side in [-1, 1]:
		var tag := 0.6 if side < 0 else 0.8
		k.box(Vector3(0.22, 0.22, 0.42), Vector3(side * 0.47, 1.38, -0.28), skin, Vector3(0.15, 0, 0), tag)
		k.box(Vector3(0.2, 0.2, 0.4), Vector3(side * 0.48, 1.28, -0.64), skin.darkened(0.05), Vector3(0.3, 0, 0), tag)
		k.sphere(0.13, Vector3(side * 0.48, 1.18, -0.88), skin.darkened(0.15), Vector3.ONE, Vector3.ZERO, 7, 4, tag)
	return k.build()

func _build_soldier(root: Node3D) -> void:
	var skin := Color(0.84, 0.64, 0.5)
	var uni := Color(0.33, 0.38, 0.24)
	var vest := Color(0.24, 0.28, 0.18)
	var body := MeshKit.new()
	body.box(Vector3(0.38, 0.2, 0.22), Vector3(0, 0.9, 0), uni.darkened(0.1))
	body.box(Vector3(0.42, 0.55, 0.25), Vector3(0, 1.2, 0), uni)
	body.box(Vector3(0.44, 0.36, 0.28), Vector3(0, 1.25, 0), vest)
	body.box(Vector3(0.3, 0.34, 0.16), Vector3(0, 1.22, 0.2), vest.darkened(0.15))
	body.cyl(0.06, 0.07, 0.1, Vector3(0, 1.52, 0), skin)
	body.sphere(0.13, Vector3(0, 1.64, 0), skin)
	body.sphere(0.16, Vector3(0, 1.67, 0), uni.darkened(0.05), Vector3(1, 0.85, 1.05), Vector3.ZERO, 12, 4, 1.0, true)
	body.cyl(0.19, 0.19, 0.02, Vector3(0, 1.66, 0), uni.darkened(0.15), Vector3.ZERO, 12)
	_mi(body.build(), mat_vc, root, "Body")
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side * 0.1, 0.86, 0)
		root.add_child(leg)
		var lk := MeshKit.new()
		lk.box(Vector3(0.15, 0.8, 0.17), Vector3(0, -0.42, 0), uni.darkened(0.08))
		lk.box(Vector3(0.16, 0.12, 0.27), Vector3(0, -0.82, -0.04), Color(0.12, 0.1, 0.08))
		_mi(lk.build(), mat_vc, leg)
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side * 0.27, 1.43, 0)
		root.add_child(arm)
		var ak := MeshKit.new()
		ak.box(Vector3(0.12, 0.34, 0.13), Vector3(0, -0.15, 0), uni)
		ak.box(Vector3(0.1, 0.3, 0.1), Vector3(0, -0.45, 0), uni.darkened(0.05))
		ak.sphere(0.055, Vector3(0, -0.63, 0), skin)
		if side > 0:
			ak.box(Vector3(0.06, 0.95, 0.08), Vector3(-0.12, -0.62, -0.05), Color(0.16, 0.15, 0.13))
			ak.box(Vector3(0.07, 0.25, 0.12), Vector3(-0.12, -0.3, -0.03), C_WOOD_DK)
		_mi(ak.build(), mat_vc, arm)

func _mesh_mortar_base() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.95, 1.0, 0.1, Vector3(0, 0.05, 0), C_DIRT.darkened(0.1), Vector3.ZERO, 16)
	var n := 11
	for i in n:
		var a := float(i) / n * TAU
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.35:
			continue
		var p := Vector3(cos(a) * 0.86, 0.2, sin(a) * 0.86)
		k.capsule(0.15, 0.55, p, C_SAND, Vector3(0, PI * 0.5 - a, PI * 0.5), Vector3(0.8, 1, 1))
	k.cyl(0.32, 0.36, 0.06, Vector3(0, 0.13, 0), C_METAL, Vector3.ZERO, 12)
	k.box(Vector3(0.4, 0.22, 0.28), Vector3(0.45, 0.21, 0.42), C_OLIVE)
	k.box(Vector3(0.4, 0.22, 0.28), Vector3(-0.45, 0.21, 0.45), C_OLIVE, Vector3(0, 0.4, 0))
	for i in 3:
		k.cyl(0.045, 0.045, 0.3, Vector3(0.62 - i * 0.1, 0.25, -0.5), C_OLIVE_LT, Vector3(0.2, 0, 0), 6)
	return k.build()

func _mesh_mortar_yaw() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.1, 0.14, 0.12, Vector3(0, 0.06, 0.12), C_METAL, Vector3.ZERO, 10)
	k.cyl(0.02, 0.02, 0.62, Vector3(0.18, 0.28, -0.32), C_METAL, Vector3(0.45, 0, -0.3), 6)
	k.cyl(0.02, 0.02, 0.62, Vector3(-0.18, 0.28, -0.32), C_METAL, Vector3(0.45, 0, 0.3), 6)
	k.box(Vector3(0.38, 0.04, 0.04), Vector3(0, 0.52, -0.42), C_METAL)
	return k.build()

func _mesh_mortar_tube() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.075, 0.08, 1.05, Vector3(0, 0, -0.5), C_OLIVE.darkened(0.2), Vector3(PI * 0.5, 0, 0), 10)
	k.cyl(0.09, 0.09, 0.08, Vector3(0, 0, -1.0), C_METAL, Vector3(PI * 0.5, 0, 0), 10)
	k.sphere(0.1, Vector3(0, 0, 0.02), C_METAL)
	return k.build()

func _mesh_sniper_tower() -> ArrayMesh:
	var k := MeshKit.new()
	var wood := C_WOOD
	var h := 4.2
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			k.cyl(0.08, 0.1, h, Vector3(cx * 0.7, h * 0.5, cz * 0.7), wood.darkened(0.1), Vector3.ZERO, 6)
			k.cyl(0.05, 0.05, 1.9, Vector3(cx * 0.7, h + 0.95, cz * 0.7), wood, Vector3.ZERO, 5)
	for cz in [-1, 1]:
		k.box(Vector3(0.06, 2.0, 0.06), Vector3(0, 1.4, cz * 0.7), wood, Vector3(0, 0, 0.62))
		k.box(Vector3(0.06, 2.0, 0.06), Vector3(0, 2.9, cz * 0.7), wood, Vector3(0, 0, -0.62))
	for cx in [-1, 1]:
		k.box(Vector3(0.06, 2.0, 0.06), Vector3(cx * 0.7, 1.4, 0), wood, Vector3(0.62, 0, 0))
		k.box(Vector3(0.06, 2.0, 0.06), Vector3(cx * 0.7, 2.9, 0), wood, Vector3(-0.62, 0, 0))
	k.box(Vector3(1.95, 0.14, 1.95), Vector3(0, h + 0.07, 0), C_WOOD_DK)
	k.box(Vector3(1.9, 0.06, 0.06), Vector3(0, h + 0.75, 0.93), wood)
	k.box(Vector3(1.9, 0.06, 0.06), Vector3(0, h + 0.75, -0.93), wood)
	k.box(Vector3(0.06, 0.06, 1.9), Vector3(0.93, h + 0.75, 0), wood)
	k.box(Vector3(0.06, 0.06, 1.9), Vector3(-0.93, h + 0.75, 0), wood)
	for i in 4:
		k.capsule(0.12, 0.45, Vector3(-0.66 + i * 0.44, h + 0.28, -0.82), C_SAND, Vector3(0, 0, PI * 0.5), Vector3(0.8, 1, 1))
	k.cyl(0.0, 1.55, 0.7, Vector3(0, h + 2.2, 0), C_OLIVE.darkened(0.15), Vector3(0, PI * 0.25, 0), 4)
	for sx in [-1, 1]:
		k.box(Vector3(0.05, h, 0.05), Vector3(sx * 0.22, h * 0.5, 0.98), wood)
	for i in 11:
		k.box(Vector3(0.44, 0.04, 0.04), Vector3(0, 0.3 + i * 0.36, 0.98), wood.darkened(0.1))
	return k.build()

func _mesh_garrison() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(1.82, 1.95, 1.9, Vector3(0, 0.95, 0), C_CONCRETE, Vector3(0, PI / 8.0, 0), 8)
	k.cyl(2.02, 2.02, 0.3, Vector3(0, 2.05, 0), C_CONCRETE_DK, Vector3(0, PI / 8.0, 0), 8)
	k.cyl(1.2, 1.6, 0.25, Vector3(0, 2.3, 0), C_CONCRETE.darkened(0.05), Vector3(0, PI / 8.0, 0), 8)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5 + PI
		var p := Vector3(sin(a) * 1.85, 1.35, cos(a) * 1.85)
		k.box(Vector3(0.9, 0.2, 0.14), p, C_DARK, Vector3(0, a, 0))
	k.box(Vector3(0.9, 1.4, 0.12), Vector3(0, 0.7, 1.85), C_METAL)
	for i in 7:
		var a2 := PI + (i - 3) * 0.32
		k.capsule(0.17, 0.6, Vector3(sin(a2) * 2.05, 0.18, cos(a2) * 2.05), C_SAND, Vector3(0, a2 + PI * 0.5, PI * 0.5), Vector3(0.8, 1, 1))
	return k.build()

func _mesh_wire() -> ArrayMesh:
	var k := MeshKit.new()
	var wood := C_WOOD.darkened(0.1)
	for sx in [-1, 1]:
		k.box(Vector3(0.07, 1.2, 0.07), Vector3(sx * 0.82, 0.45, 0), wood, Vector3(0.62, 0, 0))
		k.box(Vector3(0.07, 1.2, 0.07), Vector3(sx * 0.82, 0.45, 0), wood, Vector3(-0.62, 0, 0))
	k.cyl(0.035, 0.035, 1.75, Vector3(0, 0.62, 0), wood, Vector3(0, 0, PI * 0.5), 6)
	for i in 6:
		var t := TorusMesh.new()
		t.inner_radius = 0.33
		t.outer_radius = 0.36
		t.rings = 14
		t.ring_segments = 4
		k.add_mesh(t, MeshKit.xf_at(Vector3(-0.68 + i * 0.27, 0.42, 0), Vector3(0.25 * (i % 2), 0, PI * 0.5)), C_WIRE.lightened(0.15))
	return k.build()

func _mesh_flame_base() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(1.85, 0.85, 1.85), Vector3(0, 0.425, 0), C_CONCRETE)
	k.box(Vector3(1.55, 0.18, 1.55), Vector3(0, 0.94, 0), C_CONCRETE_DK)
	for i in 5:
		k.box(Vector3(0.18, 0.12, 0.02), Vector3(-0.72 + i * 0.36, 0.65, -0.935), Color(0.95, 0.75, 0.1) if i % 2 == 0 else C_DARK)
	k.box(Vector3(0.3, 0.3, 0.6), Vector3(0.7, 0.15, 0.8), Color(0.6, 0.15, 0.1))
	return k.build()

func _mesh_flame_yaw() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(0.48, Vector3(0, 0.0, 0), C_OLIVE, Vector3(1, 0.8, 1), Vector3.ZERO, 12, 5, 1.0, true)
	k.cyl(0.08, 0.1, 0.85, Vector3(0, 0.16, -0.55), C_METAL, Vector3(PI * 0.5, 0, 0), 8)
	k.cyl(0.12, 0.12, 0.12, Vector3(0, 0.16, -0.95), C_DARK, Vector3(PI * 0.5, 0, 0), 8)
	for sx in [-1, 1]:
		k.cyl(0.15, 0.15, 0.6, Vector3(sx * 0.22, 0.22, 0.45), Color(0.65, 0.15, 0.1), Vector3.ZERO, 10)
		k.sphere(0.15, Vector3(sx * 0.22, 0.52, 0.45), Color(0.65, 0.15, 0.1), Vector3.ONE, Vector3.ZERO, 10, 4, 1.0, true)
	return k.build()

func _mesh_concrete_wall() -> ArrayMesh:
	var k := MeshKit.new()
	var c := C_CONCRETE.lightened(0.05)
	k.box(Vector3(2.0, 3.3, 0.7), Vector3(0, 1.65, 0), c)
	k.box(Vector3(2.0, 0.25, 0.9), Vector3(0, 0.12, 0), C_CONCRETE_DK)
	k.box(Vector3(2.0, 0.18, 0.8), Vector3(0, 3.38, 0), C_CONCRETE_DK)
	for x in [-0.5, 0.5]:
		k.box(Vector3(0.04, 3.1, 0.72), Vector3(x, 1.7, 0), C_CONCRETE_DK.lightened(0.05))
	k.box(Vector3(2.0, 0.05, 0.72), Vector3(0, 1.2, 0), C_CONCRETE_DK.lightened(0.08))
	k.box(Vector3(2.0, 0.05, 0.72), Vector3(0, 2.4, 0), C_CONCRETE_DK.lightened(0.08))
	return k.build()

func _mesh_post_wood() -> ArrayMesh:
	var k := MeshKit.new()
	k.cyl(0.34, 0.38, 2.5, Vector3(0, 1.25, 0), C_WOOD.darkened(0.1), Vector3.ZERO, 10)
	k.cyl(0.0, 0.36, 0.3, Vector3(0, 2.65, 0), C_WOOD_DK, Vector3.ZERO, 10)
	k.cyl(0.4, 0.4, 0.06, Vector3(0, 0.9, 0), C_WIRE, Vector3.ZERO, 10)
	k.cyl(0.4, 0.4, 0.06, Vector3(0, 1.8, 0), C_WIRE, Vector3.ZERO, 10)
	return k.build()

func _mesh_post_concrete() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(1.0, 3.8, 1.0), Vector3(0, 1.9, 0), C_CONCRETE)
	k.box(Vector3(1.15, 0.2, 1.15), Vector3(0, 3.85, 0), C_CONCRETE_DK)
	k.box(Vector3(1.15, 0.3, 1.15), Vector3(0, 0.15, 0), C_CONCRETE_DK)
	return k.build()

func _mesh_gate_frame() -> ArrayMesh:
	var k := MeshKit.new()
	for sx in [-1, 1]:
		k.box(Vector3(0.3, 3.6, 0.9), Vector3(sx * 2.05, 1.8, 0), C_CONCRETE)
	k.box(Vector3(4.4, 0.35, 0.9), Vector3(0, 3.55, 0), C_CONCRETE_DK)
	k.box(Vector3(1.0, 0.18, 0.05), Vector3(0, 3.55, -0.46), Color(0.95, 0.75, 0.1))
	return k.build()

func _mesh_gate_leaf(side: int) -> ArrayMesh:
	var k := MeshKit.new()
	var w := 1.88
	var cx := -side * w * 0.5
	k.box(Vector3(w, 3.1, 0.14), Vector3(cx, 1.65, 0), C_OLIVE.darkened(0.25))
	for y in [0.5, 1.65, 2.8]:
		k.box(Vector3(w, 0.12, 0.2), Vector3(cx, y, 0), C_METAL)
	k.box(Vector3(0.12, 3.1, 0.2), Vector3(cx - side * (w * 0.5 - 0.06), 1.65, 0), C_METAL)
	k.box(Vector3(w * 0.9, 0.12, 0.16), Vector3(cx, 1.65, 0), C_METAL, Vector3(0, 0, side * 0.95))
	return k.build()

func _build_civilian(root: Node3D, b: bool) -> void:
	var skin := Color(0.84, 0.64, 0.5) if not b else Color(0.55, 0.4, 0.3)
	var top := Color(0.55, 0.25, 0.22) if not b else Color(0.3, 0.45, 0.6)
	var legs := Color(0.25, 0.3, 0.42) if not b else Color(0.4, 0.36, 0.3)
	var body := MeshKit.new()
	body.box(Vector3(0.36, 0.2, 0.22), Vector3(0, 0.9, 0), legs)
	body.box(Vector3(0.4, 0.55, 0.24), Vector3(0, 1.2, 0), top)
	body.cyl(0.06, 0.07, 0.1, Vector3(0, 1.52, 0), skin)
	body.sphere(0.13, Vector3(0, 1.64, 0), skin)
	body.sphere(0.14, Vector3(0, 1.69, 0.01), Color(0.2, 0.14, 0.1) if not b else Color(0.08, 0.06, 0.05), Vector3(1, 0.7, 1.05), Vector3.ZERO, 10, 4, 1.0, true)
	if b:
		body.box(Vector3(0.28, 0.32, 0.12), Vector3(0, 1.2, 0.18), Color(0.25, 0.25, 0.2))
	_mi(body.build(), mat_vc, root, "Body")
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side * 0.1, 0.86, 0)
		root.add_child(leg)
		var lk := MeshKit.new()
		lk.box(Vector3(0.14, 0.8, 0.16), Vector3(0, -0.42, 0), legs)
		lk.box(Vector3(0.15, 0.09, 0.25), Vector3(0, -0.82, -0.04), Color(0.15, 0.12, 0.1))
		_mi(lk.build(), mat_vc, leg)
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side * 0.26, 1.43, 0)
		root.add_child(arm)
		var ak := MeshKit.new()
		ak.box(Vector3(0.11, 0.34, 0.12), Vector3(0, -0.15, 0), top)
		ak.box(Vector3(0.09, 0.3, 0.09), Vector3(0, -0.45, 0), skin)
		_mi(ak.build(), mat_vc, arm)

func _mesh_ammo_crate() -> ArrayMesh:
	var k := MeshKit.new()
	k.box(Vector3(0.55, 0.3, 0.32), Vector3(0, 0, 0), C_OLIVE)
	k.box(Vector3(0.57, 0.04, 0.34), Vector3(0, 0.1, 0), C_OLIVE.darkened(0.2))
	k.box(Vector3(0.2, 0.06, 0.02), Vector3(0, 0.0, -0.17), Color(0.95, 0.8, 0.2))
	return k.build()

func ruin_mesh(variant: int) -> ArrayMesh:
	return _cached("ruin%d" % variant, func(): return _make_ruin(variant))

func _make_ruin(variant: int) -> ArrayMesh:
	var k := MeshKit.new()
	var r := RandomNumberGenerator.new()
	r.seed = 900 + variant
	var brick := Color(0.55, 0.42, 0.35)
	k.box(Vector3(5.5, 2.6, 0.4), Vector3(0, 1.3, -2.6), brick)
	k.box(Vector3(2.2, 1.4, 0.4), Vector3(-1.6, 0.7, 2.6), brick.darkened(0.1))
	k.box(Vector3(0.4, 2.0, 4.8), Vector3(-2.75, 1.0, 0), brick)
	k.box(Vector3(0.4, 1.0, 2.2), Vector3(2.75, 0.5, -1.2), brick.darkened(0.15))
	for i in 9:
		var p := Vector3(r.randf_range(-2.2, 2.2), 0.15, r.randf_range(-2.0, 2.0))
		k.box(Vector3(r.randf_range(0.3, 0.8), r.randf_range(0.15, 0.4), r.randf_range(0.3, 0.7)), p, brick.lerp(C_CONCRETE, r.randf()), Vector3(0, r.randf() * TAU, r.randf_range(-0.3, 0.3)))
	var car := Color(0.22, 0.18, 0.16)
	k.box(Vector3(1.8, 0.7, 4.0), Vector3(4.6, 0.55, 1.2), car, Vector3(0, 0.4, 0))
	k.box(Vector3(1.6, 0.6, 2.0), Vector3(4.6, 1.15, 1.1), car.darkened(0.2), Vector3(0, 0.4, 0))
	return k.build()

func tree_mesh(variant: int) -> ArrayMesh:
	return _cached("tree%d" % variant, func(): return _make_tree(variant))

func _make_tree(variant: int) -> ArrayMesh:
	var k := MeshKit.new()
	var r := RandomNumberGenerator.new()
	r.seed = 100 + variant
	if variant == 2:
		var bark := Color(0.32, 0.27, 0.22)
		k.cyl(0.1, 0.2, 3.4, Vector3(0, 1.7, 0), bark, Vector3(0.05, 0, 0.04), 7)
		for i in 4:
			var a := i * 1.7
			var y := 1.8 + i * 0.4
			k.cyl(0.03, 0.07, 1.3, Vector3(cos(a) * 0.45, y + 0.3, sin(a) * 0.45), bark, Vector3(sin(a) * 0.8, 0, -cos(a) * 0.8), 5)
		return k.build()
	var trunk := Color(0.33, 0.23, 0.15)
	var g1 := Color(0.16, 0.25, 0.14) if variant == 0 else Color(0.2, 0.27, 0.13)
	k.cyl(0.11, 0.17, 1.6, Vector3(0, 0.8, 0), trunk, Vector3.ZERO, 7)
	var y := 1.5
	var rad := 1.55
	for i in 4:
		var h := 1.7 - i * 0.2
		k.cyl(0.0, rad, h, Vector3(r.randf_range(-0.05, 0.05), y + h * 0.5, r.randf_range(-0.05, 0.05)), g1.lightened(i * 0.05).darkened(r.randf() * 0.08), Vector3(0, r.randf() * TAU, 0), 8)
		y += h * 0.55
		rad *= 0.74
	return k.build()

func rock_mesh(variant: int) -> ArrayMesh:
	return _cached("rock%d" % variant, func(): return _make_rock(variant))

func _make_rock(variant: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 9
	sm.rings = 6
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nz := FastNoiseLite.new()
	nz.seed = 300 + variant
	nz.frequency = 0.9
	var sc: Vector3 = [Vector3(1.0, 0.7, 0.85), Vector3(0.8, 0.55, 1.1), Vector3(1.2, 0.9, 1.0)][variant % 3]
	var disp := PackedVector3Array()
	disp.resize(v.size())
	for i in v.size():
		var p := v[i]
		var d := 1.0 + nz.get_noise_3dv(p * 1.3) * 0.35
		var q := p * d * sc
		q.y = maxf(q.y, -0.25)
		disp[i] = q
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var base := Color(0.46, 0.44, 0.4).lerp(Color(0.5, 0.45, 0.37), variant * 0.3)
	for t in range(0, ind.size(), 3):
		var a := disp[ind[t]]
		var b := disp[ind[t + 1]]
		var c := disp[ind[t + 2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot((a + b + c) / 3.0) < 0.0:
			n = -n
		var shade := 0.85 + 0.15 * clampf(n.y, 0.0, 1.0)
		var col := Color(base.r * shade, base.g * shade, base.b * shade)
		if n.y > 0.75:
			col = col.lerp(Color(0.33, 0.38, 0.2), 0.45)
		for p in [a, b, c]:
			verts.append(p)
			norms.append(n)
			cols.append(col)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am
