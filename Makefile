CC = gcc
LD = ld
ASM = nasm

# Build freestanding 32-bit code without host runtime dependencies.
CFLAGS = -m32 \
         -ffreestanding \
         -fno-stack-protector \
         -nostdlib \
         -nodefaultlibs

all: kernel.bin

boot.o: boot.asm
	$(ASM) -f elf32 boot.asm -o boot.o

kernel.o: kernel.c
	$(CC) $(CFLAGS) -c kernel.c -o kernel.o

# The custom script fixes the entry point and kernel memory layout.
kernel.bin: boot.o kernel.o
	$(LD) -m elf_i386 -T linker.ld boot.o kernel.o -o kernel.bin

# QEMU loads the Multiboot kernel directly; this does not test a GRUB image.
run: kernel.bin
	qemu-system-i386 -kernel kernel.bin

clean:
	rm -f *.o *.bin

.PHONY: all run clean
