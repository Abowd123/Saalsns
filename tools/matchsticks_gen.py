import random, json, itertools
def slots(W,H):
    s=[('h',x,y) for y in range(H+1) for x in range(W)]+[('v',x,y) for y in range(H) for x in range(W+1)]
    return s
def squares(st,W,H):
    out=[]
    for y in range(H):
        for x in range(W):
            e=[('h',x,y),('h',x,y+1),('v',x,y),('v',x+1,y)]
            if all(k in st for k in e):out.append(e)
    return out
def solved(st,W,H,T):
    sq=squares(st,W,H)
    if len(sq)!=T:return False
    used=set(k for e in sq for k in e)
    return used==set(st)
def min_moves(st,W,H,T,maxd):
    S=slots(W,H);frontier={frozenset(st)};seen=set(frontier)
    if solved(st,W,H,T):return 0
    for d in range(1,maxd+1):
        nf=set()
        for s in frontier:
            empty=[k for k in S if k not in s]
            for a in s:
                for b in empty:
                    n=(s-{a})|{b}
                    if n in seen:continue
                    if solved(n,W,H,T):return d
                    seen.add(n);nf.add(n)
        frontier=nf
    return None
def gen(W,H,cells,m,seed):
    rng=random.Random(seed)
    S=slots(W,H)
    for _ in range(5000):
        # choose solved config: union of chosen cells, require exact squares==len(cells)
        cs=rng.sample([(x,y) for y in range(H) for x in range(W)],cells)
        st=set()
        for x,y in cs: st|={('h',x,y),('h',x,y+1),('v',x,y),('v',x+1,y)}
        T=len(squares(st,W,H))
        sol=frozenset(st)
        cur=set(st);moves=[]
        ok=True
        for _ in range(m):
            a=rng.choice(sorted(cur));b=rng.choice([k for k in S if k not in cur])
            cur.remove(a);cur.add(b);moves.append((b,a))  # to undo: move b back to a
        mm=min_moves(cur,W,H,T,m)
        if mm==m:
            return {"w":W,"h":H,"sticks":[list(k) for k in sorted(cur)],"target":T,"move":m,"solution":[[list(f),list(t)] for f,t in reversed(moves)]}
    raise Exception("fail")
names=["مربعان","ثلاثة مربعات","الزاوية","أربعة مربعات","حركتان","التحدي"]
spec=[(3,1,2,1,1),(3,2,3,1,4),(3,3,3,1,7),(3,3,4,1,3),(3,2,4,2,5),(3,3,5,2,8)]
lv=[]
for i,(nm,(W,H,c,m,seed)) in enumerate(zip(names,spec),1):
    d=gen(W,H,c,m,seed);d={"id":i,"name":nm,**d};lv.append(d)
    print(i,nm,W,H,"sticks",len(d["sticks"]),"target",d["target"],"move",m)
open(__import__('pathlib').Path(__file__).resolve().parents[1]/'content/matchsticks/levels.json','w').write(json.dumps({"version":2,"note":"Grid edges: [\"h\",x,y] = (x,y)-(x+1,y), [\"v\",x,y] = (x,y)-(x,y+1). Win = exactly target unit squares and no loose sticks. move = minimum moves (verified by tools/matchsticks_gen.py). solution = one valid sequence [from, to].","levels":lv},ensure_ascii=False))
