import struct, sys, os
f=open(sys.argv[1],'rb'); out=sys.argv[2]
magic,ver,ma,mi,pa,flags=struct.unpack('<4s5I',f.read(24))
file_base,dir_off=struct.unpack('<QQ',f.read(16))
print(ver,ma,mi,pa,flags,file_base,dir_off)
f.seek(dir_off)
n,=struct.unpack('<I',f.read(4))
entries=[]
for i in range(n):
    l,=struct.unpack('<I',f.read(4)); p=f.read(l).rstrip(b'\0').decode()
    off,size=struct.unpack('<QQ',f.read(16)); md5=f.read(16); fl,=struct.unpack('<I',f.read(4))
    entries.append((p,off,size,fl))
for p,off,size,fl in entries:
    if sys.argv[3:] and not any(s in p for s in sys.argv[3:]): continue
    print(p,size,fl)
    f.seek(file_base+off); data=f.read(size)
    dst=os.path.join(out,p.replace('res://',''))
    os.makedirs(os.path.dirname(dst),exist_ok=True); open(dst,'wb').write(data)
