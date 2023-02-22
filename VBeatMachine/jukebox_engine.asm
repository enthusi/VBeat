;======================================================
;Licensed under the 3-Clause BSD License
;Copyright 2021, Martin 'enthusi' Wendt / PriorArt
;Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
;
;2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
;
;3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
;TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
;CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;======================================================


; 02.02.2023
; - load ALL song data into RAM first and the engine reads from there
; - load song from a list from ROM to RAM
; - data contains the assembled package of 'songdata.asm'
;  begin_songdata
;        FILE songdata.asm
;end_songdata 

; FIST:
; make sure the songdata is properly aligned
; ;FLAG all occurances of songdata labels
;
        ISV810                  
        PUBALL                  
        CAPSON                  
        OFFBANKGROUP            
bank0 group 0

        FILE    vbdefines.asm

        ;some handy 8bit world macros, taken from redsquare/Kresna!
push    macro   op1
        add     -4, sp
        st.w    op1, $0[sp]
        endm

pop     macro   op1
        ld.w    $0[sp], op1
        add     4, sp
        endm

call    macro   op1
        push    r31
        jal     op1
        pop     r31
        endm

ret     macro
        jmp     [r31]
        endm

movw    macro   op1, op2
        movea   #op1'lo, r0, op2
        movhi   #op1'hi1, op2, op2
        endm

jump    macro   op1
        movw    op1, r30
        jmp     [r30]
        endm
        
 
;-------------------------------------------------------------------------------
; RAM
;-------------------------------------------------------------------------------
;definitions for offsets for PRINT_LINE ;2 per char
R_current_channel def r4 
R_chan_reg_offset def r29
R_chan_reg_base   def r19
R_ram_base        def r18

;player output of tracker data
SCREENOUTPUT    def 1

;write registers to check their state
REGCHECK        def 1

;can channels be muted?
MUTEABLE        def 1

;disable for some EMU friendly fx
;such as no negative depths for text
;REALHW          def 1

;offsets for pattern info display
dnot equ 6
dins equ dnot+2
dvol equ dnot+4
dpan equ dnot+6

o_S1INT equ $00  ;Channel 1 Sound Interval Specification Register
o_S1LRV equ $04  ;Channel 1 Level Setting Register
o_S1FQL equ $08  ;Channel 1 Frequency Setting Low Register
o_S1FQH equ $0C  ;Channel 1 Frequency Setting High Register
o_S1EV0 equ $10  ;Channel 1 Envelope Specification Register 0
o_S1EV1 equ $14  ;Channel 1 Envelope Specification Register 1
o_S1RAM equ $18  ;Channel 1 Base Address Setting Register

        org     $05000000 ;point to RAM!
        
begin_variables

PRINT_LINE equ BG_MAP+(64*2)*20
PRINT_STAT equ BG_MAP

;variables for proper i/o
keypad_state                    ds 2       
keypad_pressed                  ds 2       
keypad_previous                 ds 2       
frame_counter                   ds 2
audio_enable                    ds 1

pattern_ptr                     ds 1
tune_toggle                     ds 1
cache_state                     ds 1
cursor_position                 ds 1
text_ptr                        ds 1
text_ptr_next                   ds 1
text_ptr_last                   ds 1
text_fade_ptr                   ds 2
current_tune					ds 	  1

        EVEN 2
timer_value                     ds 2
        EVEN 4
total_time                      ds 4
timer_count                     ds 4

;these should stay unaffected during 'audio init' so we can reset waves back
new_wave                        ds 1
new_wave_src                    ds 1
    EVEN 4

audio_init_area_start
chn0
    ds 4 ;pattern start
    ds 4 ;instrument_ptr
    ds 1 ;ptr
    ds 1 ;vol
    ds 1 ;base_note
    ds 1 ;panning
    ds 1 ;flag instrument running
    ds 1 ;instrument frame
    ds 1 ;instrument frame NEXT
    ds 1 ;skip rows
;chn1-5
    ds 16*5
    
;the offsets into the chn* channel structures in RAM    
o_pattern_start equ 0
o_inst_ptr      equ 4
o_ptr           equ 8
o_vol           equ 9
o_base_note     equ 10
o_panning       equ 11
o_inst_on       equ 12
o_inst_now      equ 13
o_inst_next     equ 14
o_skip          equ 15

main_pattern_speed                ds      1
pattern_speed                     ds      1
cmd_flag                          ds      1
pan_flag                          ds      1
note                              ds      1
instrument                        ds      1
volume                            ds      1
trap                              ds      1
row                               ds      1
scroll_flag                       ds      1
break_flag                        ds      1
break_target                      ds      1
channel_on                        ds      6 ;only if you want to be able to MUTE it
audio_init_area_end

	EVEN 4
SONG_TABLE
	ds 32 ;pointers into song specific data ; 6 * 4
	
    EVEN 4
textline_table_ram
    ds 100

end_variables
;==========================================
        org     $07000000
begin_binary        
Reset:
begin_init
        ; stack pointer
        movw    $05008000, sp ;could be placed at very end of RAM as well :)

        ; Reset PSW
        ldsr r0, 5 
        
        sei
        ldsr r0, 24

        ; early mute
        movw    VSU_SSTOP, r30
        movea   $1, r0, r29
        st.h    r29, $0[r30]
        
        ; Extended WRAM warmup
        movw    $FFFF, r6
_warmup
        add     -1, r6
        bnz     _warmup

;init memory - can't hurt though technically not required
        movw VSU, r20
        movw VSU_END,r21
_loop1
        st.h r0, $0[r20]
        add     #2, r20
        cmp r20,r21
        bne _loop1

        movw WRAM, r20
        movw WRAM_END,r21
_loop2
        st.h r0, $0[r20]
        add     #2, r20
        cmp r20,r21
        bne _loop2
        
        movw VIP, r20
        movw VIP_END,r21
_loop3
        st.h r0, $0[r20]
        add     #2, r20
        cmp r20,r21
        bne _loop3
   
        movw    FRMCYC, r6
        st.h    r0, $0[r6] ;no frame delay
        
        ;nice short approach by GuyPerfect
        ; Configure the left and right column table in one go
        movhi column_table_data'hi1, r0, r10
        movea $3DC0, r0, r11  ; Start of column table
        shl   4, r11
        movea 510, r11, r12   ; End of column table
        movea 128, r0, r13    ; Remaining bytes

        ; Write all 128 bytes as halfwords to the four appropriate destinations
_column_loop
        in.b column_table_data'lo[r10], r14
        st.h r14, 0[r11]   ; Start of table, up
        st.h r14, 512[r11]
        add  1, r10        ; Breaks up the sequence of store instructions
        st.h r14, [r12]   ; End of table, down
        st.h r14, 512[r12]
        add  2, r11
        add  -2, r12
        add  -1, r13
        bnz  _column_loop

        ; Turn on the display
        mov     XP_XPEN | XP_XPRST, r29
        movw    XPCTRL, r30
        st.h    r29, [r30]
       
        movw    DP_SYNCE | DP_RE | DP_DISP, r29
        movw    DPCTRL, r30
        st.h    r29, [r30]
        
        movw palette_data, r29
        movw GPLT0, r28
        mov 8, r26
_fill_palette:
        ld.h    [r29], r25        
        st.h    r25, [r28]        
        add     2, r29              
        add     2, r28              
        add     -2, r26
        bnz     _fill_palette
        
        movw    keypad_previous, r6
        st.h    r0, [r6]
       
        movw    WCR, r6;wait state
        mov   %11, r7
        st.b    r7, [r6]
        
        ;ack pending IRQs
        movw    INTPND, r6
        movw    INTCLR, r7
        ld.h    [r6], r8
        st.h    r8, [r7]
        
        movw    INTENB, r6
        st.h    r0, [r6] ;disable all VIP IRQs
        cli

;==================================================
        ;set colors!
        movw    BRTA, r29
        movea   BRTA_DEFAULT, r0, r28
        movea   BRTB_DEFAULT, r0, r27
        movea   BRTC_DEFAULT, r0, r26
        st.h    r28, [r29]
        st.h    r27, $2[r29]
        st.h    r26, $4[r29]

        ;set up palettes including a simple fade
        movw GPLT0, r10
   
        movw (((1<<0)+(2<<2)+(3<<4))<<2),r11; %01010100,r11
        st.h r11,0[r10]
        
        movw (((0<<0)+(1<<2)+(2<<4))<<2),r11; %01010100,r11
        st.h r11,2[r10]
        
        movw (((3<<0)+(0<<2)+(1<<4))<<2),r11; %01010100,r11
        st.h r11,4[r10]
        
        movw (((2<<0)+(3<<2)+(0<<4))<<2),r11; %01010100,r11
        st.h r11,6[r10]
    
;------------------------------------------      
		call init_song
        call init_text
        ;set timer
aaa         
;init timer value
        movw timer_value, r6
        movw $c7,r7 ;for mednafen
        ;if you use a 20us timer
        ;at the time of this code, mednafen was too buggy to use it
        ;movw $3e8,r7 ;in theory for real hardware,
        ;it's more like 3e5 given my column table
        st.h r7,[r6]

        movw TIMER_TLR, r30
        movw timer_value, r29
        in.b [r29],r29
        st.b r29, [r30]
        
        movw TIMER_THR, r30
        movw (timer_value+1), r29
        in.b [r29],r29
        st.b   r29, [r30]

        ;bit4 of TCR
        ;0	100 µs
        ;1	20 µs

        movw TIMER_TCR, r30
        movea %00001101, r0, r29 ;20 us
        st.b   r29, [r30]
;------------------------------------------
;set up PCM waves
        ; Disable all sound to avoid cracks
        ; and to allow writing to WAVE register
        sei
        movw    VSU_SSTOP, r30
        movea   $1, r0, r29
        st.h    r29, [r30]
        
        movw VSU_WAVE_0, r10
        ;movw MY_WAVE_0,  r6
        movw SONG_TABLE, r6 ;2023 ptr to offsets
		ld.w  SONG_MY_WAVE_0[r6], r6
    
        movw (32*5), r7 
_loop
        in.b  [r6], r8 
        st.b  r8,[r10]
        add 1, r6
        add 4, r10
        add -1, r7
        bne _loop
      
;==================================================  
;my init stuff
        call setup_bitmap
      
        ;clear BG map
        movw BG_MAP, r29
        
        addi  ((64*2)*32),r29,r28 ;how many words to be filled
        movea 256,r0,r27
_filler
        st.h    r27, [r29]
        add     #2, r29
        cmp     r29, r28
        bnz     _filler
        
;------------------
draw_test_line 
    ;shows the routine's usage per frame in this bar
    movw $2101,r10
    movw (BG_MAP+128*22),r11
    movw 48,r12
_loopk
    st.h r10,[r11]
    add 2,r11
    add -1, r12
    bp _loopk

;------------------

        ;init which playlist position to start at!
        movw pattern_ptr, r8
        mov 0,r7
        st.b r7, [r8]
        
        movw chn0, r4
        mov r0,r29

		
        call init_player
        
        ifdef SCREENOUTPUT   
        ;write channel IDs in top
        movw BG_MAP, r9
        mov 1,r5
        st.h r5, 8[r9]
        add 1, r5
        st.h r5, 24[r9]
        add 1, r5
        st.h r5, 40[r9]
        add 1, r5
        st.h r5, 56[r9]
        add 1, r5
        st.h r5, 72[r9]
        add 1, r5
        st.h r5, 88[r9]
        endif
        
        mov 1,r6
        movw audio_enable, r5
        st.b r6, [r5]
        
        movw    VSU_SSTOP, r6 ;probably not required
        st.h    r0, [r6]
        
        cli ;dont start music before things are set
        
        movw    INTPND, r6
        movw    INTCLR, r7
        ld.h    [r6], r8
        st.h    r8, [r7]
        
        movw $05000000, R_ram_base ;variables BASE   
        
         ;init which tune to start with
        st.b r0, tune_toggle'lo[R_ram_base]
        mov 1,r7
        st.b r7, cache_state'lo[R_ram_base] ;just in case you want to change this as user input
   
        movw timer_count,r6
        mov 10, r7
        st.w r7,0[r6] ;reset timer count
        movw total_time,r6
        st.w r0,0[r6]
          
        st.b r0, new_wave'lo[R_ram_base]
        st.b r0, scroll_flag'lo[R_ram_base]
        st.b r0, cmd_flag'lo[R_ram_base]
        st.b r0, pan_flag'lo[R_ram_base]
        st.b r0, break_flag'lo[R_ram_base]
        st.b r0, break_target'lo[R_ram_base]
        
        st.b r0,text_ptr'lo[R_ram_base]
        st.h r0,text_fade_ptr'lo[R_ram_base]
    
        st.b r0,text_ptr_next'lo[R_ram_base]
    
        mov     2, r22 ;enable cache as default
        ldsr    r22, 24;CHCW
        
end_init     
;-----------------------------------------------  
        
mainloop:
_mainloop
;===============================================
;should use HALT instruction here but heard of emulation inconsistencies currenlty

_sync_loop:
    movw XPSTTS, r20
    ld.h $0[r20],r20
    andi %1100, r20, r20
    bne _sync_loop ;wait till drawing stopped!
    
    ;animate bg
        movw (WORLD_TBL + 31*32),r9 ;parallax for world 31
        movw frame_counter, r7
        ld.h [r7], r7 ;frame counter to r7
        shr 1,r7
        andi 15,r7,r7 ;limit range
        
        mov 15,r6
        sub r7,r6
        mov r6,r7
        
        addi -16,r7,r7 ;static offset
        st.h r7,6[r9]
        shr 1,r7        ;dont scroll  at 45 deg
        st.h r7,2[r9]
;-----------------------------
        ;do we need to scroll?
        in.b scroll_flag'lo[R_ram_base], r6
        cmp r0,r6
        be _no_scroll
        call scroll_up
        st.b r0,scroll_flag'lo[R_ram_base]
_no_scroll
;--------------------------------------
        call write_text
;------------------------------------------------
        call read_keypad_hw
        call act_on_keys
        
        in.b cursor_position'lo[R_ram_base], r6
        shl 4,r6
        movw BG_MAP, r7

        movw 256,r8 ;erase pointer first
        st.h r8, (10+16*0)[r7]
        st.h r8, (10+16*1)[r7]
        st.h r8, (10+16*2)[r7]
        st.h r8, (10+16*3)[r7]
        st.h r8, (10+16*4)[r7]
        st.h r8, (10+16*5)[r7]

        add r6,r7
        movw 261,r6
        ;ori $1000,r6,r6 ;flip
        st.h r6, 10[r7]

        jump _mainloop
;===============================================
begin_timerirq
Timer_Interrupt:
        sei
; of course this could be solved WAY more efficient without macros
; and with a single stackpointer addition and a series of offset writes
; it is simply more flexible for others to use like this

        push     r4
        push     r5
        push    r6
        push    r7
        push    r8
        push    r9
        push    r10
        push    r11
        push    r12
        push    r13
        push    r14
        push    r15
        push    r16
        ;push    r17
        push    r18
        push    r19
        push    r20
        push    r21
        ;push    r22
        ;push    r23
        ;push    r24
        ;push    r25
        ;push    r26
        push    r27
        push    r28
        push    r29
        push    r30
        push    r31
;this may come in handy for later users
;setup all registers with a certain pattern
;to see which ones are being used in the end

        ifdef REGCHECK
        movw $aa55aa55,r5
acheck_regs    
        
        mov r5,r4
        mov r5,r5
        mov r5,r6
        mov r5,r7
        mov r5,r8
        mov r5,r9
        mov r5,r10
        mov r5,r11
        mov r5,r12
        mov r5,r13
        mov r5,r14
        mov r5,r15
        mov r5,r16
        ;mov r5,r17
        mov r5,r18
        mov r5,r19
        mov r5,r20
        mov r5,r21
        ;mov r5,r22
        ;mov r5,r23
        ;mov r5,r24
        ;mov r5,r25
        ;mov r5,r26
        mov r5,r27
        mov r5,r28
        mov r5,r29
        mov r5,r30
        mov r5,r31
        
        ;possibyl unused:
        ;free r17, r24, r25
        ;free r22, r23  (scrollup)
        ;r23,r24,r25,r26
        endif
        
        movw audio_enable, r5
        in.b [r5],r5
        cmp r5,r0
        bne _play_audio
        jump skip_audio
_play_audio        
        movw TIMER_TCR, r6
        movea %00001100, r0, r7 ;disable + ack
        st.b   r7, [r6]
        
        movea %00001101, r0, r7 ;re-enable
        st.b   r7, [r6]
        
beforecall   

        movw    BRTA, r29
        movea   BRTB_DEFAULT, r0, r27
        st.h    r0, 2[r29]
        
        ;this should in fact be global to the whole player!
        ;global registers is what I would do for a rewrite from scratch ;)
        movw $05000000, R_ram_base ;variables BASE
        in.b cache_state'lo[R_ram_base], r6
        mov  r0, r16
        cmp r6,r0
        be _disable_cache
    
        mov 2,r16    ;just enable
_disable_cache
        ldsr    r16, 24;CHCW
        call audio_playframe
        
        ldsr    r0, 24;CHCW
        
        movw    BRTA, r29
        movea   BRTB_DEFAULT, r0, r27
        st.h    r27, 2[r29]
        
;=======================================
skip_audio      
aftercall
    ;OLD behavior:
    ;ACK timer IRQ _AFTER_ audio_playframe
    ;to ensure the counter is no longer at 0
    ;in which case it would not ACK.
    ;alternatively: disable timer (+ack), then re-enable which we do now

        movw TIMER_TLR, r6
        in.b    [r6], r6
        movw TIMER_THR, r7
        in.b    [r7], r7
        cmp r6,r0
        bz _was_still_zero
        
        shl 8,r7
        add r7,r6 ;16bit timer in r6
        
        ;compute required time
        movw timer_value,r7
        in.h [r7],r7
        sub r6,r7   
        
_was_still_zero        
            
        ;add time to total
        movw total_time,r6
        ld.w [r6],r8
        add r7,r8
        st.w r8, [r6]
        
        ;add time to total
        movw timer_count,r6
        in.b [r6],r7
        add -1,r7
        st.b r7,[r6]
        bp _keep_adding
        
        ;optional, currently not used
        movw 0, r7   ;AVERAGE OVER THIS MANY FRAMES
        st.w r7,[r6] ;reset timer count
        
        ;divide for number
        ;shr 0,r8 ;AVERAGE OVER THIS MANY FRAMES
        ;mov r8,r7
        
        ;andi $ff, r7,r6 ;low
        ;st.h r6, 2[r9]
        
        ;reset counter
        movw total_time,r6
        st.w r0,[r6]
        
        mov r8,r6
        
        ;also show a funny bar
        ;clear first
        movw 90, r7
        movw $0100, r9
        movw (PRINT_STAT+128*27),r8
_clear_loop        
        st.h r9,[r8]
        add 2, r8
        add -1, r7
        bne _clear_loop
        
        ;r6 is bar length = time
        ;cmp r0,r6
        ;bz _no_bar ;dont draw anything if value is still 0
        mov 0,r9
        movw $00ff, r7
        movw (PRINT_STAT+128*27),r8
_bar_loop        
        st.h r9,[r8]
        add 2, r8
        add 1, r9
        add -1, r6
        bp _bar_loop
_no_bar        
_keep_adding   

    ifdef SCREENOUTPUT   
        movw row, r6
        in.b [r6], r7 ;row counter to r7
        movw PRINT_LINE, r8
        st.h r7, [r8]
    endif        

        movw frame_counter, r6
        ld.h [r6], r7 ;frame counter to r7
        add     1, r7
        st.h r7, [r6]

        ;place logo
CHAR_PA def 256 + 97 

        shr 3,r7
        andi 7,r7,r7 ;r7 is frame counter
        movw logo_palette, r8
        add r7,r8
        in.b [r8],r8
        shl 14,r8

        movea CHAR_PA,r0,r5
        movw BG_MAP, r9
        or r8,r5
        
        st.h r5, 92[r9]
        add 1,r5
        st.h r5, 94[r9]
        addi 98,r5,r5
        st.h r5, (92+128)[r9]
        add 1,r5
        st.h r5, (94+128)[r9]

bcheck_regs    
        pop     r31
        pop     r30
        pop     r29
        pop     r28
        pop     r27
        ;pop     r26
        ;pop     r25
        ;pop     r24
        ;pop     r23
        ;pop     r22
        pop     r21
        pop     r20
        pop     r19
        pop     r18
        ;pop     r17
        pop     r16
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     r11
        pop     r10
        pop     r9
        pop     r8
        pop     r7
        pop     r6
        pop     r5
        pop     r4
        pop     r30
        
        reti
end_timerirq

logo_palette 
    db 3,2,1,0,0,0,1,2
;---------------------------------------------------

;===========================================================
init_player:
        movw $05000000, R_ram_base ;variables
;clear a couple of variables
;place those in registers?!
        movea (audio_init_area_end - audio_init_area_start), r0, r6
        movw audio_init_area_start, r5
_loop
        st.b r0, [r5]
        add     #1, r5
        add -1, r6
        bne _loop
;---
        ;preset pattern speed
        ;overwritten by s3m tempo command if present
        movw main_pattern_speed, r5
        mov 6, r6
        st.b r6, [r5]
        movw pattern_speed, r7
        st.b r6, [r7]
        
        call audio_set_pattern
        
         ;preset panning
        movw chn0,r6
        mov 3,r7
        st.b r7, (16*0+o_panning)[r6]
        st.b r7, (16*1+o_panning)[r6]
        st.b r7, (16*2+o_panning)[r6]
        st.b r7, (16*3+o_panning)[r6]
        st.b r7, (16*4+o_panning)[r6]
        st.b r7, (16*5+o_panning)[r6]
        
        
        mov 1,r7
        st.b r7 (channel_on'lo + 0)[R_ram_base]
        st.b r7 (channel_on'lo + 1)[R_ram_base]
        st.b r7 (channel_on'lo + 2)[R_ram_base]
        st.b r7 (channel_on'lo + 3)[R_ram_base]
        st.b r7 (channel_on'lo + 4)[R_ram_base]
        st.b r7 (channel_on'lo + 5)[R_ram_base]
     
        ret
        
;===========================================================
set_new_waves
 ;we set a new wave
    ;which set do we use?
    in.b new_wave_src'lo[R_ram_base], r5
    shl 3,r5; *8 size of set
    
    ;mw23
    ;movw WAVESET_TABLE, r14
    
    movw SONG_TABLE, r14 ;2023 ptr to offsets
    ld.w  SONG_WAVESET_TABLE[r14], r14
    
    add r5,r14

    movw VSU_WAVE_0, r5
    
    ;movw MY_WAVE_0, r29
    movw SONG_TABLE, r29 ;2023 ptr to offsets
    ld.w  SONG_MY_WAVE_0[r29], r29
    
     ;stop all sounds to be able to write to wave tables
    movw    VSU_SSTOP, r8
    movea   $1, r0, r9
    st.h    r9, [r8]
    
    movw 5, r9 ;loops
 
_loop    
    ;read in source for every wave
    ld.b [r14],r6
    add 1,r6
    bnz _we_exchange_this_wave
    jump _skip_this_wave
    
_we_exchange_this_wave    
    add -1, r6
    ; set source pointer
    shl 5,r6 ;size of wave
    add r29,r6 ;absolute pointer
    ;as fast as we think we can here!

    in.b  $00[r6], r8  ;src
    st.b  r8,$00[r5]  ;dst
    in.b  $01[r6], r8  ;src
    st.b  r8,$04[r5]  ;dst
    in.b  $02[r6], r8  ;src
    st.b  r8,$08[r5]  ;dst
    in.b  $03[r6], r8  ;src
    st.b  r8,$0c[r5]  ;dst
    in.b  $04[r6], r8  ;src
    st.b  r8,$10[r5]  ;dst
    in.b  $05[r6], r8  ;src
    st.b  r8,$14[r5]  ;dst
    in.b  $06[r6], r8  ;src
    st.b  r8,$18[r5]  ;dst
    in.b  $07[r6], r8  ;src
    st.b  r8,$1c[r5]  ;dst
    in.b  $08[r6], r8  ;src
    st.b  r8,$20[r5]  ;dst
    in.b  $09[r6], r8  ;src
    st.b  r8,$24[r5]  ;dst
    in.b  $0a[r6], r8  ;src
    st.b  r8,$28[r5]  ;dst
    in.b  $0b[r6], r8  ;src
    st.b  r8,$2c[r5]  ;dst
    in.b  $0c[r6], r8  ;src
    st.b  r8,$30[r5]  ;dst
    in.b  $0d[r6], r8  ;src
    st.b  r8,$34[r5]  ;dst
    in.b  $0e[r6], r8  ;src
    st.b  r8,$38[r5]  ;dst
    in.b  $0f[r6], r8  ;src
    st.b  r8,$3c[r5]  ;dst
    in.b  $10[r6], r8  ;src
    st.b  r8,$40[r5]  ;dst
    in.b  $11[r6], r8  ;src
    st.b  r8,$44[r5]  ;dst
    in.b  $12[r6], r8  ;src
    st.b  r8,$48[r5]  ;dst
    in.b  $13[r6], r8  ;src
    st.b  r8,$4c[r5]  ;dst
    in.b  $14[r6], r8  ;src
    st.b  r8,$50[r5]  ;dst
    in.b  $15[r6], r8  ;src
    st.b  r8,$54[r5]  ;dst
    in.b  $16[r6], r8  ;src
    st.b  r8,$58[r5]  ;dst
    in.b  $17[r6], r8  ;src
    st.b  r8,$5c[r5]  ;dst
    in.b  $18[r6], r8  ;src
    st.b  r8,$60[r5]  ;dst
    in.b  $19[r6], r8  ;src
    st.b  r8,$64[r5]  ;dst
    in.b  $1a[r6], r8  ;src
    st.b  r8,$68[r5]  ;dst
    in.b  $1b[r6], r8  ;src
    st.b  r8,$6c[r5]  ;dst
    in.b  $1c[r6], r8  ;src
    st.b  r8,$70[r5]  ;dst
    in.b  $1d[r6], r8  ;src
    st.b  r8,$74[r5]  ;dst
    in.b  $1e[r6], r8  ;src
    st.b  r8,$78[r5]  ;dst
    in.b  $1f[r6], r8  ;src
    st.b  r8,$7c[r5]  ;dst
_skip_this_wave    

    addi $80, r5, r5 ;next wave ram
    add 1, r14 ;next entry in set
    add -1, r9
    bz _we_are_done
    jump _loop
_we_are_done    
    ;new wave implemented, clear flag
    st.b r0,new_wave'lo[R_ram_base] 
    ret
;---------------------------------------------    
    
begin_player1
audio_playframe 
    
    movw pattern_speed, r5
    in.b [r5], r6
    add -1, r6
    st.b r6, [r5]
    bne _cont
  
    mov 1,r6
    st.b r6,scroll_flag'lo[R_ram_base]
    
    ;reset pattern speed
    movw main_pattern_speed, r6
    in.b [r6], r6
    st.b r6, [r5]
        
    ;---------------------------
;2021 exhange wave table on request BEFORE play
    in.b new_wave'lo[R_ram_base], r5
    cmp r0,r5
    bz _no_new_wave
    
    call set_new_waves
_no_new_wave    
;---------------------------

    call audio_read_pattern_data
  
_cont
    movw chn0, R_current_channel ;init to chn0
    mov r0,r29 ;init register pointer to 0-offset from HW channel 0
    ;r18 is RAM 0 pointer
    movw VSU_S1INT, R_chan_reg_base ;HW reg BASE

_instrument_play_loop
    mov r29, r14
    shr 4,r14
    ;play all instrument channels now
    call play_instrument
    
    addi 16,R_current_channel,R_current_channel
    addi 64, r29,r29
    addi 64, R_chan_reg_base,R_chan_reg_base
    movw 64*6,r7
    cmp r7,r29
    bne _instrument_play_loop
    
_all_done      
      
    ;reset channel to 0
    movw chn0, R_current_channel ;init to chn0
    mov r0,r29 ;init register pointer to 0-offset from HW channel 0
    mov r0,r14
    movw VSU_S1INT, R_chan_reg_base ;HW reg BASE
    
    ret
;--------------------------------------------------------------
audio_read_pattern_data:
    movw chn0, R_current_channel ;init to chn0
    mov r0,r29 ;init register pointer to 0-offset from HW channel 0
    movw VSU_S1INT, R_chan_reg_base ;HW reg BASE
    
col_loop
    mov r29, r14
    shr 4,r14
    in.b o_skip[R_current_channel],r6 ;skip_rows0
    
    cmp r6,r0
    bz _we_dont_skip_a_row
    
    add -1, r6
    st.b r6, o_skip[R_current_channel] ;skip_rows0
    
    jump this_col_complete
    
_we_dont_skip_a_row 

    call read_byte ;-> to r10!
    cmp r10,r0 ;the byte from the stream
    bne col_not_done ;it was not a plain 0 byte (do these even exist now?)
    
    jump this_col_complete ;this does happen, probably alot for fully empty column rows
    
col_not_done   ;we have something to play or do 
    andi    %00000001, r10, r5 ;check for bit01 set 
    bz no_skip_of_next_row
    
full_run_of_zeroes   ;we had a byte that encodes a string of 0s
    mov r10, r5 ;r10 is full value, r5 is and 3
    shr 1, r5
    st.b r5,o_skip[R_current_channel]
    jump this_col_complete ;same as jump here
    
no_skip_of_next_row
;note value in stream
;bit0 indicates that rows to skip follow!

    mov r10, r5 ;r10 is full value, r5 is and 3
    shr 1, r5
;so shifting down gives the note
;$2e=46 -> 23
    ;new now check if this is really a note
    ;if it is '1' now (2 before shr)
    ;then it is NOT!
    mov 1,r6
    cmp r5,r6
    bne _this_is_a_real_note

    ;new it was a dummy note!
    ;lets read command bytes and
    ;NOT touch instrument or note
    call read_byte;-> to r10!
    mov 1,r6
    st.b r6, cmd_flag'lo[R_ram_base]
    jump _continue_with_cmd_only
    
_this_is_a_real_note
    
    st.b r0, cmd_flag'lo[R_ram_base]
    ;new r5 is datanote now
    ;add -2, r5 ;20213 moved here from start instrument!
    ;20213 side effects, instead corrected in
    ;NOTEOFF and FREQOFF
    st.b r5, note'lo[R_ram_base] 
    
    st.b r5,o_base_note[R_current_channel]
    
    ifdef SCREENOUTPUT   
    movw PRINT_LINE, r8
    add r14,r8
    add r14,r8
    add r14,r8
    add r14,r8
    add -3,r5
    st.h r5, dnot[r8] ;NOTE
    add +3,r5
    endif
    
;init max volume based on panning!
    mov 15,r8;
    st.b r8,o_vol[R_current_channel]
    
    
    ;what follows the note
    call read_byte;-> to r10!
    andi    %00011111, r10, r5 ;limit to 32 instruments
    
_proper_instrument    
    st.b r5, instrument'lo[R_ram_base];
    
    
;================================
;2021
;was it instrument 31 ?
;then it was a command to exchange a wave
    movw 31,r8
    cmp r5, r8 ;reg2- reg1
    bne _no_wave_exchange;bp if reg2 >= reg1 -> r5 <= 26
      
    in.b note'lo[R_ram_base], r5
    add -3, r5 ;TODO, BUG, NOTE, FIXME 2021 - hardcoded such that D#2 is 0
    st.b r5, new_wave_src'lo[R_ram_base] ;note = # of new wave
    
    ifdef SCREENOUTPUT   
    movw PRINT_LINE, r8
    add r14,r8
    add r14,r8
    add r14,r8
    add r14,r8

    ;add marker
    movw 261,r6
    st.h r6, dins[r8]
    endif

    
    mov 1,r5
    st.b r5, new_wave'lo[R_ram_base] ;set flag to exchange wave next time
    ;nothing else needs to happen after this
    
    ;202104 to later skip play
    mov 1,r6
    st.b r6, cmd_flag'lo[R_ram_base]
   ; jump dont_play
   br  _continue_with_cmd_only

_no_wave_exchange
;================================
;debug    
    ifdef SCREENOUTPUT   
    movw PRINT_LINE, r8
    add r14,r8
    add r14, r8
    add r14,r8
    add r14,r8
    ori (2<<14),r5,r5
    st.h r5, dins[r8]
    endif

_continue_with_cmd_only    
;check if we have a command here!    
    ;before we check for volume we should check for panning!
    mov r10, r13 ;;BACKUP this r10 value for later
    andi    %00100000, r10, r5 ;0x20 indicates panning
    bz _no_panning
    
_read_panning
  ;writing to panning0
  ;NOT updating 'volume'
  
    ;init to NO panning
    ;MW st.b r0, pan_flag'lo[R_ram_base]
  
    call read_byte;-> to r10! ;kills 10,11,20
    st.b r10, o_panning[R_current_channel]
    
    ifdef SCREENOUTPUT   
    movw PRINT_LINE, r8
    add r14, r8
    add r14, r8
    add r14, r8
    add r14, r8
    ori (2<<14),r10,r10
    st.h r10, dpan[r8]
    endif
    
    ;MW mov 1,r10 ;set panning flag
    ;because we must set volume when panning was changed!
    ;MW st.b r10, pan_flag'lo[R_ram_base]
    
    mov r13,r10 ;we need to restore to the dataflag r10!
    
_no_panning    
    ;BACKUP this r10 value for later
    mov r10, r13 ;
    andi    %10000000, r10, r5 ;0x80 indicates a VOLUME
    bz _no_new_channel_volume ;bit7 = also read volume, bit6 is for reading command/tempo, could still happen!
    
    call read_byte;-> to r10! ;kills 10,11,20
    
    ;update channel volume
    ifdef SCREENOUTPUT   
    movw PRINT_LINE, r8
    add r14,r8
    add r14, r8
    add r14,r8
    add r14,r8
    andi $3f,r10,r10
    ori (1<<14),r10,r10 ;CAREFUL affects volume but never in 8 bit range
    st.h r10, dvol[r8]
    endif
    
    shr 2, r10
    st.b r10,o_vol[R_current_channel]
    ;table
;vol + pan -> write volume, read volume, apply panning, write VOL
; -  + pan ->               read volume, apply panning, write VOL
;vol + -   -> write volume, read volume, apply panning, write VOL
    ;r10 is volume 63
    ;r6 is variable:volume
    br _we_had_a_new_volume
_no_new_channel_volume    

    ;when we changed panning, reset volume here
    ;MW in.b pan_flag'lo[R_ram_base], r5
    ;MW cmp r5,r0
    ;MW bnz _we_had_a_new_volume
    
    ;dont touch channel volume1
    ;when nothin was played!
    in.b cmd_flag'lo[R_ram_base],r5
    cmp r5,r0
    bnz column_done

_we_had_a_new_volume
    in.b o_vol[R_current_channel],r10
    
    ;this routine applies panning
    
    ld.b o_panning[R_current_channel],r20 ;r20 is panning value
    shl 3, r10 ;volume*8
    add r20,r10 ;r20 = vol*8+panning
    movw PANTABLE, r20
    add r10,r20
    ld.b 0[r20],r10
    ;movw volume, r6
    st.b r10,volume'lo[R_ram_base];$0[r6]     ;into 'volume'
    
;new remove?    
;always APPLY panning or volume in channel:
    in.b volume'lo[R_ram_base], r8
    st.b r8, o_S1LRV[R_chan_reg_base]
    
    ;the name 'column done' is very misleading
    ;we may just have checked for volume via 0x80 flag
    ;and now we check for other commands!
column_done ;but maybe we have a new tempo?
    mov r13, r10 ;restore original r10 from r13
    andi    %01000000, r10, r5
    bz channel_complete
    
;we have a command coming in!
    call read_byte;-> to r10!

    andi    %10000000, r10, r5 ;ANDI supposedly sets Z-flag!
    bne  set_tempo ;bit7 = set tempo
    
    andi    %01000000, r10, r5 ;ANDI supposedly sets Z-flag!
    bz set_nothing
    
set_new_order
;===========================
    mov 1,r6
    st.b r6, break_flag'lo[R_ram_base]
    
    andi    $3f, r10, r5 ;ANDI supposedly sets Z-flag!
    st.b r5, break_target'lo[R_ram_base]
    
    br set_nothing
;===========================    
    
set_tempo
   
    andi    %00111111, r10, r5 ;ANDI supposedly sets Z-flag!
    ;shl 2,r5 ;2021 enable SUPER SLOW for testing
    
    st.b r5, main_pattern_speed'lo[R_ram_base];$0[r6]
  
    ifdef SCREENOUTPUT   
    movw PRINT_STAT, r9
    xori (1<<14),r5, r5
    st.h r5, 4[r9]
    endif
    
set_nothing  
no_tempo
    
channel_complete    
    ;here we need to play the channel
    ;unless it was an empty note!
    
;dont play if it was a silent instrument (dummy)    
    in.b o_base_note[R_current_channel],r6
    add -2, r6
    cmp r6,r0
    bz dont_play
    
    in.b cmd_flag'lo[R_ram_base],r5
    cmp r5,r0
    bnz dont_play
    
    call start_instrument

;---------------------
dont_play    
   
this_col_complete    

we_continue_with_next_col  
    
    addi 16,R_current_channel,R_current_channel
    addi 64, r29,r29
    addi 64, R_chan_reg_base,R_chan_reg_base ;next hardware register
    movw 64*6,r7
    cmp r7,r29
    be row_done
    jump col_loop
    
row_done
;===========================================================================
    ;do we continue normally or do we have a break?
     
    in.b break_flag'lo[R_ram_base],r10
    cmp r10,r0
    bz normal_row_done

    ;we have a break    
    in.b break_target'lo[R_ram_base], r5
    
    movea $3f, r0, r6
    cmp r5,r6
    bne no_c_command
    
    call increase_patternptr
    jump cont
    
no_c_command    
    st.b r5,pattern_ptr'lo[R_ram_base]
    
cont    
    ;also end row? what else? do this here or before we increase
    ;the row pointer
    call audio_set_pattern

    
        st.b r0, row'lo[R_ram_base]
        ;rset row and channel ptr
        
        movw chn0,r5
        st.b r0, (o_skip+16*0)[r5]
        st.b r0, (o_skip+16*1)[r5]
        st.b r0, (o_skip+16*2)[r5]
        st.b r0, (o_skip+16*3)[r5]
        st.b r0, (o_skip+16*4)[r5]
        st.b r0, (o_skip+16*5)[r5]
        
        st.b r0, (o_ptr+16*0)[r5]
        st.b r0, (o_ptr+16*1)[r5]
        st.b r0, (o_ptr+16*2)[r5]
        st.b r0, (o_ptr+16*3)[r5]
        st.b r0, (o_ptr+16*4)[r5]
        st.b r0, (o_ptr+16*5)[r5]

        st.b r0, (o_vol+16*5)[r5]
        
        st.b r0, break_flag'lo[R_ram_base]
        
        ret

;==========================================================================
normal_row_done
    ;reset channel to 0
    movw chn0, R_current_channel ;init to chn0
    mov r0,r29 ;init register pointer to 0-offset from HW channel 0
    mov r0,r14
    movw VSU_S1INT, R_chan_reg_base
    
    ;jsr increase_ptr
    ;movw row, r6
    in.b row'lo[R_ram_base],r7
    add 1, r7
    st.b r7,row'lo[R_ram_base]

    ;end of pattern reached?
    movw 64,r8;
    cmp r7,r8
    bne endkk
    
    ;clear all channel pointer
    st.b r0, row'lo[R_ram_base]
        
    movw chn0,r5
        
    st.b r0, (o_ptr+16*0)[r5]
    st.b r0, (o_ptr+16*1)[r5]
    st.b r0, (o_ptr+16*2)[r5]
    st.b r0, (o_ptr+16*3)[r5]
    st.b r0, (o_ptr+16*4)[r5]
    st.b r0, (o_ptr+16*5)[r5]
    
    call increase_patternptr
    call audio_set_pattern
  
endkk
    ret

;--------------------------------------------------------------
increase_patternptr:
    in.b pattern_ptr'lo[R_ram_base],r12
    add 1, r12
    st.b r12, pattern_ptr'lo[R_ram_base]
    ret

;--------------------------------------------------------------

read_byte ;todo: for all channels of course
    ld.w o_pattern_start[R_current_channel],r20
    in.b o_ptr[R_current_channel], r21 ;DANGER if a pattern is longer than 256!
    ;but I have yet to see such a pattern ;-)
    add r21,r20
    in.b [r20],r10
;--------------------------------------------------------------
increase_ptr:
    in.b o_ptr[R_current_channel],r12
    add 1, r12
    st.b r12, o_ptr[R_current_channel]
    ret
;--------------------------------------------
audio_set_pattern:
    ifdef SCREENOUTPUT   
    in.b pattern_ptr'lo[R_ram_base], r7 
    movw PRINT_STAT, r8
    st.h r7, 0[r8]
    endif

    ;reset channel to 0
    movw chn0, R_current_channel ;init to chn0
    movw 0,r29 ;init register pointer to 0-offset from HW channel 0

_set_pattern_loop        
    mov r29, r14
    shr 4,r14
    
    ;movw pattern_ptr, r6 ;8bit
    in.b    pattern_ptr'lo[R_ram_base], r6      
     ;mw 23
    ;movw PLAYLIST, r5 ;32bit
    movw SONG_TABLE, r5 ;2023 ptr to offsets
    ld.w  SONG_PLAYLIST[r5], r5
    
    add r6, r5 
    in.b    [r5], r5 ;** playlist entry 8bit
    ;and out individual bits in helper register
    andi    %10000000, r5, r7 ;check for bit7 set 
    bne _end_of_list
    
    ifdef SCREENOUTPUT   
    mov r5,r7
    movw PRINT_STAT, r8
    xori (2<<14),r7, r7
    st.h r7, 2[r8]
    endif
    
    ;which 3 columns do we need?
    ;channel 0 first
    ;mw23
    movw SONG_TABLE, r8 ;2023 ptr to offsets
    ld.w  SONG_COL_TABLE[r8], r8
    
   ; movw COL_TABLE,r8 ;COL_PTR0, r8 ;32bit adresse
    add r14, r8
    ld.w  [r8], r8 ;the actual adress of the colptr!
    
    add r5, r8 ;r5 is ptr from playlist
    in.b  [r8], r8 ;8bit ptr into a list of columns
    ;mw23
    
    movw SONG_TABLE, r9 ;2023 ptr to offsets
    ld.w  SONG_COL_TABLE[r9], r9
    ;movw COL_TABLE, r9
    ;2023!!
    addi (6*4), r9, r9 ;COL_OFF_TABLE has this fixed offset to COL_TABLE
    
    ;add channel*4 as offset
    add r14, r9
     
    ld.w  [r9], r9 ;the actual adress COL_OFFSETS0,1,2
    
    shl 1,r8 ;offset tables are 16bit so to *2 to point into them properly
    add r8, r9
    ld.h    [r9], r5 ;16bit offset into col data
    
    ;movw CHANNEL_TABLE, r9
    movw SONG_TABLE, r9 ;2023 ptr to offsets
    ld.w  SONG_CHANNEL_TABLE[r9], r9
    
    ;add channel*4 as offset
    add r14, r9
    
    ld.w  [r9], r8 ;the actual adress CHANNEL0,1,2
    add r5, r8      ;start_of_pattern data
    
    st.w r8, o_pattern_start[R_current_channel]
    
    ;now we have written the starting position of the channel data
    ;in memory
    
    st.b r0,o_skip[R_current_channel]
    
    ;adjust GP for next channel
    addi 16,R_current_channel,R_current_channel
    addi 64, r29,r29
    movw 64*6,r5
    
    cmp r5,r29
    be _channels_complete
    jump _set_pattern_loop

_channels_complete
 ;reset channel to 0
    movw chn0, R_current_channel ;init to chn0
    movw 0,r29 ;init register pointer to 0-offset from HW channel 0
    ret
   
_end_of_list
   
    ;where to continue once end of playlist is reached.
    ;normally from start (=0) but here we loop into tech demo
    ;which starts at playlist #82
    ;tech demo loops back to 82
    ;the main tune loops internally to entry #00 via 'B00' command
    movw 82,r5
    st.b r5,pattern_ptr'lo[R_ram_base]
    ;st.b r0,pattern_ptr'lo[R_ram_base]
       
    jump audio_set_pattern
    

;===========================================================
scroll_up:
    movw (BG_MAP+64*6),r20
    movw (BG_MAP+64*4),r21
    
        movea 32*19, r0, r22 ; copy blank line into active line to clear it
_loop
        ld.w  [r20], r23
        st.w  r23,[r21]
        add 4,r20
        add 4,r21
        add -1, r22
        bne _loop
        ret
;---------------------------------------------
start_instrument:
   
    in.b o_base_note[R_current_channel], r6

    add -3, r6 ;20213 fix for v-14
    
    movw NOTES_LO, r10
    add r6, r10 ;add current note to note_table
    in.b [r10], r11 ;
    
    st.b   r11, o_S1FQL[R_chan_reg_base]

    movw NOTES_HI, r10
    add r6, r10 ;add current note to note_table
    in.b [r10], r11 ;
    
    st.b   r11, o_S1FQH[R_chan_reg_base];[r8]

    in.b volume'lo[R_ram_base], r8
    st.b r8, o_S1LRV[R_chan_reg_base];[r30]
    
    ;2021 cant kill noise!
    
    mov 9,r9  ;KILL SOUND by illegal wave
    st.b   r9, o_S1RAM[R_chan_reg_base];[r30]        
    
    movea %11111111, r0, r28
    st.b   r28, o_S1EV0[R_chan_reg_base];[r30]        
   
    movea %00000000, r0, r28
    st.b   r28, o_S1EV1[R_chan_reg_base];[r30]        
;------------        
    ifdef MUTEABLE

    mov r29, r9 ;
    shr 6,r9 ;0...5
    movw channel_on, r28
    add r28,r9
    in.b [r9],r9
    movea %00011111, r0, r28

    cmp r0,r9
    be _dont_init_on_this_channel
    endif
    ;dont play muted channels
;------------
    
    movea %10011111, r0, r28
_dont_init_on_this_channel
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]        

    st.b r0, o_inst_now[R_current_channel]
        
    mov 1, r9
    st.b r9, o_inst_on[R_current_channel]
    
    st.b r9, o_inst_next[R_current_channel]

    in.b instrument'lo[R_ram_base], r5
    shl 2,r5 ;offsets are 4* instrument
    
    ;mw23
    ;movw INSTRUMENT_TABLE, r8 ;script adresses
    movw SONG_TABLE, r8 ;2023 ptr to offsets
    ld.w  SONG_INSTRUMENT_TABLE[r8], r8
    
    add r5, r8    ;pointer to adress of script
    ld.w 0[r8],r8 ;adress of script
    
    st.w r8, o_inst_ptr[R_current_channel]
    ret
;-----------------------------------------------------------
play_instrument: 
    in.b o_inst_on[R_current_channel], r5
    cmp r0,r5
    bnz _continue_playing
    jump _nothing_running

_continue_playing
    in.b o_inst_now[R_current_channel],r5
    add 1, r5
    st.b r5,o_inst_now[R_current_channel]
    
    in.b o_inst_next[R_current_channel],r6
    cmp r5,r6 ;r6-r5
    be _update_instrument ;2021 what if now > next?
                          ;shouldnt happen, though!
    ret

_update_instrument
    ld.w o_inst_ptr[R_current_channel],r9
    ;fetch byte from that position
    in.b 0[r9], r5
    cmp r5, r0
    bne _more_to_come

_instrument_done ;script has 0 byte
    st.b r0, o_inst_on[R_current_channel]
    ret
    
_more_to_come
    ;r5 is first byte that also was not zero
    st.b r5, o_inst_next[R_current_channel]
    
    st.b r0, o_inst_now[R_current_channel]
    
    ;r9 is pointer to instrument script!
    add 1, r9
    in.b 0[r9], r5
    mov r5, r10 ;instrument_update_flags
    ;r10 is instrument_update_flag
;-------

;read flags
    andi HARDNOTE, r10,r11
    bz _no_update_hardnote
    call _update_hardnote

_no_update_hardnote
    andi VOL, r10, r11
    bz _no_update_volume
    call _update_volume
    
_no_update_volume
    andi WAVE, r10, r11
    bz _no_update_wave 
    call _update_wave

_no_update_wave    
    andi NOTE_OFF, r10,r11
    bz _no_update_note_off
    call _update_note_off
    
_no_update_note_off    
    andi FREQ_OFF, r10,r11
    bz _no_update_freq_off
    call _update_freq_off
    
_no_update_freq_off    
    andi LOOPER, r10,r11
    bz _no_loop
    call _prepare_loop
    ret
    
_no_loop    
    add 1, r9
    st.w r9,o_inst_ptr[R_current_channel]
    
_nothing_running
    ret
;---------------------------------------
_looper_code

_prepare_loop
    add 1, r9
    in.b 0[r9], r5
    sub r5,r9
    mov 2,r5
    sub r5,r9
    st.w r9,o_inst_ptr[R_current_channel]
    jump _update_instrument
    ret
;---------------------------------------
_update_volume
    ;s3m 0..63, VB 0..15
    add 1, r9
    in.b 0[r9], r5
    cmp r5,r0
    bz _write_zero
   
    shr 2, r5 ;63->15
    in.b o_panning[R_current_channel],r20 ;r20 is panning value
    
    shl 3, r5 ;volume*8
    add r20,r5 ;r5 = vol*8+panning
    movw PANTABLE, r20
    add r5,r20
    in.b 0[r20],r5
    
_write_zero
    st.b r5,o_S1LRV[R_chan_reg_base];[r30]
    ret
;---------------------------------------
_update_hardnote
    add 1, r9
    in.b 0[r9], r5 ;the hardnote pointer
    
    add 1, r9
    ld.b 0[r9], r6 ;r6 is the signed offset
    
    movw NOTES_LO, r30
    add r5, r30 ;add current note to note_table
    in.b [r30], r11 ; r11 has freq-low

    movw NOTES_HI, r30
    add r5, r30 ;add current note to note_table
    in.b [r30], r30 ; r30 has freq-high

    shl 8,r30
    add r11,r30
    
    ;r30 = 16 bit freq now
    add r6,r30
    andi $ff,r30,r5 ;r5 = low freq
    shr 8,r30       ;r30 = high
    
    st.b   r30, o_S1FQH[R_chan_reg_base]
    st.b   r5, o_S1FQL[R_chan_reg_base]
    ret
;---------------------------------------
_update_note_off
    add 1, r9
    ld.b 0[r9], r5 ;r5 is the signed offset
    
    in.b o_base_note[R_current_channel], r6
    
    ;base note in r6
    ;now add the offset
    
    add r5,r6
    andi $ff,r6,r6 ;limit to byte size for negative offset
    
    st.b r6, o_base_note[R_current_channel]
    
    add -3,r6 ;20213 correction!
    
    movw NOTES_LO, r30
    add r6, r30 ;add current note to note_table
    in.b [r30], r11 ;
    st.b   r11, o_S1FQL[R_chan_reg_base];[r8]

    movw NOTES_HI, r30
    add r6, r30 ;add current note to note_table
    in.b [r30], r11 ;
    st.b   r11, o_S1FQH[R_chan_reg_base];[r8]
    ret
;---------------------------------------
_update_freq_off
    add 1, r9
    ld.b 0[r9], r5 ;r5 is the signed offset
    
    in.b o_base_note[R_current_channel], r6
    add -3, r6 ;20213
    
    movw NOTES_LO, r30
    add r6, r30 ;add current note to note_table
    in.b [r30], r11 ;

    movw NOTES_HI, r30
    add r6, r30 ;add current note to note_table
    in.b [r30], r8 ;
    
    shl 8,r8
    add r8,r11 ;r11 = 16bit freq
    andi $ffff,r11,r11 ;limit range (needed?)
    add r5,r11 ;add signed(!) offset
    
    andi $ff,r11,r30 ;low
    shr 8,r11
    andi $ff,r11,r11 ;high
    st.b   r30, o_S1FQL[R_chan_reg_base];[r8]
    st.b   r11, o_S1FQH[R_chan_reg_base];[r8]
    ret
;---------------------------------------
_update_wave       
    ;r9 is pointer to instrument script!
    add 1, r9
    in.b 0[r9], r5
    andi $80,r5,r30 ;is bit 7 set? then its a trap ;-))
    bne _trapset
    st.b   r5, o_S1RAM[R_chan_reg_base];l[r30]        
    ret
_trapset
    andi $7,r5,r30 ;take bits 0-3
    shl 4,r30
    st.b r30, trap'lo[R_ram_base]
    st.b   r30, o_S1EV1[R_chan_reg_base]
     
    ret

;-----------------------------------------------------------
end_player1
;=========================
;nice routine by GuyPerfect, Date: April 26, 2013
read_keypad_hw

    movhi $200, r0, r12
    movea $84, r0, r11
    st.b  r11, $28[r12]; /* hw read, disable interrupts */;;;

;;    /* wait for the hardware read to complete the inefficient way )-: */
_lkey_loop_hw:
        ld.b $28[r12], r11
        andi $02, r11, r11
        bnz _lkey_loop_hw;

;    /* retrieve and concatenate the input bits */
    in.b 16[r12], r10
    in.b 20[r12], r11
    shl  8, r11
    or   r11, r10
    br both_methods

;enthusi: I skip the soft method as it didnt work too well on emulators
read_keypad
;http://perfectkiosk.net/stsvb.html#game_pad_data_registers
;/*
;  Read game pad input, returning all 16 bits
;  uint16_t vueReadGamePadSW();
;  Author: dasi, Guy Perfect
;  Date: April 26, 2013
;*/
;/* !!! WARNING !!! - This function may be wonky on some controllers */
;vueFunction(_vueReadGamePadSW)
    movhi $200, r0, r12
    movea $20, r0, r11
    st.b  r11, $28[r12]; /* game pad latch signal */

 ;   /* send 0, 1 signals to the game pad 16 times */
    shr 1, r11  ; /* 0x10, a low clock signal */
    mov r11, r10; /* 16, the number of iterations */
_loop_sw
        mul  r0, r0      ; /* this delay seems to fix the controller issue */
        add  -1, r10
        st.b r11, 40[r12]; /* send a 0 signal */
        st.b r0, 40[r12] ; /* send a 1 signal */
    bnz _loop_sw

 ;   /* retrieve and concatenate the input bits */
    in.b 16[r12], r10
    in.b 20[r12], r11
    shl  8, r11
    or   r11, r10

both_methods
    movw keypad_state, r11
    st.h r10,[r11]
     movw    keypad_previous, r7
     ld.h    [r7], r8
     st.h    r10, [r7]
     
     cmp r8,r10
     bne _new_state
    
     mov r0,r10 ;if new=old then new=0
        
_new_state     
    
_no_new_state
     movw    keypad_pressed, r7
     st.h    r10, [r7]
     ret
done
    ret
;-------------------------------------------
act_on_keys
    movw $05000000, R_ram_base ;variables BASE      

    movw keypad_pressed, r11
    in.h [r11],r15
    
    movw    SDR_LL, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_left
_left
    in.b cursor_position'lo[R_ram_base], r6
    cmp r0,r6
    be done
    add -1,r6
    st.b r6, cursor_position'lo[R_ram_base]

_not_left    
    movw    SDR_LR, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_right
_right
    in.b cursor_position'lo[R_ram_base], r6
    mov 5,r7
    cmp r7,r6
    be done
    add 1,r6
    st.b r6, cursor_position'lo[R_ram_base]

_not_right    
    movw    SDR_A, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_abutton
_abutton
    in.b cursor_position'lo[R_ram_base], r6
    movw channel_on,r16
    add r6,r16
    in.b [r16],r7
    xori 1,r7, r7
    st.b r7,[r16]
    
    ;grey out/in number
    ;r6 is still channel number
    mov r6, r7
    shl 4,r7
    movw BG_MAP, r16
    addi 8, r16,r16
    add r7,r16
    in.h [r16], r5
    xori (2<<14),r5, r5
    st.h r5, [r16]
    
_not_abutton    
    movw    SDR_B, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_bbutton
;--------------------------------------------------    
_bbutton

;--------------------------------------------------    

_not_bbutton
    movw    SDR_LU, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_leftup
_leftup
    movw timer_value, r16
    in.h [r16],r5
    addi 1,r5,r5
    st.h r5,[r16]
    call reset_timer

_not_leftup
    movw    SDR_LD, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_leftdown
_leftdown
    movw timer_value, r16
    in.h [r16],r5
    addi -1,r5,r5
    st.h r5,[r16]
    call reset_timer
_not_leftdown

_lefttrigger
    movw    SDR_LT, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_lefttrigger
	
    sei
    in.b current_tune'lo[R_ram_base], r6
    add -1,r6
    bp _ok2
    mov number_of_songs, r6
    add -1, r6
_ok2
    st.b r6,current_tune'lo[R_ram_base]
    
    movw (BG_MAP+128*23), r16
    st.h r6,8[r16]
    ;reset all waves to 0 for silence
    
	;0x01000400	S1INT	Channel 1 Sound Interval Specification Register

    movea %00011111, r0, r28
    movw VSU_S1INT, R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    
    movw VSU_S1INT, R_chan_reg_base
    call init_song
    
    ;announce change of all waves
    ;st.b r0, new_wave_src'lo[R_ram_base]
    ;mov 1,r6
    ;st.b r6, new_wave'lo[R_ram_base]
    
    ;movw    VSU_SSTOP, r8
    ;movea   $1, r0, r6
    ;st.h    r6, [r8]
    movw timer_count,r6
        mov 10, r7
        st.w r7,0[r6] ;reset timer count
        movw total_time,r6
        st.w r0,0[r6]
          
        st.b r0, new_wave'lo[R_ram_base]
        st.b r0, scroll_flag'lo[R_ram_base]
        st.b r0, cmd_flag'lo[R_ram_base]
        st.b r0, pan_flag'lo[R_ram_base]
        st.b r0, break_flag'lo[R_ram_base]
        st.b r0, break_target'lo[R_ram_base]
        
        st.b r0,text_ptr'lo[R_ram_base]
        st.h r0,text_fade_ptr'lo[R_ram_base]
    
        st.b r0,text_ptr_next'lo[R_ram_base]
    
        mov     2, r22 ;enable cache as default
        ldsr    r22, 24;CHCW
        
    movw pattern_ptr, r8
    mov 0,r7
    st.b r7, [r8]
        
    movw chn0, r4
    mov r0,r29
  
    movw $05000000, R_ram_base ;variables
    call init_player
    movw chn0, r4
    mov r0,r29

    cli
    ret
;------------------------------
_not_lefttrigger
_righttrigger
    movw    SDR_RT, r16
    and     r15, r16
    andi    $FFFC, r16, r16 ;set0 bit 0,1
    bz      _not_righttrigger
	
    sei
    in.b current_tune'lo[R_ram_base], r6
    add 1,r6
    cmp number_of_songs, r6
    bne _ok
    mov r0, r6
_ok    
    st.b r6,current_tune'lo[R_ram_base]
    
    movw (BG_MAP+128*23), r16
    st.h r6,8[r16]
        
        
    ;reset all waves to 0 for silence
    
	;0x01000400	S1INT	Channel 1 Sound Interval Specification Register

    movea %00011111, r0, r28
    movw VSU_S1INT, R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    addi 64, R_chan_reg_base,R_chan_reg_base
    st.b   r28, o_S1INT[R_chan_reg_base];[r30]   
    
    movw VSU_S1INT, R_chan_reg_base
    call init_song
    
    ;announce change of all waves
    ;st.b r0, new_wave_src'lo[R_ram_base]
    ;mov 1,r6
    ;st.b r6, new_wave'lo[R_ram_base]
    
    ;movw    VSU_SSTOP, r8
    ;movea   $1, r0, r6
    ;st.h    r6, [r8]
    movw timer_count,r6
        mov 10, r7
        st.w r7,0[r6] ;reset timer count
        movw total_time,r6
        st.w r0,0[r6]
          
        st.b r0, new_wave'lo[R_ram_base]
        st.b r0, scroll_flag'lo[R_ram_base]
        st.b r0, cmd_flag'lo[R_ram_base]
        st.b r0, pan_flag'lo[R_ram_base]
        st.b r0, break_flag'lo[R_ram_base]
        st.b r0, break_target'lo[R_ram_base]
        
        st.b r0,text_ptr'lo[R_ram_base]
        st.h r0,text_fade_ptr'lo[R_ram_base]
    
        st.b r0,text_ptr_next'lo[R_ram_base]
    
        mov     2, r22 ;enable cache as default
        ldsr    r22, 24;CHCW
        
    movw pattern_ptr, r8
    mov 0,r7
    st.b r7, [r8]
        
    movw chn0, r4
    mov r0,r29
  
    movw $05000000, R_ram_base ;variables
    call init_player
    movw chn0, r4
    mov r0,r29

    cli
    ret
_not_righttrigger    
_done


        ret
;=============================================
reset_timer 
        movw (BG_MAP+128*23), r16
        
        movw TIMER_TLR, r5
        movw timer_value, r7
        in.b [r7],r7
        st.b r7, [r5]
        st.h r7,2[r16]
        
        movw TIMER_THR, r5
        movw (timer_value+1), r7
        in.b 0[r7],r7
        st.b   r7, [r5]
        st.h r7,0[r16]
        ret
;-----------------------------------------------------------
write_text
        
        movw $05000000, R_ram_base ;variables BASE   
        in.b pattern_ptr'lo[R_ram_base], r10
        
        movw textline_table_ram,r11
        add r10,r11
        in.b [r11],r11 ;next line ptr
        cmp r0,r11
        bz _nothing ;0 means nothing happens
        
        in.h text_fade_ptr'lo[R_ram_base], r12
        cmp r0,r12
        bz _newtext ;ready for a new text?
        br _fade_text
                
_newtext        
        in.b text_ptr_last'lo[R_ram_base],r12
        cmp r10,r12
        be _nothing
        
        st.b r10, text_ptr_last'lo[R_ram_base] ;last pattern_ptr we used text from
        movw (128*16), r10
        st.h r10, text_fade_ptr'lo[R_ram_base]
        st.b r11, text_ptr_next'lo[R_ram_base]
        
_fade_text
        
        in.b text_ptr'lo[R_ram_base], r10
        
        in.h text_fade_ptr'lo[R_ram_base], r9
        add -1,r9
        st.h r9, text_fade_ptr'lo[R_ram_base]
         shr 7,r9
        
        movw (BG_MAP+128), r12
        st.h r9,[r12]
        
        mov 10,r12
        cmp r12,r9
        bne _no_textupdate
        
        in.b text_ptr_next'lo[R_ram_base], r10
        st.b r10,text_ptr'lo[R_ram_base]
_no_textupdate        
        movw pal_table, r11
        add r9,r11
        in.b [r11],r15
        shl 14,r15 ;palette bits
        
        movw depth_table, r11
        add r9,r11
        ld.b [r11],r16
        movw (WORLD_TBL + 29*32 + 4),r9 ;parallax for world 31
        st.h r16,[r9]
        
;----        
        shl 2,r10
        movw text_table, r11
        add r11,r10
        ld.w [r10],r10 ;fetch full adr for text line

        movw (BG_MAP+128*30), r11
        movw (262 - 32),r13
        movw 99,r14
_loop        
        in.b [r10],r12
        cmp r12,r0
        bz _end
        
        add r13,r12
        or r15,r12
        st.h r12,[r11]
        add r14,r12
        st.h r12,128[r11]
        add 2, r11
        add 1,r10
        br _loop
_nothing
_end
        ret
        
    EVEN 4

;mw23 put this in RAM and just edit first 2 entries
;to 18 + current song
textline_table_rom
    ;main tune
    db  1, 0, 2, 0, 0, 3, 0, 4, 0, 5 ;0
    db  0, 6, 0, 7, 0, 8, 0, 9, 0,10 ;10
    db  0,11, 0,12, 0,13, 0,14, 0,15 ;20
    db  0,16, 0,17, 0, 0, 0,27, 0,28 ;30
    db  0,29, 0, 0, 1, 0, 2, 0, 3, 0 ;40
    db  4, 0, 5, 0, 6, 0, 7, 0, 8, 0 ;50
    db  0, 0, 0, 2, 0, 3, 0, 4, 0, 5 ;60
    db  0, 6, 0, 2, 0, 2, 0, 2, 0, 2 ;70
    db 0,0
    ;tech demo
   ; db 18,19,20,21,22,23, 24, 25,26,0
   


    
    EVEN 4
text_table
    dw 0 ;dummy
    dw text_line00;1
    dw text_line01;2
    dw text_line02;3
    dw text_line03;4
    dw text_line04;5
    dw text_line05;6
    dw text_line05b;7
    dw text_line05c;8
    dw text_line06;9
    dw text_line06a;10
    dw text_line06b;11
    dw text_line06c;12
    dw text_line06d;13
    dw text_line06e;14
    dw text_line06f;15
    dw text_line06g;16
    dw text_line06h;17

;techdemo    
    dw text_line08;18 ;song 1
    dw text_line09;19 ;song 2
    dw text_line0a;20 ;song 3
    
    dw text_line0b;21
    dw text_line0c;22
    dw text_line0d;23
    dw text_line0e;24
    dw text_line0f;25
    dw text_line07;26
  
;thanks
    dw text_line_thanks  ;27 
    dw text_line_thanks2 ;28
    dw text_line_thanks3 ;29
        
    
pal_table
    db 0,0,0,0
    db 0,0,0,0
    db 0,1,2,3
    db 3,2,1,0

    
depth_table
    ifdef REALHW
    db -4,-4,-4,-4 ;on  brings up text closer than the screen plane
    db -4,-4,-4,-4 ;on  which works nicely on real hw but looks confusing in emulation
    db -2,0,2,4 ;out
    db 3,0,-2,-4 ;in
    else
    db  0, 0, 0, 0
    db  0, 0, 0, 0
    db  0, 0, 2, 4 
    db  3, 2, 1, 0 ;in
    endif

begin_text

;       012345678901234567890123456789012345678901234567 ;48        
text_line00
    db "             PriorArt presents                ",0
text_line01
    db "       VirtualBeat Audio Engine 2021          ",0
text_line02
    db "               -   VBeat  -                   ",0        
text_line03
    db "               code _ enthusi                 ",0
text_line04
    db "                tune _ jammer                 ",0
text_line05
    db "                 font _ v3to                  ",0
text_line05b
    db " Press B-Button for small tech-demonstration! ",0
text_line05c
    db " The whole engine is free under BSD 3-clause.  ",0
text_line06 
    db "    Songs are composed in common s3m format.  ",0
text_line06a
    db "      You can use the free Schismtracker!     ",0
text_line06b    
    db "  We provide a tool to encode the music data. ",0
text_line06c
    db "   Instruments have a very flexible design.   ",0
text_line06d    
    db " You can change wave pointer, note, pitch,_   ",0
text_line06e
    db "  _ volume at the players rate, i.e. 50 Hz.   ",0
text_line06f
    db " Loops can also be part of the instrument_    ",0
text_line06g
    db "  _for classical arpeggios or echos.          ",0
text_line06h
    db "                                              ",0
;-------------------------------------------------------------
text_line_thanks
    db "  Special thanks go out to:                   ",0
text_line_thanks2
    db "  GuyPerfect for help getting into the VB!    ",0
text_line_thanks3
    db "  Kresna for his inspirational free VB game!  ",0
;-------------------------------------------------------------
;EDIT HERE 2023 VbeatMachine version
text_line08
    db "          Song 1                              ",0
text_line09
    db "          Song 2                              ",0
text_line0a
    db "          Song 3                              ",0
text_line0b
    db "                                              ",0    
text_line0c
    db "                                              ",0
text_line0d
    db "                                              ",0
text_line0e
    db "                                              ",0
text_line0f
    db "                                              ",0
text_line07    
    db "                                              ",0

end_text    

    EVEN 4
;-----------------------------------------------------------
begin_genhex
generate_hexfont
    ;CHAR_TBL
    
    movw CHAR_TBL,r11 ;destination
    movw hexfontdata, r24
    mov 15,r23 ;how often to repeat MSB
    
    mov 0, r14; which character to use MSB
   
_charsetloop
    mov 0, r18; which character to use LSB
    mov 15,r15 ;how often to repeat LSB
_digitloop    
    ;msb source
    mov r24, r10 ;source
    mov r14,r16
    ;get offset in hexfontdata
    andi 1,r16,r17 ;0(2,4) or 1(3,5..)?
    add r17,r10
    shr 1,r16
    shl 4, r16 ;*8
    add r16,r10
    
    ;lsb source
    mov r24, r20 ;source
    mov r18,r21
    ;get offset in hexfontdata
    andi 1,r21,r22 ;0(2,4) or 1(3,5..)?
    add r22,r20
    shr 1, r21
    shl 4, r21 ;*8
    add r21,r20
    
    mov 8, r13
_charloop    
    in.b [r10],r12 ;msb
    st.b r12, 0[r11]
    
    in.b [r20],r12 ;lsb
    st.b r12, 1[r11]
    
    add 2,r10
    add 2,r20
    add 2,r11
    add -1,r13
    bne _charloop
;----
    add 1, r18
    add -1, r15
    bp _digitloop
    
    add 1, r14
    add -1, r23
    bp _charsetloop
    ret
    
hexfontdata
    LIBBIN hexset.dat
    EVEN 4
end_genhex    
;-------------------------------------------
    
setup_bitmap:
        movw FONT_CHARSET, r10
        movw (CHAR_TBL+256*16),r11
        call depack
        
        ;movw PACKED_CHANNEL, r10 ;for 16k version
        ;movw $0500a000, r11
        ;call depack
         
        call generate_hexfont

setup_worlds

WORLDCOUNT equ 4
;write world attributes
        movw WORLD_TBL, r12
        movw (31-WORLDCOUNT),r11 ;first world - 1
        shl 5,r11 ;*32
        add r11,r12

        ;write end marker first
        movea   WORLD_END, r0, r10
        st.h    r10, [r12]
        
        ;and advance to actual world
        addi 32,r12,r12 
        
        movw 32*WORLDCOUNT,r11 ;length
        movw my_world_attr, r10
_loop
        ld.h [r10],r13
        st.h r13,[r12]
        add  2, r10
        add  2, r12
        add -2, r11
        bnz _loop
        
_setup_bgmask        

        movw BG_MASK, r10
        movw (BG_MAP+$2000),r11
        call depack
        
        movw BG_LOGO, r10
        movw (BG_MAP+$4000),r11
        call depack
        
        ret
        
;prepare background mask map
        movw (BG_MAP+$2000),r10
        movw ($101+99),r11
        movw (64*64),r12
_loop2        
        st.h r11,[r10]
        add 2,r10
        add -1, r12
        bne _loop2
        
        ret
;=============================================================        
   
begin_depack
depack
    push lp
    movea $ff,r0,r20 ;for later
    in.h [r10],r12 ;size
    add 2,r10
    
    mov r10,r15
    add r12,r15 ;r15 = end of packed data
_getToken
   in.b [r10],r16 ;token
   add 1, r10 

   mov r16,r14 
   shr 4,r14 ;r14 = literal 
   be _getOffset

   jal _getLength

   mov r10,r12
   jal _copyData ;literal copy r12 to r11
   mov r12,r10

_getOffset
   in.b [r10],r13
   mov r11,r12
   sub r13,r12
   in.b 1[r10],r13
   shl 8,r13
   sub r13,r12
   add 2,r10
   
   andi 15,r16,r14 ;match length
   jal _getLength 
   add 4,r14 ;add min size offset
   jal _copyData  ;copy match r12 to r11
   cmp r15,r10 ;end of data stream?
   ble _getToken
   pop lp
   ret
   
_getLength:
   cmp $f,r14 ;max=$f indicates more to come
   bne _gotLength

_getLengthLoop:   
   in.b [r10],r13
   add 1,r10
   add r13,r14
   cmp r13,r20 ;r20=ff
   be _getLengthLoop
_gotLength:
    ret

_copyData:
    in.b [r12],r21
    st.b r21,[r11]
    add 1,r12
    add 1,r11
    add -1,r14
    bne _copyData
    ret
end_depack    
;----------------------------------------------------
    EVEN 4
my_world_attr:
;-----------------------        
        ;28
        dh      WORLD_LON | WORLD_RON | WORLD_BGM_NORMAL | WORLD_SCX_0 | WORLD_SCY_0 | 0
        dh      0                                       ; /WORLD_GX
        dh      0                                       ; /WORLD_GP
        dh      0                                       ; /WORLD_GY
        dh      0                                       ; /WORLD_MX
        dh      0                                       ; /WORLD_MP
        dh      0                                       ; /WORLD_MY
        dh      384                                     ; /WORLD W
        dh      224                                     ; /WORLD_H
        dh      0                                       ; /WORLD_PARAM
        dh      0                                       ; /WORLD_OVERPLANE
        
        dh 0 ;filler
        dh 0
        dh 0
        dh 0
        dh 0
;-----------------------        
        ;29
        dh      WORLD_LON | WORLD_RON | WORLD_BGM_NORMAL | WORLD_SCX_0 | WORLD_SCY_0 | 0
        dh      10                                       ; /WORLD_GX
        dh      (-5 & $ffff)                             ; /WORLD_GP
        dh      192                                      ; /WORLD_GY
        dh      0                                        ; /WORLD_MX
        dh      0                                        ; /WORLD_MP
        dh      30*8                                     ; /WORLD_MY
        dh      8*48                                     ; /WORLD W
        dh      16                                       ; /WORLD_H
        dh      0                                        ; /WORLD_PARAM
        dh      0                                        ; /WORLD_OVERPLANE

        dh 0 ;filler
        dh 0
        dh 0
        dh 0
        dh 0
;----------------------------------------------------------
 ;30
        dh       WORLD_LON | WORLD_RON | WORLD_BGM_NORMAL | WORLD_SCX_0 | WORLD_SCY_0 | 1
        dh      0                                       ; /WORLD_GX
        dh      0                                       ; /WORLD_GP
        dh      0                                       ; /WORLD_GY
        dh      0                                       ; /WORLD_MX
        dh      0                                       ; /WORLD_MP
        dh      0                                       ; /WORLD_MY
        dh      384                                     ; /WORLD W
        dh      224                                     ; /WORLD_H
        dh      0                                       ; /WORLD_PARAM
        dh      0                                       ; /WORLD_OVERPLANE
        
        dh 0 ;filler
        dh 0
        dh 0
        dh 0
        dh 0
;-------------------------------------------------------------------------------        
 ;31
        dh      WORLD_LON | WORLD_RON | WORLD_BGM_NORMAL | WORLD_SCX_0 | WORLD_SCY_0 | 2
        dh      0                                       ; /WORLD_GX
        dh      0                                       ; /WORLD_GP
        dh      0                                       ; /WORLD_GY
        dh      0                                       ; /WORLD_MX
        dh      6                                       ; /WORLD_MP
        dh      0                                       ; /WORLD_MY
        dh      400                                     ; /WORLD W
        dh      256                                     ; /WORLD_H
        dh      0                                       ; /WORLD_PARAM
        dh      0                                       ; /WORLD_OVERPLANE
        
        dh 0 ;filler
        dh 0
        dh 0
        dh 0
        dh 0
;-------------------------------------------------------------
       EVEN 4
palette_data:
        dh      %0000000011100100
        dh      %0000000011100001
        dh      %0000000000100111
        dh      %0000000011000110
        dh      %0000000011100100
        dh      %0000000000111001
        dh      %0000000001001110
        dh      %0000000010010011
;-------------------------------------------------------------
column_table_data ;still aligned
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
        db $FE, $FE, $FE, $FE, $FE, $FE, $E0, $BC
        db $A6, $96, $8A, $82, $7A, $74, $6E, $6A
        db $66, $62, $60, $5C, $5A, $58, $56, $54
        db $52, $50, $50, $4E, $4C, $4C, $4A, $4A
        db $48, $48, $46, $46, $46, $44, $44, $44
        db $42, $42, $42, $40, $40, $40, $40, $40
        db $3E, $3E, $3E, $3E, $3E, $3E, $3E, $3C
        db $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C
        db $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C
        
;-------------------------------------------------------------        
init_text
    movw textline_table_rom, r12
    movw textline_table_ram, r11
	movw 100, r14
_loop
	in.b [r12],r21
    st.b r21,[r11]
    add 1,r12
    add 1,r11
    add -1,r14
    bne _loop
    movw 255,r14
    st.b r14, text_ptr_last'lo[R_ram_base]
    ret
;-------------------------------------------------------------        

init_song 
	movw $05000000, R_ram_base ;variables BASE
	in.b current_tune'lo[R_ram_base], r11
	;*4 and add to start of song address table
	shl 2, r11
	movw MUSIC_TABLE, r12
	add r11,r12
	ld.w [r12],r12
	;copy 24 bytes from songdata into SONG_TABLE in ram
	;movw song1_data, r12
	movw SONG_TABLE, r11
	movw 25, r14
_loop
	in.b [r12],r21
    st.b r21,[r11]
    add 1,r12
    add 1,r11
    add -1,r14
    bne _loop
    
;and modify the 1st entry in the text table in ram
    in.b current_tune'lo[R_ram_base], r11
    addi 18, r11,r11
    st.b r11, textline_table_ram'lo[R_ram_base]
    movw 255,r11
    st.b r11, text_ptr_last'lo[R_ram_base]
    
    ret
;---------------------------    

;---------------------------
NOTES_LO
        LIBBIN note_timelo_0.bin
NOTES_HI
        LIBBIN note_timehi_0.bin
        
PANTABLE ;lookup table for panning-volume pairs
        LIBBIN panning.dat

        EVEN    4
FONT_CHARSET:
        LIBBIN   priorart_fontprep.dat
FONT_CHARSET_END 

        EVEN    4
BG_MASK
        LIBBIN   maskprep.dat
        
        EVEN    4
BG_LOGO
        LIBBIN   logomapprep.dat
;--------------------------------------------------------   
;offsets from SONG_TABLE
SONG_COL_TABLE equ 0
SONG_WAVESET_TABLE equ 4
SONG_INSTRUMENT_TABLE equ 8
SONG_MY_WAVE_0 equ 12
SONG_PLAYLIST equ 16
SONG_CHANNEL_TABLE equ 20

;in this order:
HARDNOTE    equ  64  ;8  affects BASENOTE
VOL         equ   8  ;8 (4)
WAVE        equ   4  ;8 (3)
NOTE_OFF    equ  16  ;8  based on BASENOTE (not touching BASENOTE!)
FREQ_OFF    equ  32  ;8  based on BASENOTE (not in combo with NOTE_OFF!)
LOOPER      equ 128  ;8

before_songdata
		EVEN    4
		
        org $7005000
begin_songdata        

;EDIT HERE 2023 VbeatMachine version
song1_data		
		FILE data_song1.asm
        EVEN 4
song2_data		
		FILE data_song2.asm
		EVEN 4
song3_data		
		FILE data_song3.asm
		EVEN 4
		
end_songdata          
;--------------------------------------------------
;EDIT HERE 2023 VbeatMachine version
number_of_songs equ 3
;--------------------------------------------------
    EVEN 4
;EDIT HERE 2023 VbeatMachine version
MUSIC_TABLE
	dw song1_data
	dw song2_data
    dw song3_data
	;dw song4_data
	;dw song5_data
	
;--------------------------------------------------------
end_binary
;--------------------------------------------------------
        org     $FFFFFDE0       ; title
        db      "PRIORART - VBEAT"

        org     $FFFFFDF4       ; reserved
        db      $00, $00, $00, $00, $00

        org     $FFFFFDF9       ; dev code
        db      "PA"

        org     $FFFFFDFB       ; game code
        db      "2302"

        org     $FFFFFDFF       ; ROM vers
        db      $00
        
;-------------------------------------------------------------------------------
; IRQ

		org     $FFFFFE00       ; Key Interrupt
        reti

        org     $FFFFFE10       ; Timer Interrupt
        push r30
        movea   #Timer_Interrupt'lo, r0, r30
        movhi   #Timer_Interrupt'hi1, r30, r30
        jmp [r30]

        org     $FFFFFE20       ; Expansion Port Interrupt
        reti

        org     $FFFFFE30       ; Link Port Interrupt
        reti

        org     $FFFFFE40       ; VIP Interrupt
        ;just ack here
        push r6
        push r7
        movw    INTPND, r6
        movw    INTCLR, r7
        ld.h    $0[r6], r6
        st.h    r6, $0[r7]
        pop r7
        pop r6
        reti

; Reset Vector 
        org     $FFFFFFF0 
        jump    Reset
