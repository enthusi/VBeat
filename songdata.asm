;all sources Licensed under the 3-Clause BSD License
;Copyright 2021, Martin 'enthusi' Wendt / PriorArt
;-----------------------------------------------------------
;Demo tune VBDemo01.s3m is Licensed under the 3-Clause BSD License
;Copyright 2021, Kamil 'jammer' Wolnikowski

begin_instruments
    EVEN 4
INSTRUMENT_TABLE 
    dw 0;dummy script_instrument0 ;0
    dw instrument_kick1 ;1
    dw instrument_bass1; 2
    dw instrument_hihatbass1; 3
    dw instrument_stickbass1 ;4
    dw instrument_rhodes1 ;5
    dw instrument_rhodes1delay ;6
    dw instrument_rhodes2 ;7
    dw instrument_rhodes3 ;8
    dw instrument_noisesnare1 ;9
    dw instrument_snare1 ;10
    dw instrument_brass1; 11
    dw instrument_brass1legato; 12
    dw instrument_brass1echo; 13
    dw instrument_brass2; 14
    dw instrument_funkyguitar1; 15
    dw instrument_shortfunkyguitar1; 16
    dw instrument_shortfunkyguitar2; 17
    dw instrument_shortfunkyguitar3; 18
    dw instrument_funkyguitardirt1; 19
    dw instrument_funkyguitardirt2; 20
    dw instrument_funkyguitardirt3; 21
    dw instrument_piano1; 22
;techdemo instruments   
    dw example_plain ;23/9
    dw example_vibrato ;24/;10
    dw example_instrument ;25/11
    dw example_instrument_2 ;26/12
    dw example_instrument_3 ;27/13
    dw example_simplewave;   28/14
;-----------------------------------------------------------    
;in this order:
HARDNOTE    equ  64  ;8  affects BASENOTE
VOL         equ   8  ;8 (4)
WAVE        equ   4  ;8 (3)
NOTE_OFF    equ  16  ;8  based on BASENOTE (not touching BASENOTE!)
FREQ_OFF    equ  32  ;8  based on BASENOTE (not in combo with NOTE_OFF!)
LOOPER      equ 128  ;8

;-----------------------------------------------------------    
    EVEN 4
script_instrument0
    db 1, VOL, 0
    db 0
    
instrument_kick1
    db 1, HARDNOTE | VOL | WAVE, 20, 1, 63, 0
    db 1, HARDNOTE |   VOL | WAVE, 14, 0, 63, 0
    db 1, HARDNOTE | VOL | WAVE, 10, 1, 63, 0
    db 1, HARDNOTE | VOL | WAVE, 5, 0, 48, 0
    db 1, HARDNOTE | VOL | WAVE, 0, 1, 32, 0
    db 1, VOL, 0
    db 0
	
instrument_snare1
    db 1, HARDNOTE | VOL | WAVE, 24, 2, 63, 0
    db 1, HARDNOTE | VOL | WAVE, 20, 2, 63, 0
    db 1, HARDNOTE | VOL | WAVE, 18, 2, 63, 0
    db 1, HARDNOTE | VOL | WAVE, 16, 2, 63, 0
    db 1, HARDNOTE | VOL | WAVE, 12, 2, 63, 0
    db 1, VOL, 0
    db 0
	
instrument_bass1
    db 1, VOL | WAVE | NOTE_OFF, 63, $87, 26
	db 1, VOL, 32
	db 1, VOL, 16
	db 8, VOL, 12
	db 1, VOL, 0
    db 0
	
instrument_hihatbass1
    db 1, HARDNOTE | VOL | WAVE, 95, 0, 16, $81
    db 1, VOL | WAVE | NOTE_OFF, 63, $87, 26
	db 1, VOL, 32
	db 1, VOL, 16
	db 8, VOL, 12
	db 1, VOL, 0
    db 0
	
instrument_stickbass1
    db 1, HARDNOTE | VOL | WAVE, 60, 0, 63, $84
    db 1, HARDNOTE | VOL | WAVE, 60, 0, 63, $81
    db 1, VOL | WAVE | NOTE_OFF, 63, $87, 26
	db 1, VOL, 32
	db 1, VOL, 16
	db 8, VOL, 12
	db 1, VOL, 0
    db 0

instrument_noisesnare1
    db 1, HARDNOTE | VOL | WAVE, 90, 0, 63, $80
    db 1, HARDNOTE | VOL | WAVE, 60, 0, 63, $80
	db 1, VOL, 32
	db 1, VOL, 16
	db 3, VOL, 8
	db 1, VOL, 0
    db 0
	
instrument_rhodes1
    db 1, VOL | WAVE | NOTE_OFF, 63, 1, (0 & 255)
	db 1, VOL, 40
	db 1, VOL, 38
	db 1, VOL, 36
	db 1, VOL, 34
	db 1, VOL, 32
	db 1, VOL, 30
	db 1, VOL, 28
	db 1, VOL, 26
	db 1, VOL, 24
	db 1, VOL, 20
	db 1, VOL, 18
	db 1, VOL, 14
	db 1, VOL, 12
instrument_rhodes1_loopstart
	db 1, FREQ_OFF, (2 & $ff)
	db 1, FREQ_OFF, (4 & $ff)
	db 1, FREQ_OFF, (6 & $ff)
	db 1, FREQ_OFF, (4 & $ff)
	db 1, FREQ_OFF, (2 & $ff)
	db 1, FREQ_OFF, (0 & $ff)
	db 1, FREQ_OFF, (-2 & $ff)
	db 1, FREQ_OFF, (-4 & $ff)
	db 1, FREQ_OFF, (-6 & $ff)
	db 1, FREQ_OFF, (-4 & $ff)
	db 1, FREQ_OFF, (-2 & $ff)
	db 1, FREQ_OFF, (0 & $ff) 
instrument_rhodes1_loopend
	db 1, LOOPER, (instrument_rhodes1_loopend - instrument_rhodes1_loopstart) 

instrument_rhodes1delay
	db 4, VOL, 63
instrument_rhodes1delay_loopend
	db 1, LOOPER, (instrument_rhodes1delay_loopend - instrument_rhodes1) 

instrument_rhodes2
	db 1, VOL | WAVE | NOTE_OFF, 63, 1, (-12 & 255)
	db 1, VOL | WAVE | NOTE_OFF, 63, 1, (24 & 255)
	db 1, VOL | WAVE | NOTE_OFF, 63, 1, (-12 & 255)
	db 1, VOL, 40
	db 1, VOL, 38
	db 1, VOL, 36
	db 1, VOL, 34
	db 1, VOL, 32
	db 1, VOL, 28
	db 1, VOL, 24
	db 1, VOL, 20
	db 1, VOL, 16
	db 1, VOL, 12
instrument_rhodes2_loopend
    db 1, LOOPER, (instrument_rhodes2_loopend - instrument_rhodes1_loopstart) 

instrument_rhodes3
    db 1, VOL | WAVE | NOTE_OFF, 63, 1, (12 & 255)
    db 1, VOL | WAVE | NOTE_OFF, 63, 2, (-12 & 255)
instrument_rhodes3_loopend
    db 1, LOOPER, (instrument_rhodes3_loopend - instrument_rhodes1_loopstart) 

instrument_piano1
    db 1, VOL | WAVE | NOTE_OFF, 48, 1, (0 & 255)
	db 1, VOL, 63
	db 1, VOL, 48
	db 1, VOL, 34
	db 1, VOL, 32
	db 1, VOL, 30
	db 1, VOL, 28
	db 1, VOL, 26
	db 1, VOL, 24
	db 1, VOL, 20
	db 1, VOL, 18
	db 1, VOL, 14
	db 1, VOL, 12
	db 1, VOL, 10
	db 1, VOL, 08
instrument_piano1_loopend
	db 1, LOOPER, (instrument_piano1_loopend - instrument_rhodes1_loopstart) 

instrument_brass1
    db 1, VOL | WAVE | NOTE_OFF, 60, 4, 0
	db 1, VOL, 63
	db 1, VOL, 62
	db 6, VOL, 60
instrument_brass1_loopstart
	db 1, FREQ_OFF, (8 & $ff)
	db 1, FREQ_OFF, (16 & $ff)
	db 1, FREQ_OFF, (8 & $ff)
	db 1, FREQ_OFF, (0 & $ff)
	db 1, FREQ_OFF, (-8 & $ff)
	db 1, FREQ_OFF, (-16 & $ff)
	db 1, FREQ_OFF, (-8 & $ff)
	db 1, FREQ_OFF, (0 & $ff) 
instrument_brass1_loopend
    db 1, LOOPER, (instrument_brass1_loopend - instrument_brass1_loopstart) 

instrument_brass1legato
    db 1, VOL | WAVE | NOTE_OFF, 56, 4, 0
    db 0

instrument_brass1echo
    db 1, WAVE | NOTE_OFF, 4, 0
    db 0

instrument_brass2
    db 3, VOL | WAVE | NOTE_OFF, 63, 3, (-2 & 255)
    db 3, VOL | WAVE | NOTE_OFF, 63, 3, (1 & 255)
    db 1, VOL | WAVE | NOTE_OFF, 63, 3, (1 & 255)
instrument_brass2_loopstart
	db 1, VOL, 32
	db 1, VOL, 63
instrument_brass2_loopend
    db 1, LOOPER, (instrument_brass2_loopend - instrument_brass2_loopstart) 

instrument_funkyguitar1
    db 1, VOL | WAVE | NOTE_OFF, 63, 3, (0 & 255)
    db 1, VOL | WAVE, 63, 2
    db 1, VOL | WAVE, 56, 1
    db 1, VOL | WAVE, 48, 2
    db 1, VOL | WAVE, 32, 3
	db 0
	
instrument_shortfunkyguitar1
    db 1, VOL | WAVE | NOTE_OFF, 63, 3, (0 & 255)
    db 1, VOL | WAVE, 48, 2
    db 3, VOL | WAVE, 32, 1
	db 1, VOL, 0
	db 0
	
instrument_shortfunkyguitar2
    db 1, VOL | WAVE | NOTE_OFF, 63, 1, (0 & 255)
    db 1, VOL | WAVE, 48, 2
    db 3, VOL | WAVE, 32, 3
	db 1, VOL, 0
	db 0
	
instrument_shortfunkyguitar3
    db 1, VOL | WAVE | NOTE_OFF, 63, 2, (0 & 255)
    db 1, VOL | WAVE, 48, 1
    db 3, VOL | WAVE, 32, 3
	db 1, VOL, 0
	db 0
	
instrument_funkyguitardirt1
    db 1, VOL | WAVE | NOTE_OFF, 64, 2, (0 & 255)
    db 1, VOL | WAVE, 32, 3
	db 1, VOL, 0
	db 0
	
instrument_funkyguitardirt2
    db 1, VOL | WAVE | NOTE_OFF, 32, 2, (0 & 255)
	db 1, VOL, 0
	db 0
	
instrument_funkyguitardirt3
    db 1, VOL | WAVE | NOTE_OFF, 32, 3, (0 & 255)
	db 1, VOL, 0
	db 0
	
;examples

example_plain
    db 35, WAVE, 0
    db 1, VOL, 0
    db 0
    
example_vibrato
    db 2, WAVE | NOTE_OFF, 1, 1
_loopstart1
    db 1, FREQ_OFF, (-5 & $ff)
    db 1, FREQ_OFF, (-7 & $ff)
    db 1, FREQ_OFF, (-9 & $ff)
    db 1, FREQ_OFF, (-7 & $ff)
    db 1, FREQ_OFF, (-5 & $ff)
    db 1, FREQ_OFF, (-3 & $ff)
    db 1, FREQ_OFF, (-1 & $ff)
    db 1, FREQ_OFF, ( 1 & $ff)
    db 1, FREQ_OFF, (-1 & $ff)
_loopend1
    db 1, LOOPER, (_loopend1 - _loopstart1 )
    db 0

example_instrument
    db 3, WAVE, 0
    db 3, WAVE, 1
    db 3, WAVE, 2
    db 3, WAVE, 3
    db 3, WAVE, 4
    db 3, WAVE, 5
    db 0

example_instrument_2
    db 1, WAVE, 1
    db 0

    
example_instrument_3
    db 1, WAVE, 1
_loopstart3
    db 1, FREQ_OFF, 0
    db 1, FREQ_OFF, 2
    db 1, FREQ_OFF, 4
    db 1, FREQ_OFF, 6
    db 1, FREQ_OFF, 8
    db 1, FREQ_OFF, 10
    db 1, FREQ_OFF, 12
    db 1, FREQ_OFF, 14
    db 1, FREQ_OFF, 12
    db 1, FREQ_OFF, 10
    db 1, FREQ_OFF, 8
    db 1, FREQ_OFF, 6
    db 1, FREQ_OFF, 4
    db 1, FREQ_OFF, 2
_loopend3
    db 1, LOOPER, (_loopend3 - _loopstart3 )
    db 0
    
example_simplewave
    db 1, WAVE, 0
    db 0
end_instruments
;-----------------------------------------------------------
        EVEN 4
WAVESET_TABLE
    
    db  0, 1, 2, 3, 4, 0, 0, 0; d#2 ;used by song
    db -1, 5, 6,-1,-1, 0, 0, 0; e-2 ;used by song
    db 10,-1,-1,-1,-1, 0, 0, 0 ;f-2 
    db  9,-1,-1,-1,-1, 0, 0, 0 ;f#2 set all waves to default
    db  8,-1,-1,-1,-1, 0, 0, 0 ;g-2
    db  7,-1,-1,-1,-1, 0, 0, 0 ;g#2
    db  1,-1,-1,-1,-1, 0, 0, 0 ;a-2
    db  3,-1,-1,-1,-1, 0, 0, 0 ;a#2
    db 11,-1,-1,-1,-1, 0, 0, 0 ;b-2
    db -1,-1,-1,-1,-1, 0, 0, 0 ; example change NOTHING -1 = skip
    
    
        
        EVEN 4
MY_WAVE_0
        LIBBIN Waveforms/sine.dat ;d#2               ; 0
        LIBBIN Waveforms/WaveRhodes01.dat ;e-2       ; 1
        LIBBIN Waveforms/WaveRhodes02.dat ;f-2       ; 2    
        LIBBIN Waveforms/WaveFunkyGuitar04.dat ;f#2  ; 3
        LIBBIN Waveforms/WaveBrass02.dat ;g-2        ; 4
        LIBBIN Waveforms/WaveFunkyGuitar06.dat ;g#2  ; 5
        LIBBIN Waveforms/WaveFunkyGuitar05.dat ;a-2  ; 6
        LIBBIN Waveforms/saw.dat ;a#2                ; 7
        LIBBIN Waveforms/square.dat ;b-2             ; 8
        LIBBIN Waveforms/deltapeak.dat ;c-3          ; 9
        LIBBIN Waveforms/wario.dat ;c#3              ;10
        LIBBIN Waveforms/flute.dat ;d-3              ;11
beginaudiodata        
       
NOTES_LO
        LIBBIN note_timelo_0.bin
NOTES_HI
        LIBBIN note_timehi_0.bin
;------------------------------------------------
audio_data
        
        EVEN 4
COL_TABLE       dw COL_PTR0, COL_PTR1, COL_PTR2
                dw COL_PTR3, COL_PTR4, COL_PTR5
                
COL_OFF_TABLE   dw COL_OFFSETS0, COL_OFFSETS1, COL_OFFSETS2
                dw COL_OFFSETS3, COL_OFFSETS4, COL_OFFSETS5
                
        EVEN 4
PLAYLIST
        LIBBIN VBDemo01_playlist.bin
        db  $ff ;end marker
;----------------------------------------------------
        EVEN 4
COL_PTR0        
        LIBBIN col_ptr0.dat
        EVEN 4
COL_PTR1        
        LIBBIN col_ptr1.dat
        EVEN 4
COL_PTR2
        LIBBIN col_ptr2.dat
        EVEN 4
COL_PTR3        
        LIBBIN col_ptr3.dat
        EVEN 4
COL_PTR4        
        LIBBIN col_ptr4.dat
        EVEN 4
COL_PTR5        
        LIBBIN col_ptr5.dat

;----------------------------------------------------        
        EVEN 4
COL_OFFSETS0
        LIBBIN col_offsets0.dat
        EVEN 4
COL_OFFSETS1
        LIBBIN col_offsets1.dat
        EVEN 4
COL_OFFSETS2
        LIBBIN col_offsets2.dat
        EVEN 4
COL_OFFSETS3
        LIBBIN col_offsets3.dat
        EVEN 4
COL_OFFSETS4
        LIBBIN col_offsets4.dat
        EVEN 4
COL_OFFSETS5
        LIBBIN col_offsets5.dat        
;----------------------------------------------------
        EVEN 4
        
CHANNEL0
        LIBBIN channel0_stream4.dat
       ; EVEN 4
CHANNEL1
        LIBBIN channel1_stream4.dat        
       ; EVEN 4
CHANNEL2
        LIBBIN channel2_stream4.dat        
        ;EVEN 4
CHANNEL3
        LIBBIN channel3_stream4.dat
        ;EVEN 4
CHANNEL4
        LIBBIN channel4_stream4.dat        
        ;EVEN 4
CHANNEL5
        LIBBIN channel5_stream4.dat        
        
        EVEN 4

CHANNEL_START equ CHANNEL0        
                
CHANNEL_TABLE   dw CHANNEL0-CHANNEL0+CHANNEL_START, CHANNEL1-CHANNEL0+CHANNEL_START, CHANNEL2-CHANNEL0+CHANNEL_START
                dw CHANNEL3-CHANNEL0+CHANNEL_START, CHANNEL4-CHANNEL0+CHANNEL_START, CHANNEL5-CHANNEL0+CHANNEL_START
                
endaudiodata        
