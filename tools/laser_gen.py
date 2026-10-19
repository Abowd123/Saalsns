"""Advanced laser generator. Tap a mirror/splitter to flip it between / and \\.
Win = every target lit by a beam of ITS color and no bomb hit. Every level has exactly one
winning set of orientations (checked over all 2^k combinations); par = flips needed."""
import random, json, pathlib, itertools
def reflect(o,dx,dy): return (-dy,-dx) if o==0 else (dy,dx)   # 0 = '/', 1 = '\'
def trace(lv,orient):
    n=lv["size"];walls={tuple(w) for w in lv["walls"]};fixed={(f[0],f[1]):f[2] for f in lv["fixed"]}
    pieces={(p["x"],p["y"]):(p["kind"],orient[i]) for i,p in enumerate(lv["pieces"])}
    targets={(t["x"],t["y"]):t["color"] for t in lv["targets"]};bombs={tuple(b) for b in lv["bombs"]}
    srcs={(s["x"],s["y"]) for s in lv["sources"]}
    lit=set();boom=False;path=[];ends=[]
    for s in lv["sources"]:
        col=s["color"];stack=[(s["x"],s["y"],s["dir"][0],s["dir"][1])];seen=set()
        while stack:
            x,y,dx,dy=stack.pop()
            while True:
                nx,ny=x+dx,y+dy
                if not(0<=nx<n and 0<=ny<n) or (nx,ny) in walls or (nx,ny) in srcs:
                    ends.append((x,y,col));break
                if (nx,ny,dx,dy,col) in seen: break
                seen.add((nx,ny,dx,dy,col));path.append((nx,ny,col))
                x,y=nx,ny
                if (x,y) in bombs: boom=True;break
                if (x,y) in targets:
                    if targets[(x,y)]==col: lit.add((x,y))
                    break
                if (x,y) in fixed: dx,dy=reflect(fixed[(x,y)],dx,dy)
                elif (x,y) in pieces:
                    kind,o=pieces[(x,y)]
                    if kind=="split": stack.append((x,y,dx,dy))
                    dx,dy=reflect(o,dx,dy)
    ok=(not boom) and all(p in lit for p in targets)
    trace.ends=ends
    return ok,path,boom
def gen(n,k,nsplit,ncolors,ntargets,nbombs,rng):
    for _ in range(20000):
        cells=[(x,y) for x in range(n) for y in range(n)]
        lv={"size":n,"sources":[],"walls":[],"fixed":[],"pieces":[],"targets":[],"bombs":[]}
        used=set()
        for c in range(ncolors):
            side=rng.randrange(4)
            if side==0: x,y,d=0,rng.randrange(1,n-1),(1,0)
            elif side==1: x,y,d=n-1,rng.randrange(1,n-1),(-1,0)
            elif side==2: x,y,d=rng.randrange(1,n-1),0,(0,1)
            else: x,y,d=rng.randrange(1,n-1),n-1,(0,-1)
            if (x,y) in used: break
            used.add((x,y));lv["sources"].append({"x":x,"y":y,"dir":list(d),"color":c})
        if len(lv["sources"])<ncolors: continue
        sol=[]
        # grow the solution: each new piece goes on a cell the current beam passes through
        okb=True
        for i in range(k+rng.randint(0,2)):
            _,path,_=trace(lv,sol)
            taken={(p["x"],p["y"]) for p in lv["pieces"]}|{(f[0],f[1]) for f in lv["fixed"]}|used
            opts=[(x,y) for x,y,_ in path if (x,y) not in taken]
            if not opts: okb=False;break
            x,y=rng.choice(opts[len(opts)//3:] or opts)
            if i>=k:
                lv["fixed"].append([x,y,rng.randrange(2)])
            else:
                lv["pieces"].append({"x":x,"y":y,"kind":"split" if i in (1,3)[:nsplit] else "mirror"});sol.append(rng.randrange(2))
        if not okb or len(lv["pieces"])<k: continue
        _,path,_=trace(lv,sol)
        pc={(p["x"],p["y"]) for p in lv["pieces"]}
        if not pc<= {(x,y) for x,y,_ in path}: continue
        on={(x,y) for x,y,_ in path}
        taken=pc|{(f[0],f[1]) for f in lv["fixed"]}|used
        free=[c for c in cells if c not in taken]
        offp=[c for c in free if c not in on];rng.shuffle(offp)
        for w in offp[:rng.randint(n//2,n)]: lv["walls"].append(list(w))
        free=[c for c in free if list(c) not in lv["walls"]]
        trace(lv,sol)
        fs=set(free)
        cand=[];seenc=set()
        for x,y,c in trace.ends:
            if (x,y) in fs and (x,y) not in seenc: cand.append((x,y,c));seenc.add((x,y))
        if len(cand)<ntargets: continue
        rng.shuffle(cand)
        picks=cand[:ntargets]
        cols={c for _,_,c in picks}
        if ncolors==2 and len(cols)<2: continue
        for x,y,c in picks: lv["targets"].append({"x":x,"y":y,"color":c})
        ok,path,_=trace(lv,sol)
        if not ok: continue
        if not pc<= {(x,y) for x,y,_ in path}: continue
        on={(x,y) for x,y,_ in path};tg={(t["x"],t["y"]) for t in lv["targets"]}
        bf=[c for c in free if c not in on and c not in tg]
        rng.shuffle(bf)
        for b in bf[:nbombs]: lv["bombs"].append(list(b))
        if not trace(lv,sol)[0]: continue
        wins=[o for o in itertools.product((0,1),repeat=k) if trace(lv,list(o))[0]]
        if len(wins)!=1: continue
        for _ in range(100):
            st=[rng.randrange(2) for _ in range(k)]
            par=sum(a!=b for a,b in zip(st,sol))
            if par>=max(2,(k+1)//2) and not trace(lv,st)[0]: break
        else: continue
        for i,p in enumerate(lv["pieces"]): p["start"]=st[i];p["solution"]=sol[i]
        lv["par"]=par
        return lv
    raise Exception("fail %s"%((n,k),))
spec=[(6,3,0,1,1,0),(6,4,1,1,2,1),(6,5,1,1,2,2),(7,5,0,2,2,2),(7,6,1,2,3,2),(7,7,1,2,3,3),(8,8,2,2,3,3),(8,9,2,2,4,4)]
names=["الشعاع الأول","المقسِّم","الحقل الملغوم","لونان","ثلاثة أهداف","المتاهة","شبكة الضوء","المختبر"]
if __name__=="__main__":
    rng=random.Random(77);lv=[]
    for i,sp in enumerate(spec):
        l=gen(*sp,rng);l={"id":i+1,"name":names[i],**l};lv.append(l)
        print(i+1,names[i],"size",l["size"],"pieces",len(l["pieces"]),"targets",len(l["targets"]),"bombs",len(l["bombs"]),"par",l["par"])
    root=pathlib.Path(__file__).resolve().parents[1]
    out=root/"content/laser/levels.json" if (root/"content").exists() else pathlib.Path("laser_levels.json")
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps({"version":1,"note":"orientation 0 = '/', 1 = '\\\\'. Exactly one winning orientation set per level (tools/laser_gen.py).","levels":lv},ensure_ascii=False))
    print("wrote",out)
