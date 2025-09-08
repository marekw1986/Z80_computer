# Adjust the run address to match the .org in the source code
all: bootloader.hex

bootloader.hex: bootloader.asm
	a85 bootloader.asm -l bootloader.lst -o bootloader.hex
	
bootloader_z80.bin: bootloader_z80.asm
	asl -o bootloader_z80.bin -L -OLIST bootloader_z80.lst bootloader_z80.asm -cpu z80

clean:
	$(RM) *.lst *.hex labels.asm *.bin

distclean: clean
