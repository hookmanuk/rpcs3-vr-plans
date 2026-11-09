import glob, os, subprocess, concurrent.futures as cf
C=r'H:\uncharted_pc\user\cache'; O=r'H:\uc_tests\spv7'; os.makedirs(O,exist_ok=True)
seen={}
for d in sorted(glob.glob(C+r'\CUSA02343-nan1_mv7*'))+sorted(glob.glob(C+r'\CUSA02343-nan1_mv6*'))+sorted(glob.glob(C+r'\CUSA02343-nan1_mv5*')):
    for f in glob.glob(d+r'\*.spv'):
        seen.setdefault(os.path.basename(f),f)
def go(kv):
    b,f=kv; o=os.path.join(O,b[:-4]+'.glsl')
    if os.path.exists(o) and os.path.getsize(o)>200: return 0
    with open(o,'w') as h: subprocess.run([r'C:\VulkanSDK\1.4.341.1\Bin\spirv-cross.exe','--vulkan-semantics',f],stdout=h,stderr=subprocess.DEVNULL)
    return 1
with cf.ThreadPoolExecutor(6) as e: n=sum(e.map(go,seen.items()))
print('unique',len(seen),'new',n)
