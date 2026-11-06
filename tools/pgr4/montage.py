"""montage.py OUT.png W IN1 IN2 ...: side by side at width W each."""
import sys
from PIL import Image
out,w,*ins=sys.argv[1:]; w=int(w)
ims=[Image.open(p).convert('RGB') for p in ins]
ims=[i.resize((w,i.height*w//i.width)) for i in ims]
m=Image.new('RGB',(w*len(ims),max(i.height for i in ims)))
for k,i in enumerate(ims): m.paste(i,(k*w,0))
m.save(out)
