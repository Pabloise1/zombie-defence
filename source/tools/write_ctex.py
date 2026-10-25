"""Wrap tools/retex.gd dumps as Godot .ctex files (raw image data).

usage: python3 write_ctex.py index.pck retex_dir out_dir
Writes out_dir/.godot/imported/<name>.ctex for every dump, keeping each
original texture's header flags. Pass out_dir to repack.py as overrides.
"""
import os, struct, sys
pck, raw_dir, out_dir = sys.argv[1:4]
f = open(pck, 'rb')
fb, do = struct.unpack('<QQ', (f.seek(24), f.read(16))[1])
f.seek(do)
n, = struct.unpack('<I', f.read(4))
ents = {}
for i in range(n):
    l, = struct.unpack('<I', f.read(4)); p = f.read(l).rstrip(b'\0').decode()
    off, size = struct.unpack('<QQ', f.read(16)); f.read(20)
    ents[p] = (off, size)
DATA_FORMAT_IMAGE = 0
done = 0
for fn in sorted(os.listdir(raw_dir)):
    name = fn[:-len('.raw')]
    path = '.godot/imported/' + name
    off, size = ents[path]
    f.seek(fb + off); old = f.read(36)
    assert old[:4] == b'GST2', path
    ver, ow, oh, flags, limit = struct.unpack('<IIIIi', old[4:24])
    d = open(os.path.join(raw_dir, fn), 'rb').read()
    w, h, mips, fmt = struct.unpack('<4I', d[:16])
    hdr = b'GST2' + struct.pack('<IIIIi', ver, w, h, flags, limit) + b'\0' * 12
    body = struct.pack('<IHHII', DATA_FORMAT_IMAGE, w, h, mips, fmt) + d[16:]
    dst = os.path.join(out_dir, path)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'wb').write(hdr + body)
    done += 1
print('wrote', done, 'ctex files')
