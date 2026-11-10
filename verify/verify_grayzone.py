"""Independent cross-check of the MATLAB results in Python.

Re-implements the same rules as code/analyzeLeadVehicle.m and code/compareGrayZone.m
and prints the headline numbers. Usage:

    python verify_grayzone.py path/to/citySensorLog.mat

Expected output with the MathWorks workshop data:
    before review 38 warning 2
    after events 2 confirmed warning 0
"""
import sys, numpy as np
from scipy.io import loadmat
m=loadmat(sys.argv[1],squeeze_me=True,struct_as_record=False)
radar=np.atleast_1d(m['radar']); lane=np.atleast_1d(m['lane'])
n=len(radar); ts=np.array([float(r.timeStamp) for r in radar]); t=(ts-ts[0])*1e-6
def laneY(b,x):
    ok=bool(getattr(b,'isValid',0))
    return (b.offset+x*np.tan(b.headingAngle)+b.curvature*x**2, ok)
def run(g):
    ttc=np.full(n,np.inf); prop=['']*n; stat=['']*n; dist=np.full(n,np.nan)
    for k in range(n):
        mo=int(radar[k].numObjects)
        if mo<1: prop[k]=stat[k]='No Object'; continue
        obj=np.atleast_1d(radar[k].object)[:mo]
        P=np.array([np.atleast_1d(o.position) for o in obj]); x=P[:,0]; y=P[:,1]
        yl,okL=laneY(lane[k].left,x); yr,okR=laneY(lane[k].right,x)
        if not(okL and okR): yl=np.full_like(x,1.8); yr=np.full_like(x,-1.8)
        inl=(x>0)&(y<=np.maximum(yl,yr))&(y>=np.minimum(yl,yr))
        if not inl.any(): prop[k]=stat[k]='No Object'; continue
        idx=np.where(inl)[0]; i=idx[np.argmin(x[idx])]
        dist[k]=x[i]; V=np.array([np.atleast_1d(o.velocity) for o in obj]); cs=-V[i,0]
        if cs>0: ttc[k]=x[i]/cs
        c='Warning' if ttc[k]<=2 else 'Caution' if ttc[k]<=4 else 'Normal'
        prop[k]=c; stat[k]='Review' if (abs(ttc[k]-2)<=g or abs(ttc[k]-4)<=g) else c
    return ttc,np.array(prop),np.array(stat),dist
_,p0,s0,_=run(0.5); _,p1,s1,_=run(0.25)
print('frames',n,'dt',np.median(np.diff(t)))
print('before review',(s0=='Review').sum(),'warning',(p0=='Warning').sum())
sev=(p1=='Caution')*1+(p1=='Warning')*2; conf=np.zeros(n,int); N=3
for k in range(n):
    if k>=N-1 and (sev[k-N+1:k+1]==sev[k]).all(): conf[k]=sev[k]
    elif k>0: conf[k]=conf[k-1]
rev=(s1=='Review'); revP=np.zeros(n,bool)
for k in range(N-1,n):
    if rev[k-N+1:k+1].all(): revP[k-N+1:k+1]=True
d=np.diff(np.r_[0,revP.astype(int),0]); print('after events',(d==1).sum(),'confirmed warning',(conf==2).sum())
