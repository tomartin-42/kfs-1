CC = gcc
LD = ld
ASM = nasm

CFLAGS = -m32 -ffreestanding -fno-stack-protector -nostdlib -nodefaultlibs

all: kernel.bin

boot.o: boot.asm
	$(ASM) -f elf32 boot.asm -o boot.o

kernel.o: kernel.c
	$(CC) $(CFLAGS) -c kernel.c -o kernel.o

kernel.bin: boot.o kernel.o
	$(LD) -m elf_i386 -T linker.ld boot.o kernel.o -o kernel.bin

run: kernel.bin
	qemu-system-i386 -kernel kernel.bin

clean:
	rm -f *.o *.bin
