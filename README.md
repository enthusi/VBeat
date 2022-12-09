# VBeat
A tracker based free *VirtualBeat Audio Engine* for the ***Virtual Boy*** console by [PriorArt](http://priorartgames.eu).\
Download zipped 16KB ROM image directly: [VBeat16k_PriorArt.zip](http://martinwendt.de/2021/vbeat/VBeat16k_PriorArt.zip).
## In action
- [MP3 recording from real hardware](http://martinwendt.de/2021/vbeat/vbeat_recording.mp3)
- YouTube recording:\
[![Vbeat on YouTube](http://img.youtube.com/vi/GvSOXE-GMVo/0.jpg)](http://www.youtube.com/watch?v=GvSOXE-GMVo "VirtualBeat Audio Engine for the Virtual Boy")
## Credits
- code: *Martin 'enthusi' Wendt*
- audio: *Kamil 'jammer' Wolnikowski*
- 8x16 font: *Oliver 'v3to' Lindau*
## Specs
- 100% handwritten v810 Assembler
- player takes up to 450us (~2% of a frame which is 20ms) for heavy frames -  on average much less!
-  converts S3M modules to engine format (we use the great free [Schismtracker](http://schismtracker.org/screenie.png))
- all 6 channels
- channel 6 dedicated to 'noise' instruments
-  featuring 'low' notes and precussion for noise channel
-  exhange 1-5 WAVE tables on the fly
- lowest direct note is d#2 (hardware limit)
- up to 30 instruments supported
###  supported effects in S3M tracker:
- tempo (currently in units of frames) (can be set at any column and without an instrument)
- volume 0-63 (gets divided to 0-15 by player!) (can be set without an instrument)
- panning (S8x) x=0-6 from all left to all right. 3 being center 
- continue with pattern xx (Bxx)  (can be set at any column)
- continue with NEXT pattern (break) as 'C00'  (identical to B3F)
## The player
![screenshot](http://martinwendt.de/2021/vbeat/example-screen.png)
The source code provides the full player as well as a full framework to assemble
the example tune with player. 
Further down you find an explanation of the information shown by the player.
## Compilation
To assemble the provided sources you need the official ISAS assembler (ISAS32.EXE) + linker (ISLK32.EXE)
as well as some tool to extract a VB rom file (.vb) from the native .isx format (VUIC.EXE).
The provided Makefile assumes all of those three binaries to be present.
The engine was developed on a linux system. All tools run well in WINE or DOSBOX.
The tools are available here for example:
[ISAS](https://www.virtual-boy.com/tools/isas-islk-dev-kit/).
You can find the tools as part of the official SDK packs for later consoles as well.
[SDK package](https://www.retroreversing.com/official-gameboy-software-dev-kit)
## The player documentation
The VBeat player as provided shows the current pattern row on the left.
Followed by pattern data for all 6 channels.
From left to right the following is shown: note, instrument, volume, panning
The command to exchange the set of waves is indicated by the set number and an arrow.
The top left numbers show the current playlist position, the current pattern and the current
pattern speed (pattern read every n frames).
There is a small arrow next to the channel numbers on top.\
You can move it with left/right 
and **mute/unmute individual channels with the A-button.**\
The **B-button toggles between the main song and some demo patterns.**
With up/down you can change the rate of player calls for the 100us timer.
![screenshot](http://martinwendt.de/2021/vbeat/explain.png)
# The Engine
## How to use it
- compose your S3M, feel free to learn by editing the provided tune `VBDemo01.s3m`.
- convert it into proper data format: `python3 tracker2vb.py VBDemo01.s3m`.
- run `make` or alternatively execute the following commands:
 ```
 wine ISAS32.exe -w 3  -t engine.asm -o music.o
wine ISLK32.exe music.o -t -v -map -o music.isx
wine VUIC.EXE music.isx music.vb
```
## Wave forms
We provide all the wave forms (a 32 Bytes) used in the Jazz tune as well as the technical demo.\
You will also find a tool to create wave forms from PNG images (64x32 pixels): `bitmap2wave.py`.\
Usage:
```python3 bitmap2wave.py wario.png```
We also provide a very basic tool to convert 8bit samples to 6bit samples: `sample8to6.py`.
## Instruments
basenote = note as given in S3M\
all stored in songdata.vbasm\
set up *INSTRUMENT_TABLE* \
example:
```
INSTRUMENT_TABLE 
    dw 0;dummy ALWAYS at first position
    dw script_instrument_0 
    dw script_instrument_1
    dw script_instrument_2
  ```  
Controls are (in this order!)
- HARDNOTE    equ  64  ;16 bit  does NOT affect BASENOTE (use it in every row that you need it)
- VOL         equ   8  ;8 (4)
- WAVE        equ   4  ;8 (3)
- NOTE_OFF    equ  16  ;8  based on BASENOTE (changes BASENOTE!)
- FREQ_OFF    equ  32  ;8  based on BASENOTE (can now be used with NOTE_OFF)
- LOOPER      equ 128  ;8

*HARDNOTE*: sets a numerical note temporary:  0 = d#2 ...\
it takes TWO bytes now:\
byte1: numerical note (will not sound like it!) in half-tone steps\
byte2: fine shift relative to byte1 in +/- 127\
*VOL* 0..63 changes volume (overrides channel volume!)\
*WAVE* sets waveform 0-5 for channel1-5\
WAVE in channel6: noise-form + $80\
*NOTE_OFF* signed  byte as offset to current basenote (or normal instrument note)\
    in steps of notes. It changes the basenote to basenote + NOTE_OFF\
*FREQ_OFF* signed  byte as offset to current basenote (or normal instrument note)\
    in setps of 16bit frequency which CAN be finer than notes (depends on range)\
*LOOPER* use this to loop within an instrument definition, use no other command on that line!
**Always end instrument definition with 'db 0'**
**End with Vol 0 if it should stop playing**
*use (-5 & $ff) for negativ values if the assembler complains!*
### Exchange wave tables on the fly (any number in predefined sets).
instrument 31 means: change wave(s)\
the note then defines the new wave set: d#2 = 0\
The player shows set number + arrow\
the wave change will occur on next pattern-read!\
A set consists of 5 pointers into your wave data plus 3 filler bytes.\
A pointer of -1 does not change the corresponding wave.
```
WAVESET_TABLE
    db  0, 1, 2, 3, 4, 0, 0, 0 ;sets wave0-4 to the first 5 waves
    db -1, 5, 6,-1,-1, 0, 0, 0 ;only changes wave 1 and 2 (to 5th and 6th wave data)
```    
## Instrument examples
*Vibrato instrument:*
```
script_instrument1
    db 2, WAVE | NOTE_OFF, 1, 1
_loopstart
    db 1, FREQ_OFF, (-5 & $ff)
    db 1, FREQ_OFF, (-7 & $ff)
    db 1, FREQ_OFF, (-9 & $ff)
    db 1, FREQ_OFF, (-7 & $ff)
    db 1, FREQ_OFF, (-5 & $ff)
    db 1, FREQ_OFF, (-3 & $ff)
    db 1, FREQ_OFF, (-1 & $ff)
    db 1, FREQ_OFF, ( 1 & $ff)
    db 1, FREQ_OFF, (-1 & $ff)
_loopend
    db 1, LOOPER, (_loopend - _loopstart )
    db 0
 ```
*simple single tone for ~ 1 second*
```
script_instrument5
    db 50, WAVE 4
    db 1, VOL,0
    db 0
 ```

*bass+hihat for channel6 (-> WAVE = $86)*
```
script_instrument_trap0
    db 5, HARDNOTE | VOL | WAVE, 15, 63, $86
    db 1, VOL, 32
    db 1, VOL, 16
_loopstart    
    db 4, VOL, 0
    db 1, HARDNOTE | VOL | WAVE  , 65, 32, $80
    db 1, HARDNOTE | VOL | WAVE , 66, 63, $80
    db 1, HARDNOTE | VOL | WAVE , 67, 0, $80
    db 1, HARDNOTE | VOL | WAVE , 67, 32, $80
    db 1, HARDNOTE | VOL | WAVE , 67, 0, $80
_loopend
    db 1, LOOPER, (_loopend - _loopstart )
    db 0
```
## Noise instruments
We provide a tool to show all 8 possible noise patterns , along with their repetition length (which directly influence the perceived pitch):
`python lfsr.py` which creates this graph:
![noise patterns](http://martinwendt.de/2021/vbeat/noise.png)
Note, how the upper few values have a certain period (which is still longer than the 32 wave table samples played at lowest frequency for channels 1-5).

## Engine data format
- 'col_ptr0.dat'      contains the indexes to unique pattern columns for channel 0
- 'col_offsets0.dat'  contains the 16bit offsets per unique pattern column into stream data
- 'channel0_stream4.dat' the actual pattern data for channel 0.

example pattern:
```
0e 41 85 07 0e 01 05 0e 01 07 0e 01 09 14 01 55
```
means:
```
0e ; bit0 = 0 -> no skip single row, >>1 = Note = 7. 7-3 = 4 -> G-2
41 ; &0x3f = 1 -> instrument. 0x40 -> CMD coming in
85 ; requested CMD byte (bit 7 =tempo, bit6 = break. Here: tempo to 5
07 ; bit0 = 1 -> skip 7/2 +1 = 4 rows
0e ; another G-2
01 ; instrument 1
05 ; skip 3 rows
0e ; G-2
01 ; Instr 1
07 ; skip 4 rows
0e ; G-2
01 ; Instr 1
09 ; skip 5 rows
14 ; Note = 10-3 = 7  = A#2
01 ; instrument 1
55 ; skip 55//2 +1 = 43 rows
-> all 64 rows done
```
## Engine work flow
```
1) first set which pattern to play next:

read current playlist pointer
read pattern-number at offset from playlist
if bit7 is set:
    restart song
use pattern-number as pointer into column_table (for current channel!)
read 16bit offset for the requested column in column stream
write start of stream data for this channel
loop the above for all channels

2) then audio_read_pattern_data:

fetch byte
    if bit0==1: 
       byte/2 = number of rows to skip minus 1
    is it a REAL note or a dummy? '2' means dummy
    store byte/2 as note (plus 3!)
    read another byte
    byte & 0x1f is the new instrument
    is the instrument >25? Then it is a flag to 
       exchange a wave. Instruments points to 
       destination and note is the source
    byte & 0x20 is the PANNING flag
    if PANNING:
       read new byte and store as panning 0-6 (0=left, 6=right, 3=center)
    byte & 0x80 is the VOLUME flag
    if VOLUME:
       read new byte and store as volume
    apply panning to current volumne
    byte & 0x40 means COMMANDS coming in
    if COMMANDS:
       read new byte
       byte & 0x80 is TEMPO flag
       byte & 0x40 is BREAK flag
    if BREAK:
       set global break flag
       set target to byte & 0x3f
    if TEMPO:
       set global tempo to byte & 0x3f
if REAL note:
    start instrument

loop the above for all columns
then:
if BREAK:
    if break target == 0x3f:
        break to next entry in playlist
    else:
        break to target playlist entry
        
big loop all of the above for all rows

3) play/update instrument
this is done per channel:
is an instrument playing currently?
if not:
    skip this channel
increase individual instrument pointer
have we reached the next step?
if not:
    done for this channel
fetch the current pointer into the instrument description
and read new instrument byte
if byte==0:
    instrument done
else:
    byte is counter for next instrument update (in 'frames')
read new instrument byte
there are multiple bit flags: HARDNOTE, VOL, WAVE, NOTE_OFF, FREQ_OFF, LOOPER
if HARDNOTE:
    read new note table pointer byte (full note)
    read new raw frequency offset byte 
    set new channel frequency
    do NOT touch base note
if VOL:
    read new channel volume byte
    apply current panning via table
    set new channel volume
if WAVE:
    read new wave byte
    if byte & 0x80:
        interpret byte - 0x80 as noise trap byte 0-7
    (we use illegal waves to mute an instrument too)
if NOTE_OFF:
    read byte
    add signed half note offset to current base note
    set new channel frequency
    and write new base note
if FREQ_OFF:
    read byte
    add signed frequency offset to current base note
    set new channel frequency
    do NOT touch base note
if LOOPER:
    read signed byte
    add offset to current instrument pointer + correction for offset
    next instrument update will read from new offset address!
```
### Note Table (not required by user)
We wrote a tool to find the best 16bit frequency register values for the classical notes.
output of gen_note_table.py (python 2).
You can tell by the frequency bytes how a FREQ_OFF +/- affects the note
with a much finer grain than NOTE_OFF for low notes. For higher notes, it becomes the same as NOTE_OFF!
```
the columns show: HARDNOTE, base, note, frequency, VB_ferquency, offset in %, 16bit freq. register values

0	19	d#2	77.8	78.0	0.3	2d
1	20	e2	82.4	82.0	0.5	8f
2	21	f2	87.3	87.0	0.4	fd
3	22	f#2	92.5	92.0	0.5	15e
4	23	g2	98.0	98.0	0.0	1c6
5	24	g#2	103.8	104.0	0.2	222
6	25	a2	110.0	110.0	0.0	274
7	26	a#2	116.5	117.0	0.4	2c9
8	27	b2	123.5	123.0	0.4	30a
9	28	c3	130.8	131.0	0.1	358
10	29	c#3	138.6	139.0	0.3	39c
11	30	d3	146.8	147.0	0.1	3da
12	31	d#3	155.6	156.0	0.3	417
13	32	e3	164.8	165.0	0.1	44e
14	33	f3	174.6	175.0	0.2	484
15	34	f#3	185.0	185.0	0.0	4b4
16	35	g3	196.0	196.0	0.0	4e3
17	36	g#3	207.7	208.0	0.2	511
18	37	a3	220.0	220.0	0.0	53a
19	38	a#3	233.1	233.0	0.0	562
20	39	b3	246.9	247.0	0.0	588
21	40	c4	261.6	262.0	0.1	5ac
22	41	c#4	277.2	277.0	0.1	5cc
23	42	d4	293.7	294.0	0.1	5ed
24	43	d#4	311.1	311.0	0.0	60a
25	44	e4	329.6	330.0	0.1	627
26	45	f4	349.2	349.0	0.1	641
27	46	f#4	370.0	370.0	0.0	65a
28	47	g4	392.0	392.0	0.0	672
29	48	g#4	415.3	415.0	0.1	688
30	49	a4	440.0	440.0	0.0	69d
31	50	a#4	466.2	466.0	0.0	6b1
32	51	b4	493.9	494.0	0.0	6c4
33	52	c5	523.3	524.0	0.1	6d6
34	53	c#5	554.4	554.0	0.1	6e6
35	54	d5	587.3	587.0	0.1	6f6
36	55	d#5	622.3	622.0	0.0	705
37	56	e5	659.3	659.0	0.0	713
38	57	f5	698.5	697.0	0.2	720
39	58	f#5	740.0	740.0	0.0	72d
40	59	g5	784.0	785.0	0.1	739
41	60	g#5	830.6	831.0	0.0	744
42	61	a5	880.0	882.0	0.2	74f
43	62	a#5	932.3	930.0	0.2	758
44	63	b5	987.8	988.0	0.0	762
45	64	c6	1046.5	1048.0	0.1	76b
46	65	c#6	1108.7	1108.0	0.1	773
47	66	d6	1174.7	1174.0	0.1	77b
48	67	d#6	1244.5	1240.0	0.4	782
49	68	e6	1318.5	1324.0	0.4	78a
50	69	f6	1396.9	1395.0	0.1	790
51	70	f#6	1480.0	1474.0	0.4	796
52	71	g6	1568.0	1562.0	0.4	79c
53	72	g#6	1661.2	1662.0	0.0	7a2
54	73	a6	1760.0	1755.0	0.3	7a7
55	74	a#6	1864.7	1860.0	0.2	7ac
56	75	b6	1975.5	1977.0	0.1	7b1
57	76	c7	2093.0	2083.0	0.5	7b5
58	77	c#7	2217.5	2232.0	0.7	7ba
59	78	d7	2349.3	2332.0	0.7	7bd
60	79	d#7	2489.0	2480.0	0.4	7c1
61	80	e7	2637.0	2648.0	0.4	7c5
62	81	f7	2793.8	2790.0	0.1	7c8
63	82	f#7	2960.0	2948.0	0.4	7cb
64	83	g7	3136.0	3125.0	0.3	7ce
65	84	g#7	3322.4	3324.0	0.0	7d1
66	85	a7	3520.0	3551.0	0.9	7d4
67	86	a#7	3729.3	3720.0	0.2	7d6
68	87	b7	3951.1	3906.0	1.1	7d8
69	88	c8	4186.0	4222.0	0.9	7db
70	89	c#8	4434.9	4464.0	0.7	7dd
71	90	d8	4698.6	4734.0	0.8	7df
72	91	d#8	4978.0	5040.0	1.2	7e1
73	92	e8	5274.0	5208.0	1.3	7e2
74	93	f8	5587.7	5580.0	0.1	7e4
75	94	f#8	5919.9	6009.0	1.5	7e6
76	95	g8	6271.9	6250.0	0.3	7e7
77	96	g#8	6644.9	6510.0	2.0	7e8
78	97	a8	7040.0	7102.0	0.9	7ea
79	98	a#8	7458.6	7440.0	0.2	7eb
80	99	b8	7902.1	7812.0	1.1	7ec
81	100	c9	8372.0	8223.0	1.8	7ed
82	101	c#9	8869.8	8680.0	2.1	7ee
83	102	d9	9397.3	9191.0	2.2	7ef
84	103	d#9	9956.1	9765.0	1.9	7f0
85	104	e9	10548.1	10416.0	1.3	7f1
86	105	f9	11175.3	11160.0	0.1	7f2
87	106	f#9	11839.8	12019.0	1.5	7f3
88	107	g9	12543.9	13020.0	3.8	7f4
89	108	g#9	13289.8	13020.0	2.0	7f4
90	109	a9	14080.0	14204.0	0.9	7f5
91	110	a#9	14917.2	15625.0	4.7	7f6
92	111	b9	15804.3	15625.0	1.1	7f6
93	112	c10	16744.0	17361.0	3.7	7f7
94	113	c#10	17739.7	17361.0	2.1	7f7
95	114	d10	18794.5	19531.0	3.9	7f8
96	115	d#10	19912.1	19531.0	1.9	7f8
```
## Memory footprint (roughly)
The Player itself (running in timer IRQ, but also possibly in Draw IRQ) with all features is less than 2 KB in size.\
The instrument definitions of the demo song are about 0.5 KB in size. \
The total songdata (instruments, tables and patterns) is just below 7KB in size (not further compressed in ROM).\
About 150 Bytes of RAM are used by the player (you can compress the songdata and depack into RAM of course).\
![memory map](http://martinwendt.de/2021/vbeat/memmap.png)
```
size
hex   dec   
0092 (146)	 VARIABLES
3d3d (15677) BINARY
0346 (838)	 INIT
02d4 (724)	 TIMERIRQ
07b8 (1976)	 PLAYER1
04c7 (1223)  TEXT
00f4 (244)   GENHEX
007c (124)	 DEPACK
1b48 (6984)	 SONGDATA
030f (783)	 INSTRUMENTS
1668 (5736)	 AUDIODATA
```
## Noteworthy Spin Offs
- ***LZ4 compression***: the engine data format itself is already pretty effective. But I wrote a depacker for the open LZ4 compression format in assembler. 
The player uses a compressed letter character set- as well as compressed world map for the masks to separate the channel columns from the background.
The resulted code is published under BSD 3-clause [here](https://github.com/enthusi/lz4_v810_decode) and recognized on the [official LZ4 page](http://lz4.github.io/lz4/).
- ***HEXFONT***: A very useful debug feature (that now made it into the final player) is the hexfont charset which shows 00-ff as 8x8 character. You can write 
the actual value of a byte into the world map and it gets displayed in hex digitis. The code to generate this font including the all the data is less than 256 Bytes long.
You find the public repository [here](https://github.com/enthusi/hexfont).
## Thanks
- To GuyPerfect for his deep skills and wonderful [tech specs](http://perfectkiosk.net/stsvb.html) for the Virtual Boy.
- To Kresna for writing and publishing the assembly source for this very nice game [Red Square](http://slum.online/vb).
