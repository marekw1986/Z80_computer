# Adjust the run address to match the .org in the source code
all: bootloader_z80.bin
	
bootloader_z80.p: bootloader_z80.asm
	asl -o bootloader_z80.p -L -OLIST bootloader_z80.lst bootloader_z80.asm -cpu z80
	
bootloader_z80.bin: bootloader_z80.p
	p2bin -l '$$00' bootloader_z80.p bootloader_z80.bin

clean:
	$(RM) *.lst *.hex labels.asm *.bin *.p

distclean: clean
