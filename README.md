# KFS-1

Kernel mínimo para i386 escrito en NASM y C. GRUB carga el kernel mediante
Multiboot, el código de arranque prepara una pila y `kmain` escribe `42`
directamente en la memoria de texto VGA.

## Requisitos

En Arch Linux:

```bash
sudo pacman -Syu gcc nasm make qemu-system-x86 grub libisoburn mtools
```

Herramientas utilizadas:

- `nasm`: ensambla `boot.asm` como ELF32.
- `gcc` y `ld`: compilan y enlazan el kernel i386.
- `grub-file`: valida la cabecera Multiboot.
- `grub-mkrescue` y `xorriso`: generan la ISO con GRUB.
- `qemu-system-i386`: ejecuta el kernel o la ISO.

Se puede comprobar la instalación con:

```bash
command -v nasm gcc ld grub-file grub-mkrescue xorriso qemu-system-i386
```

## Compilación

```bash
make
```

El resultado es `kernel.bin`, un ejecutable ELF de 32 bits. Para reconstruir
desde cero:

```bash
make clean && make
```

El kernel se compila en modo freestanding, sin enlazar la biblioteca estándar
ni el entorno de ejecución del sistema anfitrión.

## Validación Multiboot

Antes de crear la imagen, comprueba que GRUB reconoce el kernel:

```bash
grub-file --is-x86-multiboot kernel.bin
```

El comando no imprime nada cuando la validación es correcta. Su código de
salida se puede consultar con `echo $?`: `0` significa que el kernel es
Multiboot válido.

## Generar La ISO

El repositorio incluye `grub.cfg`. El Makefile crea el árbol temporal `iso/`,
valida el kernel, genera una imagen BIOS/i386 mínima y comprueba su tamaño:

```bash
make iso
```

El target ejecuta `grub-mkrescue` únicamente con los módulos necesarios:

```bash
grub-mkrescue \
  --directory=/usr/lib/grub/i386-pc \
  --install-modules="biosdisk iso9660 normal configfile multiboot" \
  --modules="biosdisk iso9660 normal configfile multiboot" \
  --locales="" --fonts="" --themes="" \
  --compress=xz \
  -o kfs.iso iso
```

La estructura resultante usada por GRUB es:

```text
iso/
└── boot/
    ├── kernel.bin
    └── grub/
        └── grub.cfg
```

## Ejecutar

Arranque real desde la ISO mediante GRUB:

```bash
make run-iso
```

La pantalla debe quedar limpia y mostrar `42` en la esquina superior
izquierda.

También existe un arranque rápido para desarrollo:

```bash
make run
```

`make run` usa `qemu-system-i386 -kernel kernel.bin`. Este modo emplea el
cargador Multiboot integrado de QEMU y no demuestra que la ISO arranque
correctamente con GRUB.

## Límite De Tamaño

El subject fija un máximo de 10 MB para la entrega y su imagen. Comprueba el
tamaño de la ISO con:

```bash
stat -c '%n: %s bytes' kfs.iso
test "$(stat -c %s kfs.iso)" -lt 10000000
```

El segundo comando termina correctamente solo si `kfs.iso` ocupa menos de
10 MB. `make iso` ejecuta esta comprobación automáticamente.

## Flujo De Arranque

1. GRUB encuentra la cabecera Multiboot y carga `kernel.bin`.
2. El linker sitúa el kernel a partir de `0x100000` y usa `_start` como entrada.
3. `boot.asm` prepara una pila de 16 KiB y llama a `kmain`.
4. `kernel.c` limpia las 80 x 25 celdas VGA y escribe `42` en `0xB8000`.
5. El kernel permanece en un bucle infinito.

## Archivos Principales

- `boot.asm`: cabecera Multiboot, pila y punto de entrada `_start`.
- `kernel.c`: acceso a VGA y función `kmain`.
- `linker.ld`: layout del ELF y dirección de carga a 1 MiB.
- `grub.cfg`: entrada de GRUB que carga el kernel mediante Multiboot.
- `Makefile`: compilación, validación, generación de ISO y ejecución.
- `kfs.iso`: imagen GRUB generada para la entrega.
- `en.subject.pdf`: requisitos originales del proyecto.
