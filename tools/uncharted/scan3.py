import glob, os, re
# Wider net: shaders that read a screen-addressed image and later divide by a term built from that read,
# then multiply the result by something screen-derived (a point rebuilt some other way, e.g. an inverse matrix).
done={'8a04b99b','fe99f21a','0d90d5b9','5fb447d7','5d941826','a74ece03','f4a633e3','7c219ffb','43b8ee5e','661db47f','84adaaea','f2fab535','14e3079b','6aed7ebb','71165e3f','b1386ddc','75132665','69de1134'}
assign=re.compile(r'^\s*(?:precise )?(?:float|vec[234]|uint|int|bool|uvec[234]) (_\d+) = (.*);\s*$')
out=[]
for f in glob.glob(r'H:\uc_tests\spv7\*.glsl'):
    t=open(f,errors='ignore').read(); h=os.path.basename(f)[10:18]
    if h in done: continue
    src=[s for s in ('gl_FragCoord','gl_GlobalInvocationID','gl_WorkGroupID') if s in t]
    if not src: continue
    screen=set(); dep=set(); rec=set(); hits=0; names=[]
    for l in t.split('\n'):
        m=assign.match(l)
        if not m: continue
        v,e=m.groups(); d=set(re.findall(r'\b_\d+\b',e))
        if re.search(r'\b(texture\w*|imageLoad|texelFetch)\(',e):
            if d&screen or any(s in e for s in src): dep.add(v)
            continue
        if any(s in e for s in src) or (d&screen and not d&rec and not d&dep): screen.add(v)
        if d&dep: dep.add(v)
        if re.search(r'(1\.0 / |inversesqrt)',e) and d&dep: rec.add(v)
        elif d&rec and '*' in e:
            if d&screen: hits+=1; names.append(v)
            rec.add(v)
    if hits>=2: out.append((hits,h,'FS' if 'gl_FragCoord' in src else 'CS'))
out.sort(reverse=True); print(len(out)); print(out[:40])
