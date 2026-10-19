import json,sys
from collections import deque
def parse(m):
    W=set();G=set();B=set();P=None
    for y,row in enumerate(m):
        for x,ch in enumerate(row):
            p=(x,y)
            if ch=='#':W.add(p)
            elif ch=='.':G.add(p)
            elif ch=='$':B.add(p)
            elif ch=='*':B.add(p);G.add(p)
            elif ch=='@':P=p
            elif ch=='+':P=p;G.add(p)
    return W,G,B,P
def dead(p,W,G):
    if p in G:return False
    x,y=p
    up=(x,y-1) in W;dn=(x,y+1) in W;le=(x-1,y) in W;ri=(x+1,y) in W
    return (up or dn) and (le or ri)
def solve(m):
    W,G,B,P=parse(m)
    if len(B)!=len(G):return None
    s=(P,frozenset(B));q=deque([(s,0)]);seen={s}
    while q:
        (p,bx),d=q.popleft()
        if bx==G:return d
        for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
            n=(p[0]+dx,p[1]+dy)
            if n in W:continue
            nb=bx
            if n in bx:
                b2=(n[0]+dx,n[1]+dy)
                if b2 in W or b2 in bx or dead(b2,W,G):continue
                nb=(bx-{n})|{b2}
            st=(n,nb)
            if st not in seen:seen.add(st);q.append((st,d+1))
    return None
if __name__=="__main__":
    if len(sys.argv)<2: sys.argv.append(str(__import__("pathlib").Path(__file__).resolve().parents[1]/"content/sokoban_levels.json"))
    for lv in json.load(open(sys.argv[1]))['levels']:
        print(lv['id'],lv['name'],solve(lv['map']))
