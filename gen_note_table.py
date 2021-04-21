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

from math import *

def vb(i):
    base=5000000
    delay=2048-i
    freq=base//delay//32
    return freq

def freq(n,a4):
    return (2**(1/12.0))**(n-49)*a4

base_list=[1,2,4,8,16,32,64]

def best_match(freq):
    best=999
    
    best_timer=0
    best_freq=0
    for timer in range(2048):
            h=vb(timer)
            delta = fabs(h-freq)
            if delta < best:
                best=delta
                best_timer=timer
                best_freq=h
    return best,best_freq,best_timer 
                
note_bases="c,c#,d,d#,e,f,f#,g,g#,a,a#,b".split(',')

notebook={}
pos=0
data_lo=[]
data_hi=[]
factor=0
for i in range(19,118):
        base_freq=440.0* (2**(1/48.0))**factor #0,1,2,3
        aim=freq(i,base_freq)
        note_ptr=(i+8)%12
        octave=(i+8)//12
        note=note_bases[note_ptr]+"%d"%octave
        
        off,found,timer=best_match(aim)
        print ("%d\t%d\t%s\t%.1f\t%.1f\t%.1f\t%02x" % (pos,i,note,aim,found,((off)/aim*100.0),timer) )
        notebook[note]=pos
        pos+=1
        data_lo.append(timer&0xff)
        data_hi.append(timer>>8)

timelo_file=open('note_timelo.bin','wb')
timehi_file=open('note_timehi.bin','wb')
timelo_file.write(bytearray(data_lo))
timehi_file.write(bytearray(data_hi))


    
        
