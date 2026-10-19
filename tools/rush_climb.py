import rush_gen as r, random, time, json, sys
seed=int(sys.argv[1]); T=float(sys.argv[2])
rng=random.Random(seed); t0=time.time()
best={}  # depth -> (cars,pos)
def record(cars,pos,d):
    if d not in best: best[d]=( [list(c) for c in cars],[list(p) for p in pos])
def mutate(cars,pos):
    cars=list(cars);pos=list(pos)
    op=rng.random()
    if op<0.4 and len(cars)>6:
        i=rng.randrange(1,len(cars));cars.pop(i);pos.pop(i)
    else:
        for _ in range(50):
            l=3 if rng.random()<0.3 else 2;h=rng.random()<0.5
            if h:
                y=rng.randrange(6)
                if y==2: continue
                x=rng.randrange(0,7-l)
            else: x=rng.randrange(6);y=rng.randrange(0,7-l)
            c=cars+[(l,h,False)];p=pos+[(x,y)]
            if r.occ(c,p) is not None:
                if op>=0.7 and len(cars)>6:
                    i=rng.randrange(1,len(cars));c.pop(i);p.pop(i)
                    if r.occ(c,p) is None: continue
                cars,pos=c,p;break
    return cars,tuple(pos)
cur=None;curd=-1
while time.time()-t0<T:
    if cur is None or rng.random()<0.02:
        cars,pos=r.rand_layout(rng,rng.randint(8,12))
    else:
        cars,pos=mutate(*cur)
    res=r.hardest(cars,pos,25000)
    if not res: continue
    b,d,_=res
    record(cars,b,d)
    if d>=curd or rng.random()<0.05:
        cur=(cars,b);curd=d
json.dump({str(k):v for k,v in best.items()},open(f'rush_best_{seed}.json','w'))
print(seed,sorted(best)[-5:])
