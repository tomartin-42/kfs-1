CC = gcc
LD = ld
ASM = nasm
ISO = kfs.iso
ISO_DIR = iso
GRUB_MODULES = biosdisk iso9660 normal configfile multiboot

# -m32: genera código para la arquitectura i386 de 32 bits.
# -ffreestanding: no asume un entorno de ejecución alojado.
# -fno-stack-protector: evita referencias a __stack_chk_fail.
# -nostdlib: no enlaza archivos de inicio ni bibliotecas estándar.
# -nodefaultlibs: no enlaza automáticamente bibliotecas del compilador.
# -fno-builtin: evita sustituir funciones por implementaciones de la libc.
CFLAGS = -m32 \
         -ffreestanding \
         -fno-stack-protector \
         -nostdlib \
         -nodefaultlibs \
         -fno-builtin

all: kernel.bin

boot.o: boot.asm
	$(ASM) -f elf32 boot.asm -o boot.o

kernel.o: kernel.c
	$(CC) $(CFLAGS) -c kernel.c -o kernel.o

# The custom script fixes the entry point and kernel memory layout.
kernel.bin: boot.o kernel.o linker.ld
	$(LD) -m elf_i386 -T linker.ld boot.o kernel.o -o kernel.bin

check: kernel.bin
	grub-file --is-x86-multiboot kernel.bin

# --directory: usa exclusivamente los módulos de GRUB para BIOS/i386.
# --install-modules: copia en la ISO solo los módulos indicados y sus dependencias.
# --modules: precarga esos módulos en la imagen principal de GRUB.
# --locales, --fonts, --themes: omite recursos gráficos y traducciones innecesarios.
# --compress=xz: comprime los componentes de GRUB para mantener la ISO bajo 10 MB.
# -o: indica el nombre del archivo ISO de salida; ISO_DIR es su árbol de entrada.
$(ISO): fclean kernel.bin grub.cfg Makefile 
	rm -rf $(ISO_DIR) $(ISO)
	mkdir -p $(ISO_DIR)/boot/grub
	cp kernel.bin $(ISO_DIR)/boot/kernel.bin
	cp grub.cfg $(ISO_DIR)/boot/grub/grub.cfg
	grub-file --is-x86-multiboot kernel.bin
	grub-mkrescue \
		--directory=/usr/lib/grub/i386-pc \
		--install-modules="$(GRUB_MODULES)" \
		--modules="$(GRUB_MODULES)" \
		--locales="" \
		--fonts="" \
		--themes="" \
		--compress=xz \
		-o $(ISO) $(ISO_DIR)
	test "$$(stat -c %s $(ISO))" -lt 10000000

iso: $(ISO)

# QEMU loads the Multiboot kernel directly; this does not test a GRUB image.
run: kernel.bin
	qemu-system-i386 -kernel kernel.bin

run-iso: $(ISO)
	qemu-system-i386 -cdrom $(ISO)

clean:
	rm -rf *.o $(ISO_DIR)

fclean: clean
	rm -f kernel.bin 

re: fclean all

.PHONY: all check iso run run-iso clean fclean re
