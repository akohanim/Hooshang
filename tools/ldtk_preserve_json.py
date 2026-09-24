"""Update structured LDtk JSON while preserving untouched author formatting."""
import json
DEC=json.JSONDecoder()
def pretty(v,depth=0):
 pad='\t'*depth
 if isinstance(v,dict):
  if 'px' in v and 'src' in v and 't' in v:return json.dumps(v,separators=(',',':'))
  return '{\n'+',\n'.join(pad+'\t'+json.dumps(k)+': '+pretty(x,depth+1) for k,x in v.items())+'\n'+pad+'}' if v else '{}'
 if isinstance(v,list):
  if not v or all(not isinstance(x,(dict,list)) for x in v):return json.dumps(v,separators=(',',':'))
  return '[\n'+',\n'.join(pad+'\t'+pretty(x,depth+1) for x in v)+'\n'+pad+']'
 return json.dumps(v)
def update(text,wanted):
 old=json.loads(text)
 def patch(raw,a,b,depth):
  if a==b:return raw
  if isinstance(a,dict) and isinstance(b,dict) and a.keys()==b.keys():
   i=raw.index('{')+1;changes=[]
   for key,value in a.items():
    while raw[i].isspace() or raw[i]==',':i+=1
    k,end=DEC.raw_decode(raw,i);i=end
    while raw[i].isspace() or raw[i]==':':i+=1
    _,end=DEC.raw_decode(raw,i)
    changes.append((i,end,patch(raw[i:end],value,b[key],depth+1)));i=end
   for start,end,new in reversed(changes):raw=raw[:start]+new+raw[end:]
   return raw
  if isinstance(a,list) and isinstance(b,list) and len(b)>=len(a) and a:
   i=raw.index('[')+1;changes=[]
   for j,value in enumerate(a):
    while raw[i].isspace() or raw[i]==',':i+=1
    _,end=DEC.raw_decode(raw,i);changes.append((i,end,patch(raw[i:end],value,b[j],depth+1)));i=end
   if len(b)>len(a):changes.append((i,i,',\n'+',\n'.join('\t'*(depth+1)+pretty(x,depth+1) for x in b[len(a):])))
   for start,end,new in reversed(changes):raw=raw[:start]+new+raw[end:]
   return raw
  return pretty(b,depth)
 result=patch(text,old,wanted,0)
 assert json.loads(result)==wanted
 return result
