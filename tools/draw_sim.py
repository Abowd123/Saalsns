"""Approximate 2D sim to sanity-check draw_levels.json reference solutions.
Not Godot's solver, so levels are designed with wide margins; the in-app verifier is the final check."""
import json, math, sys
G=980.0; R=22.0; E=0.3; MU=0.15; DT=1/240

def rect_segs(x,y,w,h):
    return [((x,y),(x+w,y)),((x+w,y),(x+w,y+h)),((x+w,y+h),(x,y+h)),((x,y+h),(x,y))]

def closest(p,a,b):
    ax,ay=a; bx,by=b; px,py=p
    dx,dy=bx-ax,by-ay; L=dx*dx+dy*dy
    t=0 if L==0 else max(0,min(1,((px-ax)*dx+(py-ay)*dy)/L))
    return (ax+dx*t, ay+dy*t)

def run(lv, use_solution=True):
    segs=[]
    for w in lv['walls']: segs+=rect_segs(*w)
    gx,gy,gw,gh=lv['goal']
    segs+=rect_segs(gx,gy+gh-10,gw,10)+rect_segs(gx,gy+gh*0.35,10,gh*0.65)+rect_segs(gx+gw-10,gy+gh*0.35,10,gh*0.65)
    ink=0
    if use_solution:
        s=lv['solution']
        for i in range(1,len(s)):
            segs.append((tuple(s[i-1]),tuple(s[i]))); ink+=math.dist(s[i-1],s[i])
    x,y=lv['ball']; vx=vy=0.0; hold=0.0; t=0.0
    while t<9.0:
        vy+=G*DT; x+=vx*DT; y+=vy*DT; t+=DT
        for a,b in segs:
            cx,cy=closest((x,y),a,b); dx,dy=x-cx,y-cy; d=math.hypot(dx,dy)
            if 0<d<R:
                nx,ny=dx/d,dy/d; x+=nx*(R-d); y+=ny*(R-d)
                vn=vx*nx+vy*ny
                if vn<0:
                    tx,ty=-ny,nx; vt=vx*tx+vy*ty
                    vn=-vn*E; vt*=(1-MU*0.05)
                    vx=vn*nx+vt*tx; vy=vn*ny+vt*ty
        if gx<=x<=gx+gw and gy<=y<=gy+gh and math.hypot(vx,vy)<40:
            hold+=DT
            if hold>=0.8: return True, ink, t
        else: hold=0
        if y>1000: return False, ink, t
    return False, ink, t

if __name__=='__main__':
    d=json.load(open(sys.argv[1] if len(sys.argv)>1 else str(__import__("pathlib").Path(__file__).resolve().parents[1]/"content/build/draw_levels.json"))); ok=True
    for lv in d['levels']:
        win,ink,t=run(lv); trivial,_,_=run(lv,False)
        print(lv['id'],lv['name'],'solution_wins=',win,'ink=%.0f/%d'%(ink,lv['ink']),'t=%.1f'%t,'trivial_without_drawing=',trivial)
        ok &= win and ink<=lv['ink'] and not trivial
    sys.exit(0 if ok else 1)
