"""nav.py GAME "STEPS": drive.py's steps (wait S | press BUTTON [S] | hold TOKENS | release | shot NAME) against a game
already running under sess.sh (its pad file and frame dump trigger in H:/uncharted_pc/out/try/GAME). Shots are saved
at 900 px as out/try/GAME/NAME.png."""
import sys, time
from pathlib import Path
sys.path.insert(0, r'H:\uncharted_pc\tools')
import drive
out = Path(r'H:\uncharted_pc\out\try') / sys.argv[1]
pad, dump, trigger = out / 'pad.txt', out / 'dump', out / 'dump.trigger'


def put(text):
    tmp = pad.with_suffix('.tmp'); tmp.write_text(text, encoding='ascii'); tmp.replace(pad)


for step in filter(None, (s.strip() for s in sys.argv[2].split(';'))):
    verb, *args = step.split()
    if verb == 'wait':
        time.sleep(float(args[0]))
    elif verb == 'press':
        put(args[0]); time.sleep(float(args[1]) if len(args) > 1 else 0.15); put(''); time.sleep(0.1)
    elif verb == 'hold':
        put(' '.join(args))
    elif verb == 'release':
        put('')
    elif verb == 'shot':
        png = out / (args[0] + '.png')
        if drive.frame_shot(dump, trigger, png):
            from PIL import Image
            im = Image.open(png); im.thumbnail((900, 900)); im.save(png)
        else:
            print('shot failed')
