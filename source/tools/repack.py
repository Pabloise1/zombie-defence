"""Repack index.pck with the text .gd scripts from a source dir.

Every .gd under src_dir replaces the matching script in the pack (whether the
pack holds it compiled as .gdc + .gd.remap, or already as text). Godot loads
text scripts fine at runtime, so no editor or export templates are needed.

usage: python3 repack.py index.pck ../ new.pck"""
import struct, sys, os, hashlib
orig, src, out = sys.argv[1:4]
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
files = []
for p, off, size, fl in es:
    if p.endswith('.gdc') and p[:-1] in gd: continue
    if p.endswith('.gd.remap') and p[:-6] in gd: continue
    if p in gd: continue
    f.seek(fb + off); files.append((p, f.read(size), fl))
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
