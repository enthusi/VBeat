SOURCE=jukebox_engine.asm
EMU=mednafen

audio.vb: $(SOURCE) VBDemo01_playlist.bin songdata.asm
	./isas -w 2  -t $(SOURCE) -o audio.o
	./islk audio.o -t -v -map -o audio.isx
	./isx2vb audio.isx audio.vb

#VBDemo01_playlist.bin: VBDemo01.s3m
#	python tracker2vb.py VBDemo01.s3m
#	
run: audio.vb
	$(EMU)  audio.vb
