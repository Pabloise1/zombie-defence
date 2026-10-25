"""Repack index.pck with the text .gd scripts from a source dir.

Every .gd under src_dir replaces the matching script in the pack (whether the
pack holds it compiled as .gdc + .gd.remap, or already as text). Godot loads
text scripts fine at runtime, so no editor or export templates are needed.

Optional 4th argument: a folder of replacement files laid out by pack path
(e.g. overrides/.godot/imported/x.ctex), which replace those files as-is.

usage: python3 repack.py index.pck ../ new.pck [overrides_dir]"""
import struct, sys, os, hashlib
orig, src, out = sys.argv[1:4]
over_dir = sys.argv[4] if len(sys.argv) > 4 else None
f = open(orig, 'rb')
hdr = bytearray(f.read(112))
fb, do = struct.unpack('<QQ', hdr[24:40])
f.seek(do); n, = struct.unpack('<I', f.read(4)); es = []
for i in range(n):
    l, = struct.unpack('<I', f.read(4)); p = f.read(l).rstrip(b'\0').decode()
    off, size = struct.unpack('<QQ', f.read(16)); f.read(16); fl, = struct.unpack('<I', f.read(4))
    es.append((p, off, size, fl))
gd = {}
for root, dirs, files in os.walk(src):
    dirs[:] = [d for d in dirs if d != 'tools']  # dev scripts, not game code
    for fn in files:
        if fn.endswith('.gd'):
            rel = os.path.relpath(os.path.join(root, fn), src).replace(os.sep, '/')
            gd[rel] = open(os.path.join(root, fn), 'rb').read()
over = {}
if over_dir:
    for root, _, fs in os.walk(over_dir):
        for fn in fs:
            full = os.path.join(root, fn)
            over[os.path.relpath(full, over_dir).replace(os.sep, '/')] = open(full, 'rb').read()
files = []
for p, off, size, fl in es:
    if p in over:
        files.append((p, over.pop(p), fl))
        continue
    if p.endswith('.gdc') and p[:-1] in gd: continue
    if p.endswith('.gd.remap') and p[:-6] in gd: continue
    if p in gd: continue
    f.seek(fb + off); files.append((p, f.read(size), fl))
assert not over, 'overrides not in the pack: %s' % sorted(over)[:5]

# New class_name scripts must be listed in the global class cache, which the
# editor normally writes on export. Add any that are missing.
import re
CACHE = '.godot/global_script_class_cache.cfg'
for i, (p, data, fl) in enumerate(files):
    if p != CACHE:
        continue
    txt = data.decode('utf-8')
    known = set(re.findall(r'"class": &"(\w+)"', txt))
    add = []
    for rel, code in sorted(gd.items()):
        m = re.search(r'^class_name\s+(\w+)', code.decode('utf-8'), re.M)
        if not m or m.group(1) in known:
            continue
        base = re.search(r'^extends\s+(\w+)', code.decode('utf-8'), re.M)
        add.append('{\n"base": &"%s",\n"class": &"%s",\n"icon": "",\n"is_abstract": false,\n"is_tool": false,\n"language": &"GDScript",\n"path": "res://%s"\n}' % (base.group(1) if base else 'RefCounted', m.group(1), rel))
    if add:
        k = txt.rindex('}]')
        txt = txt[:k + 1] + ', ' + ', '.join(add) + txt[k + 1:]
        files[i] = (p, txt.encode('utf-8'), fl)
        print('class cache: added', len(add))
for rel, data in sorted(gd.items()):
    files.append((rel, data, 0))
o = open(out, 'wb'); o.write(hdr)
dirents = []
for p, data, fl in files:
    pos = o.tell(); o.write(data); o.write(b'\0' * ((16 - len(data) % 16) % 16))
    dirents.append((p, pos - fb, len(data), hashlib.md5(data).digest(), fl))
dpos = o.tell()
o.write(struct.pack('<I', len(dirents)))
for p, off, size, md5, fl in dirents:
    pb = p.encode(); pb += b'\0' * (4 - len(pb) % 4 if len(pb) % 4 else 0)
    o.write(struct.pack('<I', len(pb)) + pb + struct.pack('<QQ', off, size) + md5 + struct.pack('<I', fl))
o.seek(32); o.write(struct.pack('<Q', dpos)); o.close()
print('wrote', out, len(dirents), 'files; replaced', len(gd), 'scripts')
