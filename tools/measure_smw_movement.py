#!/usr/bin/env python3
import ctypes as C, pathlib, json, struct, zlib
import argparse, hashlib
parser=argparse.ArgumentParser(description="Measure a user-supplied US SMW ROM through a libretro SNES core.")
parser.add_argument('--rom',type=pathlib.Path,required=True)
parser.add_argument('--core',type=pathlib.Path,required=True)
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args()
ROOT=args.output
ROOT.mkdir(parents=True,exist_ok=True)
core=C.CDLL(str(args.core))
ENV=C.CFUNCTYPE(C.c_bool,C.c_uint,C.c_void_p)
VIDEO=C.CFUNCTYPE(None,C.c_void_p,C.c_uint,C.c_uint,C.c_size_t)
AUDIO=C.CFUNCTYPE(None,C.c_int16,C.c_int16)
BATCH=C.CFUNCTYPE(C.c_size_t,C.c_void_p,C.c_size_t)
POLL=C.CFUNCTYPE(None)
INPUT=C.CFUNCTYPE(C.c_int16,C.c_uint,C.c_uint,C.c_uint,C.c_uint)
buttons=set();last_frame=None;pixel_format=0
@ENV
def env(cmd,data):
 global pixel_format
 if cmd==3:C.cast(data,C.POINTER(C.c_bool))[0]=True;return True
 if cmd==10:pixel_format=C.cast(data,C.POINTER(C.c_int))[0];return True
 if cmd==17:C.cast(data,C.POINTER(C.c_bool))[0]=False;return True
 if cmd in [16,18,35]:return True
 return False
@VIDEO
def video(data,w,h,pitch):
 global last_frame
 if data:last_frame=(C.string_at(data,pitch*h),w,h,pitch)
@AUDIO
def audio(l,r):pass
@BATCH
def batch(data,n):return n
@POLL
def poll():pass
@INPUT
def inp(port,device,index,id):return int(port==0 and id in buttons)
for name,cb in [('environment',env),('video_refresh',video),('audio_sample',audio),('audio_sample_batch',batch),('input_poll',poll),('input_state',inp)]:
 getattr(core,'retro_set_'+name).argtypes=[type(cb)];getattr(core,'retro_set_'+name)(cb)
core.retro_init()
class Game(C.Structure):_fields_=[('path',C.c_char_p),('data',C.c_void_p),('size',C.c_size_t),('meta',C.c_char_p)]
rom=C.create_string_buffer(args.rom.read_bytes())
core.retro_load_game.argtypes=[C.POINTER(Game)];core.retro_load_game.restype=C.c_bool
assert core.retro_load_game(C.byref(Game(None,C.cast(rom,C.c_void_p),len(rom)-1,None)))
core.retro_get_memory_data.argtypes=[C.c_uint];core.retro_get_memory_data.restype=C.c_void_p
ram=(C.c_uint8*131072).from_address(core.retro_get_memory_data(2))
def word(a):return ram[a]+ram[a+1]*256
def signed(v):return v if v<128 else v-256
def state():return {'mode':ram[0x100],'x':word(0x94),'y':word(0x96),'vx':signed(ram[0x7b])/16,'vy':signed(ram[0x7d])/16,'air':ram[0x72],'blocked':ram[0x77],'level':ram[0x13bf]}
def run(n,keys=()):
 global buttons
 buttons=set(keys)
 for i in range(n):core.retro_run()
 return state()
def png(name):
 data,w,h,pitch=last_frame;rows=[]
 for y in range(h):
  row=bytearray([0])
  for x in range(w):
   v=struct.unpack_from('<H',data,y*pitch+x*2)[0]
   row.extend((((v>>11)&31)*255//31,((v>>5)&63)*255//63,(v&31)*255//31))
  rows.append(bytes(row))
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 (ROOT/name).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b''))

# Real boot/menu inputs to a flat starting area. No patched ROM or game code.
run(380);run(1,[3]);run(60);run(1,[0]);run(60);run(1,[0]);run(60)
run(1,[0]);run(500);run(60,[7]);run(1,[0]);run(180)
run(1,[3]);run(300);run(90,[7]);run(20);run(1,[0]);run(180)
run(90,[7]);run(20);run(1,[0]);run(180)
assert state()['mode']==20 and state()['air']==0, state()
core.retro_serialize_size.restype=C.c_size_t
size=core.retro_serialize_size();buf=C.create_string_buffer(size)
core.retro_serialize.argtypes=[C.c_void_p,C.c_size_t];core.retro_serialize.restype=C.c_bool
assert core.retro_serialize(buf,size)
core.retro_unserialize.argtypes=[C.c_void_p,C.c_size_t];core.retro_unserialize.restype=C.c_bool
saved=buf
def reset():
 assert core.retro_unserialize(saved,size)
 run(2)
def trace(n,keys=(),fixed_x=False):
 result=[]
 for i in range(n):
  if fixed_x:ram[0x94]=32;ram[0x95]=0
  result.append(run(1,keys))
 return result
out={}
for name,keys in [('walk',[7]),('run',[7,1])]:
 reset();out[name]=trace(55,keys)
 out[name+'_release']=trace(30)
 reset();trace(45,keys);out[name+'_reverse']=trace(45,[6]+([1] if name=='run' else []))
for running in [False,True]:
 for hold in [1,2,4,8,12,20,60]:
  reset()
  if running:trace(45,[7,1],True)
  base=state()['y'];t=[]
  for i in range(120):
   ram[0x94]=32;ram[0x95]=0
   keys=([7,1] if running else [])+([0] if i<hold else [])
   t.append(run(1,keys))
   if i>2 and not state()['air']:break
  out[('running' if running else 'standing')+'_jump_'+str(hold)]={'height':base-min(x['y'] for x in t),'frames':len(t),'trace':t}
reset();trace(40,[7,1],True);trace(6,[7,1,0],True);out['air_release']=trace(12,[0],True)
(ROOT/'measurements.json').write_text(json.dumps(out,indent=2))
for name,value in out.items():
 if isinstance(value,dict):print(name,value['height'],value['frames'])
 else:print(name,[(i+1,value[i]['vx'],value[i]['vy']) for i in [0,4,9,min(len(value)-1,19),len(value)-1]])
print('ROM table jump @ D2BD', args.rom.read_bytes()[0x52bd:0x52cd].hex())
print('ROM gravity @ D7A5', args.rom.read_bytes()[0x57a5:0x57af].hex())

(ROOT/'provenance.json').write_text(json.dumps({
 'rom_sha256':hashlib.sha256(args.rom.read_bytes()).hexdigest(),
 'core':str(args.core), 'state':state(),
 'method':'60 Hz emulator frames; vertical trials pin X to 32 in the flat starting area, preserving velocity. Small Mario, ordinary jump, no cape or Yoshi. Horizontal traces use natural movement.',
 'source':'https://archive.org/details/super-mario-world-usa_202406'
},indent=2))
core.retro_unload_game();core.retro_deinit()
