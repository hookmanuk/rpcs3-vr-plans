import sys
from PIL import Image
r=sys.argv[1]
im=Image.new('RGB',(960,5*140))
for i in range(1,6):
    a=Image.open(f'p{r}_{i}.png')
    t=a.crop((760,10,960,60)).resize((400,100)); s=a.crop((290,420,670,540)).resize((380,120))
    im.paste(t,(0,(i-1)*140)); im.paste(s,(420,(i-1)*140))
im.save(f'p{r}.png')
