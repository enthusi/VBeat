SOURCE=engine.asm
EMU=mednafen

audio.vb: $(SOURCE) VBDemo01_playlist.bin
	# Build the rom
	wine ISAS32.exe -w 2  -t $(SOURCE) -o audio.o
	wine ISLK32.exe audio.o -t -v -map -o audio.isx
	wine VUIC.EXE audio.isx audio.vb

VBDemo01_playlist.bin: VBDemo01.s3m
	python tracker2vb.py VBDemo01.s3m
	
run: audio.vb
	$(EMU) AUDIO.VB
