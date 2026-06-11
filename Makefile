# ==============================================================================
#  Makefile — KFS-1
#  Sistema de compilación automática para el kernel mínimo KFS-1.
#
#  ¿Qué hace Make?
#    Make es una herramienta que automatiza la compilación. Lee este archivo
#    (Makefile) y determina qué comandos ejecutar según:
#      - Los archivos fuente modificados (dependencias).
#      - Los objetivos solicitados (all, run, clean).
#    Solo recompila lo necesario, ahorrando tiempo.
#
#  Estructura de una regla:
#    objetivo: dependencias
#        comando
#
#    Make ejecuta "comando" solo si "dependencias" es más reciente que
#    "objetivo", o si "objetivo" no existe.
# ==============================================================================


# ==============================================================================
#  Variables / Herramientas del sistema
# ==============================================================================

# CC = gcc
#   Compilador de C (GNU C Compiler).
#   Traduce código C a código máquina (en este caso, x86 32 bits).
#   Se podría cambiar a clang, i686-elf-gcc, etc. según el toolchain.
CC = gcc

# LD = ld
#   Enlazador (GNU Linker).
#   Toma los archivos objeto (.o) y los fusiona en un solo binario (.bin)
#   siguiendo las instrucciones del linker script (linker.ld).
#   Se encarga de:
#     - Resolver símbolos (ej. kmain definido en C, referenciado en assembly).
#     - Asignar direcciones finales a cada sección.
#     - Generar el archivo ELF ejecutable listo para GRUB.
LD = ld

# ASM = nasm
#   Ensamblador (Netwide Assembler).
#   Traduce código assembly (boot.asm) a código máquina en formato ELF32.
#   Alternativas: nasm (estándar), gas (GNU Assembler), fasm, yasm.
#   NASM usa sintaxis Intel (mov esp, stack_top) a diferencia de GAS que
#   usa sintaxis AT&T (mov $stack_top, %esp).
ASM = nasm


# ==============================================================================
#  Flags de compilación de C (CFLAGS)
# ==============================================================================

CFLAGS = -m32 \
         -ffreestanding \
         -fno-stack-protector \
         -nostdlib \
         -nodefaultlibs \
	 -fno-builtin \
	 -fno-exceptions

# ── Desglose de cada flag ────────────────────────────────────────────────────
#
# -m32
#   Genera código para x86 de 32 bits (i386).
#   En sistemas de 64 bits, GCC genera código x86_64 por defecto.
#   Este flag fuerza la generación de código 32 bits, necesario porque:
#     - El modo protegido de x86 es de 32 bits (no 64).
#     - GRUB arranca en modo protegido (32 bits), no en modo largo (64 bits).
#   En un sistema de 64 bits, requiere gcc-multilib instalado.
#
# -ffreestanding
#   Indica que el código se ejecutará en un entorno "freestanding"
#   (sin sistema operativo), en lugar de "hosted" (con SO).
#   Efectos:
#     - NO asume que existe una biblioteca estándar de C (libc).
#     - NO vincula automáticamente crt0 (startup code de C).
#     - main() NO tiene el prototipo estándar (int main(int argc, char** argv)).
#     - Permite usar tipos como size_t y NULL sin incluir headers estándar.
#
# -fno-stack-protector
#   Desactiva el "stack protector" de GCC (también llamado -fstack-protector).
#   ¿Qué hace el stack protector?
#     GCC inserta un "canary" (valor centinela) en el stack antes de cada
#     buffer local. Al salir de la función, verifica que el canary no haya
#     sido sobrescrito (detecta desbordamiento de buffer).
#   ¿Por qué desactivarlo?
#     El stack protector llama a __stack_chk_fail(), que es una función de
#     la libc que NO tenemos disponible en un entorno freestanding.
#     Sin este flag, el enlazador fallaría con "undefined reference to
#     __stack_chk_fail".
#
# -nostdlib
#   Le dice al compilador que NO vincule la biblioteca estándar de C (libc)
#   ni el código de inicio estándar (crt0, crti, crtn).
#   Sin este flag, GCC intentaría vincular:
#     - /usr/lib/crt0.o  (código de inicio)
#     - /usr/lib/libc.so (biblioteca estándar)
#     - /usr/lib/crtn.o  (código de finalización)
#   Todo eso depende del sistema operativo anfitrión y NO funciona en un
#   kernel freestanding (no hay SO debajo, no hay syscalls, etc.).
#
# -nodefaultlibs
#   Similar a -nostdlib, pero más específico: evita que GCC agregue
#   las bibliotecas por defecto (libc, libgcc, etc.) al enlazado.
#   La diferencia sutil:
#     -nostdlib = no agregues crt0 ni libc
#     -nodefaultlibs = no agregues ninguna biblioteca por defecto
#   Usar ambos es redundante pero explícito — refuerza la intención.


# ==============================================================================
#  Objetivos (targets)
# ==============================================================================

# ── all (objetivo por defecto) ────────────────────────────────────────────────
#   El primer objetivo del Makefile es el default.
#   Al ejecutar "make" sin argumentos, se construye kernel.bin.
all: kernel.bin


# ── boot.o — Ensamblar boot.asm ──────────────────────────────────────────────
#   Convierte boot.asm → boot.o (ELF32 object file).
#
#   -f elf32:
#     Formato de salida: ELF32 (Executable and Linkable Format, 32 bits).
#     ELF es el formato estándar de archivos objeto en sistemas Unix/Linux.
#     GRUB requiere ELF32 para cargar el kernel.
#     Alternativas:
#       -f bin   → binario plano (no sirve, GRUB necesita metadatos ELF)
#       -f elf64 → ELF64 (no sirve, estamos en 32 bits)
#       -f win32 → formato COFF (Windows, no sirve aquí)
#
#   boot.o:
#     Archivo objeto intermedio. No es ejecutable por sí solo; debe ser
#     enlazado con kernel.o para formar kernel.bin.
boot.o: boot.asm
	$(ASM) -f elf32 boot.asm -o boot.o


# ── kernel.o — Compilar kernel.c ─────────────────────────────────────────────
#   Convierte kernel.c → kernel.o (ELF32 object file).
#
#   -c:
#     Compila solo (compile only). NO enlaza.
#     Produce un archivo objeto (.o) en lugar de un ejecutable.
#     El enlazado se hace después, cuando juntamos boot.o + kernel.o.
#
#   kernel.o:
#     Archivo objeto con kmain() y clear_screen() compilados.
#     Contiene código máquina (section .text), datos (.data, .bss)
#     y una tabla de símbolos (kmain, clear_screen).
kernel.o: kernel.c
	$(CC) $(CFLAGS) -c kernel.c -o kernel.o


# ── kernel.bin — Enlazar boot.o + kernel.o ───────────────────────────────────
#   Combina boot.o y kernel.o en el ejecutable final kernel.bin.
#
#   -m elf_i386:
#     Emulación del enlazador: simula un sistema i386 (ELF32).
#     En sistemas de 64 bits, ld por defecto intenta generar ELF64.
#     Este flag fuerza ELF32, necesario para GRUB.
#
#   -T linker.ld:
#     Especifica el script de enlazado personalizado (linker.ld).
#     Sin -T, ld usaría su script por defecto, que asume un programa
#     de usuario con libc y colocaría el código en direcciones
#     incorrectas (normalmente 0x400000 para Linux).
#
#   kernel.bin:
#     ELF ejecutable final. Contiene:
#       - Cabecera ELF (punto de entrada, tabla de secciones, etc.)
#       - Cabecera Multiboot (GRUB la verifica)
#       - Código máquina del kernel (_start, kmain, clear_screen)
#       - Stack (en .bss, sin datos en disco)
#     GRUB cargará este archivo y saltará a _start.
kernel.bin: boot.o kernel.o
	$(LD) -m elf_i386 -T linker.ld boot.o kernel.o -o kernel.bin


# ── run — Ejecutar kernel en QEMU ────────────────────────────────────────────
#   Arranca el kernel dentro del emulador QEMU.
#
#   qemu-system-i386:
#     Emulador de PC completo para arquitectura x86 (32 bits).
#     Emula: CPU (i386), RAM, BIOS, discos, teclado, pantalla VGA, etc.
#
#   -kernel kernel.bin:
#     Le dice a QEMU que cargue kernel.bin como un kernel Multiboot.
#     QEMU tiene un cargador Multiboot incorporado (como GRUB),
#     así que no hace falta instalar GRUB realmente.
#     QEMU:
#       1. Inicializa la máquina virtual.
#       2. Ejecuta su BIOS emulada.
#       3. El BIOS carga el loader Multiboot interno de QEMU.
#       4. El loader carga kernel.bin y salta a _start.
#
#   make run = compilar (si es necesario) + ejecutar en QEMU.
run: kernel.bin
	qemu-system-i386 -kernel kernel.bin


# ── clean — Limpiar archivos generados ───────────────────────────────────────
#   Elimina todos los archivos objeto (.o) y el binario (.bin),
#   dejando solo el código fuente.
#
#   Útil para:
#     - Reconstruir desde cero (make clean && make).
#     - Evitar artefactos de compilaciones anteriores.
#     - Limpiar antes de commit (los .o y .bin no deben ir al repo).
clean:
	rm -f *.o *.bin
