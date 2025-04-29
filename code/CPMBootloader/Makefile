# Adjust the run address to match the .org in the source code
all: bootloader.hex

bootloader.hex: bootloader.asm
	a85 bootloader.asm -l bootloader.lst -o bootloader.hex

clean:
	$(RM) *.lst *.hex labels.asm

distclean: clean
