import random, json
# directions as (dx,dy). rotation r: q -> (-q.y, q.x) applied r times (same as game)
SH={0:[(0,-1),(0,1)],1:[(-1,0),(1,0)],2:[(0,-1),(1,0)],3:[(1,0),(0,1)],4:[(0,1),(-1,0)],5:[(-1,0),(0,-1)]}
def rot(q,r):
    for _ in range(r): q=(-q[1],q[0])
    return q
def shape(base,r): return [rot(q,r) for q in SH[base]]
def connected(n,layout,rots,src):
    seen={src};q=[src]
    while q:
        p=q.pop(0)
        for d in shape(layout[p[1]][p[0]],rots[p[1]][p[0]]):
            nb=(p[0]+d[0],p[1]+d[1])
            if not(0<=nb[0]<n and 0<=nb[1]<n):continue
            if (-d[0],-d[1]) in shape(layout[nb[1]][nb[0]],rots[nb[1]][nb[0]]) and nb not in seen:
                seen.add(nb);q.append(nb)
    return seen
def walk(n,src,dst,rng,minlen):
    for _ in range(20000):
        path=[src];cur=src;vis={src}
        while cur!=dst:
            opts=[(cur[0]+dx,cur[1]+dy) for dx,dy in((1,0),(-1,0),(0,1),(0,-1))]
            opts=[o for o in opts if 0<=o[0]<n and 0<=o[1]<n and o not in vis]
            if not opts:break
            cur=rng.choice(opts);path.append(cur);vis.add(cur)
        if cur==dst and minlen<=len(path)<=minlen+1:return path
    raise Exception("no path")
def need(path,i):
    p=path[i];ds=[]
    if i>0:ds.append((path[i-1][0]-p[0],path[i-1][1]-p[1]))
    if i<len(path)-1:ds.append((path[i+1][0]-p[0],path[i+1][1]-p[1]))
    return ds
def gen(n,seed,minlen):
    rng=random.Random(seed)
    src=(0,0);dst=(n-1,n-1)
    path=walk(n,src,dst,rng,minlen)
    layout=[[rng.randrange(6) for _ in range(n)] for _ in range(n)]
    for i,p in enumerate(path):
        ds=need(path,i)
        if len(ds)==2 and ds[0][0]==-ds[1][0] and ds[0][1]==-ds[1][1]:
            layout[p[1]][p[0]]=rng.choice([0,1])
        elif len(ds)==2:
            layout[p[1]][p[0]]=rng.choice([2,3,4,5])
    # valid rotations per path cell
    valid={}
    for i,p in enumerate(path):
        ds=need(path,i);b=layout[p[1]][p[0]]
        valid[p]=[r for r in range(4) if all(d in shape(b,r) for d in ds)]
        assert valid[p],(p,ds,b)
    while True:
        start=[[rng.randrange(4) for _ in range(n)] for _ in range(n)]
        if dst in connected(n,layout,start,src):continue
        par=sum(min((r-start[p[1]][p[0]])%4 for r in valid[p]) for p in path)
        if par>=len(path)//2:break
    sol=[[-1]*n for _ in range(n)]
    for p in path: sol[p[1]][p[0]]=valid[p][0]
    # check solution works
    test=[row[:] for row in start]
    for p in path: test[p[1]][p[0]]=valid[p][0]
    assert dst in connected(n,layout,test,src)
    return {"size":n,"source":list(src),"target":list(dst),"layout":layout,"start":start,"solution":sol,"par":par,"path_len":len(path)}
names=["المسار الأول","منعطفان","الأفعى","العبور","المتاهة","الشبكة الكبرى"]
spec=[(4,11,7),(4,23,9),(5,5,11),(5,8,13),(6,3,17),(6,9,21)]
lv=[]
for i,((n,seed,ml),nm) in enumerate(zip(spec,names),1):
    d=gen(n,seed,ml);d={"id":i,"name":nm,**d};lv.append(d);print(i,nm,n,"path",d["path_len"],"par",d["par"])
open(__import__('pathlib').Path(__file__).resolve().parents[1]/'content/pipes/levels.json','w').write(json.dumps({"version":2,"note":"start = initial rotations, solution = one valid rotation per path cell (-1 = free), par = rotations needed for that solution. Generated + verified by tools/pipes_gen.py","levels":lv},ensure_ascii=False))
