# Adjust the run address to match the .org in the source code
all: bootloader.hex

bootloader.hex: bootloader.asm
	a85 bootloader.asm -l bootloader.lst -o bootloader.hex
	
bootloader_z80.bin: bootloader_z80.asm
	zasm -i bootloader_z80.asm -l bootloader_z80.lst -o bootloader_z80.bin
	
bootloader_z80.hex: bootloader_z80.bin
	objcopy -I binary -O ihex bootloader_z80.bin bootloader_z80.hex

clean:
	$(RM) *.lst *.hex labels.asm *.bin

distclean: clean
