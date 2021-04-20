# VBeat
VirtualBeat Audio Engine for the Virtual Boy console by [PriorArt](http://priorartgames.eu).

## Credits
all code: Martin 'enthusi' Wendt
all audio: Kamil 'jammer' Wolnikowski
8x16 font: Oliver 'v3to' Lindau

## Specs
- 100% handwritten v810 Assembler
- provided song takes up to 450us (~2% of a frame which is 20ms) for heavy frames
  on average much less!
-  converts S3M modules to engine format (we use the great free [Schismtracker](http://schismtracker.org/screenie.png)
- all 6 channels
- channel 6 dedicated to 'noise' instruments
-  featuring 'low' notes and precussion for noise channel
-  exhange 1-5 WAVE tables on the fly
- lowest direct note is d#2 (hardware limit)
- up to 30 instruments supported

###  supported effects in S3M tracker:
-- tempo (currently in units of frames) (can be set at any column and without an instrument)
-- volume 0-63 (gets divided to 0-15 by player!) (can be set without an instrument)
-- panning (S8x) x=0-6 from all left to all right. 3 being center 
-- continue with pattern xx (Bxx)  (can be set at any column)
-- continue with NEXT pattern (break) as 'C00'  (identical to B3F)

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
You can find the tools as part of the official SDK packs for later consoles!
[SDK package](https://www.retroreversing.com/official-gameboy-software-dev-kit)

## The player documentation
The VBeat player as provided shows the current pattern row on the left.
Followed by pattern data for all 6 channels.
From left to right the following is shown: note, instrument, volume, panning
The command to exchange the set of waves is indicated by the set number and an arrow.
The top left numbers show the current playlist position, the current pattern and the current
pattern speed (pattern read every n frames).
There is a small arrow next to the channel numbers on top. You can move it with left/right 
and **mute/unmute individual channels with the A-button.**
The **B-button toggles between the main song and some demo patterns.**
With up/down you can change the rate of player calls for the 100us timer.
![screenshot](http://martinwendt.de/2021/vbeat/example-screen_editor.png)

## Thanks
To GuyPerfect for his deep skills and wonderful [tech specs](http://perfectkiosk.net/stsvb.html) for the Virtual Boy.
To Kresna for writing and publishing the assembly source for this very nice game [Red Square](http://slum.online/vb)
