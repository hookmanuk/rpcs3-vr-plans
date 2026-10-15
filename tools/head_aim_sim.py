# Head aim (profile head_aim, rsx_camera_probe.cpp update_head_aim / head_aim_pad) simulated: a head turn of 20 degrees right
# and 10 up while the aim button is held, a game camera that turns at 120 / 90 degrees a second at full stick with two
# frames of input lag, then the button let go. Prints the error, the stick, the offset and the direction the headset
# shows (it must follow the head alone while aiming). Runs a normal game and one with each look axis inverted.
# Usage: python tools/head_aim_sim.py
import numpy as np, math
deg=180/math.pi
def cam(y,p):
    f=np.array([math.sin(y)*math.cos(p), math.sin(p), math.cos(y)*math.cos(p)])
    r=np.array([math.cos(y),0,-math.sin(y)])
    u=np.array([-math.sin(y)*math.sin(p), math.cos(p), -math.cos(y)*math.sin(p)])
    return np.array([r,u,f])
def rx(a): c,s=math.cos(a),math.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def ry(a): c,s=math.cos(a),math.sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def head_rot(yaw_right, pitch_up):
    R=ry(-yaw_right)@rx(pitch_up)
    s=[1,1,-1]
    return np.array([[s[j]*R[j][i]*s[i] for j in range(3)] for i in range(3)])
def angle(R): return math.acos(np.clip((np.trace(R)-1)/2,-1,1))
def ortho(m):
    f=m[2]/np.linalg.norm(m[2]); x=m[0]-f*(m[0]@f); x/=np.linalg.norm(x); y=m[1]-f*(m[1]@f)-x*(m[1]@x); y/=np.linalg.norm(y); return np.array([x,y,f])
rule=dict(full=10,minst=0.15,dz=0.75,ret=120)
def shape(e):
    a=abs(e)
    if a<=rule['dz']: return 0
    t=min(1,(a-rule['dz'])/(rule['full']-rule['dz'])); return math.copysign(rule['minst']+(1-rule['minst'])*t,e)
def run(sign_game_x=1, sign_game_y=1, gaze=False):
    y=p=0.0; Off=np.eye(3); prevC=None; dt=1/45; lag=[(0,0)]*2
    sign=[1,1]; votes=[0,0]; ref=[0,0]; was=False; frames=0; out=(0,0)
    log=[]
    for n in range(270):
        t=n*dt
        active = 0.2<=t<4.0
        hy = (20/deg)*min(1,max(0,(t-0.5)/0.5)) if t<3 else (20/deg)
        hp = (10/deg)*min(1,max(0,(t-1.0)/0.5))
        # game applies stick from 2 frames ago
        sx,sy=lag.pop(0)
        y += sign_game_x*sx*120/deg*dt; p += sign_game_y*sy*90/deg*dt
        C=cam(y,p); H=head_rot(hy,hp)
        if prevC is not None:
            turn=prevC@C.T
            if angle(turn)<25/deg:
                if active: Off=Off@turn
                if active and frames>15:
                    m=[math.atan2(turn[0,2],turn[2,2])*deg, math.atan2(turn[1,2],turn[2,2])*deg]
                    for ax in range(2):
                        if abs(out[ax])<0.5 or abs(m[ax])<0.2: continue
                        votes[ax]=max(-8,min(8,votes[ax]+(1 if (out[ax]>0)==(m[ax]>0) else -1)))
                        if votes[ax]<=-6: votes[ax]=0; sign[ax]=-sign[ax]; log.append(('flip',ax,t))
        prevC=C
        if not active:
            a=angle(Off)
            if a<0.2/deg: Off=np.eye(3)
            else:
                step=rule['ret']/deg*dt*min(1,max(0.25,a/(10/deg))); nx=max(0,a-step); sn=2*math.sin(a)
                axv=np.array([Off[2,1]-Off[1,2],Off[0,2]-Off[2,0],Off[1,0]-Off[0,1]])/sn
                K=np.array([[0,-axv[2],axv[1]],[axv[2],0,-axv[0]],[-axv[1],axv[0],0]])
                Off=np.eye(3)+math.sin(nx)*K+(1-math.cos(nx))*K@K
        Off=ortho(Off)
        E=H@Off; a=E[:,2]
        ex=math.atan2(-a[0],a[2])*deg; ey=math.atan2(-a[1],math.hypot(a[0],a[2]))*deg
        if active and not was: ref=[0,0] if gaze else [ex,ey]; frames=0
        was=active; frames = frames+1 if active else 0
        ex-=ref[0]; ey-=ref[1]
        out=(shape(ex), shape(ey)) if active else (0,0)
        lag.append((sign[0]*out[0], sign[1]*out[1]))
        view=E@C  # what the headset shows (world -> eye)
        if n%15==0 or n in (179,180,181):
            print(f"t={t:4.2f} act={int(active)} head=({hy*deg:5.1f},{hp*deg:5.1f}) cam=({y*deg:6.2f},{p*deg:6.2f}) err=({ex:6.2f},{ey:6.2f}) stick=({out[0]:5.2f},{out[1]:5.2f}) off={angle(Off)*deg:5.2f} viewfwd={np.round(view.T@np.array([0,0,1]),3)}")
    print(log)
print("normal game"); run()
print("inverted horizontal look"); run(sign_game_x=-1)
print("inverted vertical look"); run(sign_game_y=-1)
