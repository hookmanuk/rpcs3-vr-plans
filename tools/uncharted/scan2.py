import glob, os, re, collections
known={'8a04b99b','fe99f21a','0d90d5b9','5fb447d7','5d941826','a74ece03','f4a633e3','7c219ffb','43b8ee5e','661db47f','84adaaea','f2fab535'}
assign=re.compile(r'^\s*(?:precise )?(?:float|vec[234]|uint|int|bool|uvec[234]) (_\d+) = (.*);\s*$')
out=[]
for f in glob.glob(r'H:\uc_tests\spv7\*.glsl'):
    t=open(f,errors='ignore').read()
    screen_src = 'gl_FragCoord' if 'gl_FragCoord' in t else ('gl_GlobalInvocationID' if 'gl_GlobalInvocationID' in t else None)
    if not screen_src: continue
    h=os.path.basename(f)[10:18]; lines=[assign.match(l) for l in t.split('\n')]; lines=[m for m in lines if m]
    screen=set(); depth=set(); z=set(); pos=set(); attr_used=False; world_rows=0; ray=[]
    for m in lines:
        v,e=m.group(1),m.group(2); deps=set(re.findall(r'\b_\d+\b',e))
        tex=re.search(r'\b(texture\w*|imageLoad|texelFetch)\(',e)
        if tex:
            # a texture read addressed by the screen position: a candidate depth
            if deps&screen or screen_src in e: depth.add(v)
            continue
        if screen_src in e or deps&screen: screen.add(v)
        if deps&depth and not deps&screen: depth.add(v) if re.search(r' [-+] ',e) and '/' not in e else None
        # z: reciprocal of the depth term
        if re.search(r'1\.0 / ',e) and deps&depth: z.add(v)
        elif deps&z and '*' in e and not deps&screen and not deps&pos: z.add(v)
        p=re.match(r'^(_\d+) \* (_\d+)$',e)
        if p and ((p.group(1) in z and p.group(2) in screen) or (p.group(2) in z and p.group(1) in screen)):
            pos.add(v); ray.append(v); continue
        if deps&pos:
            pos.add(v)
            if 'fs_in_attr' in e or re.search(r'fma\(',e): attr_used=True
    if len(ray)>=1:
        kind='decal(per-vertex)' if attr_used else 'constants'
        n=sum(1 for m in lines if set(re.findall(r'\b_\d+\b',m.group(2)))&pos)
        out.append((h,'known' if h in known else 'NEW','FS' if screen_src=='gl_FragCoord' else 'CS',kind,len(ray),n))
out.sort(key=lambda r:(r[1],r[3],-r[5]))
print(len(out))
for r in out: print(*r)
