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
import matplotlib.pyplot as plt
import pygame
pygame.init()
pygame.mixer.pre_init(frequency=44100, size=-8, channels=1)
pygame.mixer.init()


Tap_LUT = [ 15 - 1, 11 - 1, 14 - 1, 5 - 1, 9 - 1, 7 - 1, 10 - 1, 12 - 1 ]
repeat = [32767,1953,254,217,73,63,42,28]

plt.figure(figsize=(24, 1.5 * 8))
ax = plt.subplot(111)

for t in range(8):
    lfsr = 1
    tapvalue = t<<12 #12 = (8) + 4!
    y=[]
    x=[]
    for i in range(260):
        
        feedback = ((lfsr >> 7) & 1) ^ ((lfsr >> Tap_LUT[(tapvalue >> 12) & 0x7]) & 1) ^ 1
        lfsr = ((lfsr << 1) & 0x7FFF) | feedback
        NoiseLatcher = ((lfsr & 1) << 6) - (lfsr & 1)
        #print i,lfsr,NoiseLatcher
        x.append(i)
        y.append(NoiseLatcher/64.0+2*t)
    
    
    ax.step(x, y , 'k-', where='mid')
    if len(x) > repeat[t]:
        ax.plot([repeat[t],repeat[t]], [t*2-0.5, t*2+1.5], 'r-', alpha=1)
    ax.text(0, t*2+1.3, 'tap:%d, length:%d' % (t,repeat[t]))
    #ax.set_ylim(0, 0.7 + 0.7 * nspectra)
    ax.set_xlabel(r'samples')
plt.show()    

lfsr = 1
tapvalue = t<<12 #12 = (8) + 4!
rawdata=[]
for i in range(4096):
        feedback = ((lfsr >> 7) & 1) ^ ((lfsr >> Tap_LUT[(tapvalue >> 12) & 0x7]) & 1) ^ 1
        lfsr = ((lfsr << 1) & 0x7FFF) | feedback
        NoiseLatcher = ((lfsr & 1) << 6) - (lfsr & 1)
        #print i,lfsr,NoiseLatcher
        rawdata.append(NoiseLatcher)
beep = pygame.mixer.Sound(buffer=bytes(rawdata))
pygame.mixer.Sound.play(beep)
pygame.quit()
