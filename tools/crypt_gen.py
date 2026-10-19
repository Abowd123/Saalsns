"""Letter arithmetic (cryptarithm) generator: A + B = C, each letter one digit, different
letters = different digits, no leading zero. Every shipped puzzle has exactly ONE solution
(counted by an exhaustive column solver)."""
import random, json, pathlib, itertools
LETTERS=list("أبجدرسعفقلمنهوكص")
def count_solutions(words,limit=2):
    a,b,c=words
    letters=sorted(set(a+b+c))
    lead={w[0] for w in words}
    # exhaustive with pruning: assign by columns right to left
    cols=[]
    L=len(c)
    A=a.rjust(L,' ');B=b.rjust(L,' ')
    for i in range(L-1,-1,-1): cols.append((A[i],B[i],c[i]))
    order=[]
    for x,y,z in cols:
        for ch in (x,y,z):
            if ch!=' ' and ch not in order: order.append(ch)
    sols=[0];found=[None]
    asg={};used=set()
    def check_col(ci,carry):
        # returns list of possible carries out if all letters in col assigned, else None
        x,y,z=cols[ci]
        vals=[]
        for ch in (x,y,z):
            if ch==' ': vals.append(0)
            elif ch in asg: vals.append(asg[ch])
            else: return None
        s=vals[0]+vals[1]+carry
        if s%10!=vals[2]: return False
        return s//10
    def rec(ci,carry):
        if sols[0]>=limit: return
        if ci==len(cols):
            if carry==0:
                sols[0]+=1;found[0]=dict(asg)
            return
        x,y,z=cols[ci]
        free=[ch for ch in dict.fromkeys((x,y,z)) if ch!=' ' and ch not in asg]
        if not free:
            r=check_col(ci,carry)
            if r is False: return
            rec(ci+1,r);return
        ch=free[0]
        for d in range(10):
            if d in used or (d==0 and ch in lead): continue
            asg[ch]=d;used.add(d)
            r=check_col(ci,carry)
            if r is None: rec_partial(ci,carry)
            elif r is not False: rec(ci+1,r)
            del asg[ch];used.discard(d)
    def rec_partial(ci,carry):
        x,y,z=cols[ci]
        free=[ch for ch in dict.fromkeys((x,y,z)) if ch!=' ' and ch not in asg]
        ch=free[0]
        for d in range(10):
            if d in used or (d==0 and ch in lead): continue
            asg[ch]=d;used.add(d)
            r=check_col(ci,carry)
            if r is None: rec_partial(ci,carry)
            elif r is not False: rec(ci+1,r)
            del asg[ch];used.discard(d)
            if sols[0]>=limit: return
    rec(0,0)
    return sols[0],found[0]
def gen(la,lb,kmin,kmax,rng):
    for _ in range(200000):
        a=rng.randrange(10**(la-1),10**la);b=rng.randrange(10**(lb-1),10**lb);c=a+b
        digits=sorted(set(str(a)+str(b)+str(c)))
        if not(kmin<=len(digits)<=kmax): continue
        letters=rng.sample(LETTERS,len(digits))
        m=dict(zip(digits,letters))
        w=["".join(m[d] for d in str(n)) for n in (a,b,c)]
        n,sol=count_solutions(w)
        if n==1:
            return {"a":w[0],"b":w[1],"c":w[2],"solution":{k:int(v) for k,v in sol.items()},"letters":len(digits)}
spec=[(2,2,4,4),(3,2,5,5),(3,3,5,6),(3,3,6,7),(4,3,7,7),(4,4,7,8),(5,4,8,9),(5,5,9,10)]
names=["البداية","خانة إضافية","ثلاث خانات","الحمل","آلاف","أربعة وأربعة","عشرات الآلاف","العبقري"]
if __name__=="__main__":
    rng=random.Random(2026);lv=[]
    for i,(la,lb,k1,k2) in enumerate(spec):
        p=gen(la,lb,k1,k2,rng);p={"id":i+1,"name":names[i],**p};lv.append(p)
        print(i+1,p["a"],"+",p["b"],"=",p["c"],"letters",p["letters"])
    root=pathlib.Path(__file__).resolve().parents[1]
    out=root/"content/crypt/levels.json" if (root/"content").exists() else pathlib.Path("crypt_levels.json")
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps({"version":1,"note":"a + b = c. Every letter is one digit, different letters different digits, no leading zero. Each puzzle has exactly one solution (tools/crypt_gen.py).","levels":lv},ensure_ascii=False))
    print("wrote",out)
