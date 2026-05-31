# KFS-1 — Kernel From Scratch

KFS-1 es un **kernel mínimo para x86 (32 bits)** desde cero, compatible con el estándar **Multiboot** y arrancable con **GRUB**. Está escrito en **NASM assembly** y **C** con `gcc` en modo *freestanding* (sin biblioteca estándar de C).

Su propósito es didáctico: muestra los componentes mínimos indispensables para que un kernel bootee, escriba en pantalla y se mantenga en ejecución.

---

## Arquitectura del proyecto

```
kfs-1/
├── boot.asm       # Punto de entrada en assembly (Multiboot + stack + call kmain)
├── kernel.c       # Lógica del kernel en C (pantalla VGA, bucle infinito)
├── linker.ld      # Script de enlazado (define layout en memoria)
├── Makefile       # Compilación, enlazado y ejecución en QEMU
└── README.md      # Este archivo
```

---

## Proceso de arranque (paso a paso)

```
ENCENDIDO DEL PC
       │
       ▼
     BIOS/UEFI
  (inicializa hardware)
       │
       ▼
     GRUB (bootloader)
  (lee kernel.bin del disco)
       │
       ▼
  ┌─────────────────────────────────────────────────────────┐
  │ 1. GRUB carga kernel.bin en la dirección física 1M      │
  │ 2. GRUB verifica la cabecera Multiboot                  │
  │ 3. GRUB pasa a modo protegido (32 bits, ring 0)         │
  │ 4. GRUB salta a _start (entry point del linker)          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  ┌─────────────────────────────────────────────────────────┐
  │                boot.asm  (_start)                        │
  │                                                         │
  │  1. Configura el stack pointer (ESP = stack_top)         │
  │  2. Llama a kmain()                                     │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  ┌─────────────────────────────────────────────────────────┐
  │                kernel.c  (kmain)                         │
  │                                                         │
  │  1. Limpia la pantalla VGA (clear_screen)               │
  │  2. Escribe "42" en la esquina superior izquierda       │
  │  3. Bucle infinito (while(1))                           │
  └─────────────────────────────────────────────────────────┘
```

### 1. BIOS → GRUB

Al encender, la BIOS realiza el POST, inicializa dispositivos y busca un bootloader en el disco. GRUB (Grand Unified Bootloader) toma el control, carga `kernel.bin` en memoria y verifica que tenga una **cabecera Multiboot** válida.

### 2. Cabecera Multiboot (`boot.asm`)

GRUB busca en el binario tres valores consecutivos de 32 bits:

| Campo     | Valor        | Descripción                              |
|-----------|-------------|------------------------------------------|
| Magic     | `0x1BADB002`| Identifica el binario como Multiboot     |
| Flags     | `0x0`       | Sin opciones especiales                  |
| Checksum  | `-(magic)`  | Verifica integridad: magic + flags + checksum = 0 |

Estos valores están en la sección `.multiboot` del assembly, alineados a 4 bytes.

### 3. Carga en memoria (`linker.ld`)

El linker script coloca el kernel en la dirección `0x100000` (1 MB). Esta dirección es convencional para kernels Multiboot porque deja suficiente espacio para:

- **0x00000000 – 0x000FFFFF** (1.er MB): Reservado para BIOS, IVT, BDA, EBDA, etc.
- **0x00100000 en adelante** (1 MB+): Libre para el kernel.

Organización de secciones en memoria:

```
1 MB (0x100000)
  ├── .multiboot  ← Cabecera Multiboot (GRUB la lee)
  ├── .text       ← Código ejecutable (assembly + C compilado)
  ├── .data       ← Datos inicializados
  └── .bss        ← Datos no inicializados (stack incluido)
```

### 4. Configuración del stack (`boot.asm`)

Antes de llamar a código C, el assembly configura el **stack pointer** (`ESP`). El stack se reserva en `.bss` con 16 KB de espacio:

```
stack_bottom  ┌────────────────────┐  dirección baja
              │                    │
              │  16 KB reservados  │  resb 16384
              │                    │
stack_top     └────────────────────┘  dirección alta  ← ESP apunta aquí
```

El stack crece **hacia direcciones decrecientes** (de `stack_top` hacia `stack_bottom`). Sin un stack válido, instrucciones como `call`, `ret` y cualquier variable local en C provocarían un crash.

### 5. Llamada a `kmain`

`_start` ejecuta `call kmain`. La instrucción `call`:
1. Pushea la dirección de retorno (`hang`) en el stack.
2. Salta a la dirección de `kmain` (definida en `kernel.c` y resuelta por el linker).

`kmain` se ejecuta en **ring 0** (máximo privilegio) y tiene acceso completo a memoria, puertos de E/S e instrucciones privilegiadas de la CPU.

### 6. Escritura en pantalla VGA

El kernel escribe directamente en el **framebuffer de modo texto VGA** en la dirección física `0xB8000`. Cada celda de pantalla ocupa 16 bits:

```
Bit    15 14 13 12 11 10  9  8 │ 7  6  5  4  3  2  1  0
       │  fondo  │frente│ B │ │     carácter ASCII
       └─── byte de atributo ──┘ └─── byte de carácter ──
```

- **Byte bajo** (bits 0-7): carácter ASCII (ej. `'4'` = `0x34`)
- **Byte alto** (bits 8-15): atributo de color
  - Bits 8-11: color de frente (foreground)
  - Bits 12-14: color de fondo (background)
  - Bit 15: parpadeo (blink)

`0x07` = fondo negro (0), frente gris claro (7), sin parpadeo.

La pantalla en modo texto estándar es de **80 columnas × 25 filas** = 2000 celdas.

### 7. Bucle infinito

`kmain` termina con `while(1);` que el compilador traduce a `jmp $` (salto a sí mismo). Esto es necesario porque:

- No hay un sistema operativo al cual retornar.
- Si la CPU llegara más allá de `kmain`, ejecutaría instrucciones basura en memoria no inicializada.
- En un kernel real, aquí residiría el planificador de procesos o el bucle de interrupciones.

---

## Archivos del proyecto

### `boot.asm` — Punto de entrada en assembly

```
Secciones:
  .multiboot → Cabecera Multiboot (magic, flags, checksum)
  .bss       → Stack de 16 KB (stack_bottom, stack_top)
  .text      → _start: configura ESP, call kmain, hang

Símbolos:
  _start  → Entry point (global, visible al linker)
  kmain   → Externo (definido en kernel.c)
  hang    → Bucle infinito de respaldo (si kmain retorna)
```

### `kernel.c` — Núcleo en C

```
Funciones:
  clear_screen()
    → Rellena 0xB8000..0xB8F9F con espacios (atributo 0x07)
    → Borra cualquier residuo de GRUB/BIOS en pantalla

  kmain()
    → Llama a clear_screen()
    → Escribe '4' en video[0] y '2' en video[1]
    → while(1)
```

### `linker.ld` — Script de enlazado

```
ENTRY(_start)       → El punto de entrada es _start (assembly)
. = 1M              → Base de carga en 1 MB (0x100000)
Secciones:
  .text   → .multiboot primero, luego .text
  .data   → Datos inicializados
  .bss    → Datos no inicializados (COMMON + .bss)
```

### `Makefile` — Automatización

| Objetivo     | Comando                      | Descripción                      |
|-------------|------------------------------|----------------------------------|
| `all`       | `make`                       | Genera `kernel.bin`              |
| `kernel.bin`| `make kernel.bin`            | Compila y enlaza todo            |
| `run`       | `make run`                   | Ejecuta en QEMU                  |
| `clean`     | `make clean`                 | Elimina `.o` y `.bin`            |

Proceso de compilación:

```
boot.asm  ──nasm -f elf32──→ boot.o  ──┐
                                       ├──ld -m elf_i386 -T linker.ld──→ kernel.bin
kernel.c  ──gcc -m32 -ffreestanding──→ kernel.o  ──┘
```

---

## Dependencias

| Herramienta          | Rol                          | Instalación (Debian/Ubuntu)          |
|---------------------|------------------------------|--------------------------------------|
| `nasm`              | Ensamblador (assembly → .o)  | `sudo apt install nasm`              |
| `gcc`               | Compilador de C              | `sudo apt install gcc`               |
| `ld` (binutils)     | Enlazador (.o → .bin)        | `sudo apt install binutils`          |
| `qemu-system-i386` | Emulador de PC (para pruebas)| `sudo apt install qemu-system-x86`   |
| `make`              | Automatización de builds     | `sudo apt install make`              |

> **Nota**: Se necesita GCC con soporte para `-m32` (multilib). En sistemas de 64 bits: `sudo apt install gcc-multilib`.

---

## Compilación y ejecución

```bash
# Compilar todo
make

# Ejecutar en QEMU
make run

# Limpiar archivos objeto
make clean
```

Si todo funciona correctamente, QEMU mostrará una pantalla negra con `42` en la esquina superior izquierda.

---

## Consideraciones técnicas importantes

### Modo *freestanding* vs. *hosted*

El flag `-ffreestanding` de GCC indica que el código se ejecutará **sin biblioteca estándar de C**. Esto implica:

- No hay `libc` (sin `printf`, `malloc`, `exit`, etc.).
- No hay `crt0` (sin código de inicio/rutinas de inicialización estándar).
- No hay librerías del sistema.
- El entry point debe definirse manualmente.

Los flags `-nostdlib -nodefaultlibs` refuerzan esta restricción.

### Dirección `0xB8000`

Es la dirección base del **framebuffer de modo texto VGA** en memoria física. En modo protegido sin paginación (como en este kernel), el acceso es directo. Especificaciones:

- Rango: `0xB8000` – `0xB8F9F` (4000 bytes = 2000 celdas × 2 bytes)
- Cada celda: 2 bytes (carácter + atributo)
- Resolución: 80×25 caracteres

### `volatile` en C

El calificador `volatile` evita que el compilador optimice las escrituras a `0xB8000`. Sin él, GCC podría:
- Eliminar escrituras que considera redundantes.
- Reordenar o fusionar accesos.
El compilador no entiende que escribir en `0xB8000` tiene un **efecto secundario visible** (cambia la pantalla).

### Alineación del stack

El stack está alineado a 16 bytes (`align 16`), que es el estándar que espera la ABI de System V (GCC genera código que asume stack alineado a 16 bytes para instrucciones SSE como `movdqa`).

### Estándar Multiboot

El estándar Multiboot (definido por la Free Software Foundation) especifica cómo un bootloader debe cargar un kernel. Requisitos:

- Cabecera con magic number, flags y checksum en los primeros 8 KB del binario.
- Alineación a 4 bytes de la cabecera.
- Formato ELF32 (generado con `nasm -f elf32` y `ld -m elf_i386`).

---

## Posibles extensiones

Este kernel mínimo es un punto de partida. Algunas ideas para continuar:

| Área               | Descripción                                      |
|--------------------|--------------------------------------------------|
| **GDT**            | Configurar la Tabla de Descriptores Globales     |
| **IDT**            | Configurar la Tabla de Descriptores de Interrupción |
| **ISR / IRQ**      | Manejar interrupciones del teclado y reloj       |
| **Paginación**     | Habilitar memoria virtual (MMU)                  |
| **Terminal**       | Desplazar texto, colores, cursor                 |
| **Puerto serie**   | Salida por COM1 para debugging                   |
| **Shell**          | Mini consola de comandos                         |
| **A20 gate**       | Habilitar línea de dirección A20                 |

---

## Referencias

- [OSDev Wiki](https://wiki.osdev.org/) — Recurso principal para desarrollo de kernels
- [Multiboot Specification](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html) — Estándar Multiboot de GNU
- [VGA Text Mode (OSDev)](https://wiki.osdev.org/Text_UI) — Documentación del modo texto VGA
- [System V ABI](https://wiki.osdev.org/System_V_ABI) — Convención de llamada usada por GCC en x86
- *The Guía del Autoestopista Galáctico* — Douglas Adams (por el "42")

---

## Licencia

Este proyecto es código abierto. Consulta el archivo `LICENSE` si existe, o considéralo dominio público con fines educativos.
