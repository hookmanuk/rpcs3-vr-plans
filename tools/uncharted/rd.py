import sys; sys.path.insert(0, r'H:\uncharted_pc\tools\vr'); import memscan, struct, time
a=0xb500000+0xf2f364
for i in range(int(sys.argv[1]) if len(sys.argv)>1 else 1):
    print(struct.unpack('<I', memscan.read(a,4))[0], end=' ', flush=True); time.sleep(0.25)
print()
