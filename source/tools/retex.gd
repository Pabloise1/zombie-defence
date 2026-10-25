extends SceneTree
# Re-encodes the game's textures for phones: decode each .ctex, cap it at
# MAX px, rebuild mipmaps and compress to ETC2. Writes one raw dump per
# texture (w, h, mipmaps, format, data) for tools/write_ctex.py to wrap.
# Normal and ORM maps get MAX_DETAIL px: their fine detail doesn't show from
# the game camera. Run headless with the editor binary:
# LIST=ctex_list.txt OUT=dir MAX=512 MAX_DETAIL=256
func _init():
	var max_px := int(OS.get_environment("MAX")) if OS.get_environment("MAX") != "" else 512
	var max_detail := int(OS.get_environment("MAX_DETAIL")) if OS.get_environment("MAX_DETAIL") != "" else 256
	var out_dir := OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(OS.get_environment("LIST"), FileAccess.READ)
	var n := 0
	while not f.eof_reached():
		var p := f.get_line().strip_edges()
		if p == "":
			continue
		var tex := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if tex == null:
			print("RETEX skip ", p)
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		var name := p.get_file()
		var detail := name.contains("_normal") or name.contains("_orm")
		var w := img.get_width()
		var h := img.get_height()
		var k := maxf(1.0, maxf(w, h) / float(max_detail if detail else max_px))
		if k > 1.0:
			img.resize(int(w / k), int(h / k), Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		var src := Image.COMPRESS_SOURCE_GENERIC
		if name.contains("_normal"):
			src = Image.COMPRESS_SOURCE_NORMAL
		elif name.contains("_color") or name.contains("albedo"):
			src = Image.COMPRESS_SOURCE_SRGB
		var err := img.compress(Image.COMPRESS_ETC2, src)
		if err != OK:
			print("RETEX compress failed ", p)
			continue
		var o := FileAccess.open(out_dir + "/" + name + ".raw", FileAccess.WRITE)
		o.store_32(img.get_width())
		o.store_32(img.get_height())
		o.store_32(img.get_mipmap_count())
		o.store_32(img.get_format())
		o.store_buffer(img.get_data())
		o.close()
		n += 1
	print("RETEX done ", n)
	quit()
