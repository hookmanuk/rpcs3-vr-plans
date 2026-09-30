import sys
from PIL import Image
outs=[]
for n in sys.argv[2:]:
    b=Image.open(n+'.full.png'); Bw=b.width//2; H=b.height
    box=(int(Bw*0.3),int(H*0.35),int(Bw*0.95),int(H*0.62))
    o=Image.new('RGB',(1000,260))
    for e in (0,1): o.paste(b.crop((e*Bw+box[0],box[1],e*Bw+box[2],box[3])).resize((500,260)),(500*e,0))
    outs.append(o)
O=Image.new('RGB',(1000,260*len(outs))); [O.paste(o,(0,260*i)) for i,o in enumerate(outs)]; O.save(sys.argv[1])
