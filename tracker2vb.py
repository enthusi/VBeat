#Licensed under the 3-Clause BSD License
#Copyright 2021, Martin 'enthusi' Wendt / PriorArt
#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
#3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import sys
from math import *
verbose=False
global data
filename=sys.argv[1]
filenamebase=filename[:-4]
datfilename=filenamebase+".bin"
infile=open(filename,'rb')
data=infile.read()

a4=440.0

def flush(data):
    for i in data:
        print('%02x ' % i, end='')
        
def freq(n):
    return (2**(1/12.0))**(n-49)*a4

base_list=[1,2,4,8,16,32,64]

def best_match(freq):
    best=999
    best_base=0
    best_timer=0
    best_freq=0
    for base in base_list:
        for timer in range(1,256):
            h=1.0/(1e-6*base*timer)
            delta = fabs(h-freq)
            if delta < best:
                best=delta
                best_base=base
                best_timer=timer
                best_freq=h
    return best,best_freq,best_base,best_timer 

def get16bit(ptr):
    return (data[ptr+1])*256+(data[ptr])

def get8bit(ptr):
    return (data[ptr])
#http://lclevy.free.fr/mo3/s3m.txt

#  0020: |OrdNum |InsNum |PatNum | Flags | Cwt/v |  Ffv  |'S'|'C'|'R'|'M'|
#        +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
#  0030: |g.v|i.s|i.t|m.v| x | x | x | x | x | x | x | x | x | x |Special|
#        +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
#  0040: |Channel settings for 32 channels, 255=unused,+128=disabled     |

ordnum=get16bit(0x20)
insnum=get16bit(0x22)
patnum=get16bit(0x24)

#print(patnum)

len_orders=ordnum
len_instruments=insnum*2
len_patterns=patnum*2
ptr_patterns=0x60+len_orders+len_instruments

parapointers=[]
pattern_pos=[]
for i in range(0,patnum*2,2):
    v = get16bit(ptr_patterns+i)*16
    pattern_pos.append(v)
#print(pattern_pos)

playlist_entries=[]
playlist=open('%s_playlist.bin' % filenamebase,'wb')
for i in range(ordnum):
    v=get8bit(0x60+i)
    if v<255:
        playlist_entries.append(v)
    #print(v)
playlist.write(bytearray(playlist_entries))    

if verbose: print (pattern_pos)
if verbose: print (patnum)

keys = ['c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b']
allowed_commands =[1,2,3]
panning_commands=[19] #new!
offsets=open('%s_patoffsets.bin' % filenamebase,'wb')

patpak=open(datfilename,'wb')

if verbose: print(pattern_pos)
pat=0   
global_len=0x0000
for pattern_chunk in range(patnum):
  channel=0
  pattern=[]
    #prefill 1 or more patterns with 'empty'
  for i in range(65*10):
    pattern.append(["-","-","-"])
  patdat=[]
  for p in [pattern_pos[pattern_chunk]]:#[pattern_pos[0]]:
    if p==0:
        print('EMPTY pattern: %d' % pattern_chunk)
        break
    i=0
    row=0
    
    while row<64:
        cmd=0
        info=0
        pos=p+i
        channel=0xff
        #note='-'
        #just get that out of the way
        if i==0:
            v=get16bit(p+i)
            i+=2
            if verbose: print ("pattern_data_length=", hex(v),v)
            if verbose: print
            offset=[]
            offset.append(global_len&0xff)
            offset.append(global_len>>8)
            offsets.write(bytearray(offset))
            
        v = get8bit(p+i)
        i+=1
        if v==0:
            #row done, we use ff as marker
            if verbose: print ("---",row)
            row+=1
            patdat.append(0xff)
            continue
            
        if verbose: print ('channel', (v&0x1f))
        channel=v&0x1f
        note=0 #means nothing
        octave=0
        inst=0
        NOTE_CORRECTION=-1
        OCTAVE_CORRECTION=0
        if v&0x20:
            note=get8bit(p+i)
            octave=(note>>4)-OCTAVE_CORRECTION
            note=note&0xf
            i+=1
            inst=get8bit(p+i)
            i+=1
            if verbose: print ("n:",note,octave,"i:",inst)
        
        if inst==0: datanote=0
        datanote=note+octave*12 +1 - NOTE_CORRECTION#+1 to keep 0 as none

        if True:
            patdat.append(channel)
            patdat.append(datanote)
        
        databyte=0
        vol=1
        if v&0x40:
            vol=get8bit(p+i)
            i+=1
            if verbose: print ("v:",vol)
            databyte+=0x80
            
        if v&0x80:
            cmd=get8bit(p+i)
            i+=1
            info=get8bit(p+i)
            i+=1
            if verbose: print ("c:",cmd,"t:",info)
            if cmd in allowed_commands:
                databyte+=0x40
            if cmd in panning_commands:
                databyte+=0x20 #should be safe, 0x1f max instruments!
            
        databyte+=inst
        if True:  patdat.append(databyte)
        
        #new: panning should come FIRST!
        if databyte&0x20:
            writebyte=info-0x80 #should be 0..f for panning
            if True: patdat.append(writebyte)
            if verbose: print ("PANNING",cmd,info,writebyte)
            
        if databyte>=0x80:
            if vol>63: vol=63
            writebyte=vol
            if verbose: print ("VOLUME",cmd,info,vol)
            if True: patdat.append(writebyte)
            
        if databyte&0x40:
            if verbose: print ("command used",cmd,info)
            if cmd==1: #tempo Axx
                writebyte=0x80
                writebyte+=info
                if True: patdat.append(writebyte)
            if cmd==2: #break to order Bxx
                writebyte=0x40
                writebyte+=info
                if True: patdat.append(writebyte)
            if cmd==3: #break here Cxx
                writebyte=0x40 #flag command (act as Bxx)
                writebyte+=0x3f #manually set to 0x3f
                if True: patdat.append(writebyte)
                if verbose: print ("added end order")
                
        if verbose: print
        if verbose: flush(patdat)
  pat+=1
  
  if verbose: print (patdat),
  for i in range(len(patdat)):
      b=patdat[i]
      if b>255: print ("Too large values:",i,b)
  databytes=bytearray(patdat)
  
  patpak.write(databytes)
  global_len+=len(databytes)
  
patpak.close()
#==========================================================
#former column formatter part
names = ['c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b','?']

for selection in [0,1,2,3,4,5]:
    infile=open(datfilename,'rb')

    data=infile.read()
    row=0
    i=0
    pattern=0
    column_data=[]
    current_pos=0
    column=[]
    pattern_starts=[]
    pattern_len=64
    chan_set=False
    channel_file=open('channel%d_stream4.dat' % selection,'wb')
    col_ptr_file=open('col_ptr%d.dat' % selection,'wb')
    col_offsets_file=open('col_offsets%d.dat' % selection,'wb')
    col_pointers=[]
    pos_of_last_control_byte=0
    for g in range(len(data)):
        volume=-1
        tempo=-1
        neworder=-1
        instrument=-1
        note=-1
        channel=-1
        v=int(data[i])
        i+=1
        
        if v==0xff: #row done
            row+=1
            if not chan_set: #this means, we completed a row WITHOUT
                #our current channel ever having an entry -> empty line
                
                #check if the last control byte has the 0-follows flag set
                #if not, set it and skip the 0
                #if set we skipped one already
                if row==1: #in case this happened on first row
                    pos_of_last_control_byte=0 #init  stream with 0
                    column.append(0)
                    continue
                try:
                    last_controlbyte=column[pos_of_last_control_byte]
                except:
                    print (pos_of_last_control_byte, len(column), column)
                    print ("ERROR")
                    sys.exit(1)
                    
                    
                if (last_controlbyte&1)==0: #1 indicates RLE run following
                    #we already added a single line to skip 
                    #initiate RLE byte
                    rle_start = 1 #+ 1*4 #3 sets bit0+1 and 1*4 means 1 zero byte
                    #column[pos_of_last_control_byte]=rle_start
                    if verbose: print ("we initiate RLE run",pos_of_last_control_byte,row,len(column))
                    column.append(rle_start)
                    pos_of_last_control_byte=len(column)-1
                
                elif (last_controlbyte & 1) ==1: #we alraady startet RLE run
                    last_controlbyte+=(1<<1) #was 4 = (1<<2)
                    column[pos_of_last_control_byte]=last_controlbyte
                    if verbose: print ('we add more zeros',last_controlbyte>>2)
                
                else:
                    if verbose: print (">3 empty rows", pos_of_last_control_byte,last_controlbyte & 3)
                    column.append(0) #if nothing happens, add a 0
                
            
            chan_set=False
            if row==pattern_len:
                row=0
                
                pattern+=1
                
                if column not in column_data:
                    column_data.append(column)    
                    pattern_starts.append(current_pos)
                    current_pos+=len(column)
                
                
                
                col_ptr=column_data.index(column)
                col_pointers.append(col_ptr)
                
                column=[]
            if i>= len(data):
                break
            if verbose: print ("---",pattern,row,"---")
            continue
        else:
            
            channel=v
            v=int(data[i])
            i+=1
            if channel==selection:
                chan_set=True
                pos_of_last_control_byte=len(column)
                
            if verbose: print ("c:",channel,)
            
            #THIS CAUSED THE BUG 20213
            if v == 2:
                datanote = 1
            else:
                datanote=v-14
            #else:
            #    datanote = 2
            note=(datanote)%12-1
            octave=(datanote)/12+1
            
            if channel==selection:
                column.append((datanote<<1)&0xfe) #v is datanote << 1, bit0 cleared
            
            if verbose: print ("n:",names[note],octave,datanote,)
            d=int(data[i])
            i+=1
            instrument=d&0x1f
            if verbose: print ("i:",instrument,)
            
            if channel==selection:
                column.append(d)
            
            #new check PANNING first!
            if d&0x20 :
                c=int(data[i])
                i+=1
                panning=c
                if verbose: print( "panning:",panning,)
                if channel==selection:
                    column.append(panning)
                    
            if d&0x80:
                c=int(data[i])
                i+=1
                volume=c
                if verbose: print ("v:",volume,)
                if channel==selection:
                    column.append(volume)
                
            if d&0x40: #command
                f=int(data[i])
                i+=1
                if channel==selection:
                    column.append(f)
                if f&0x80:
                    tempo=(f&0x3f)
                    if verbose: print ("t:",tempo,)
                if f&0x40:
                    neworder=(f&0x3f)
                    if verbose: print ("ord:",neworder,)
        if verbose: print (' ')

    if verbose: print (len(column_data)   , len(col_pointers) )
    if verbose: print (col_pointers)
    if verbose: print (pattern_starts)

    #old_off=0
    for offset in pattern_starts:
        col_offsets_file.write(bytearray([offset&0xff]))
        col_offsets_file.write(bytearray([offset>>8]))
        #size=offset-old_off
        #print(size,hex(size))
        
    databytes=bytearray(col_pointers)
    col_ptr_file.write(databytes)
    
    for col in column_data:
        pattern_size=(len(col))
        #print(hex(pattern_size))
        if pattern_size>255:
            print('WARNING, pattern too long! Exceeding 8bit length')
            sys.exit(1)
        databytes=bytearray(col)
        channel_file.write(databytes)
        
    channel_file.close()
