/*
 * ============================================================================
 *  linker.ld — Script de enlazado para KFS-1
 * ============================================================================
 *
 *  ¿Qué hace un linker script?
 *    Es un archivo de configuración para el enlazador (ld) que define:
 *      - El punto de entrada del programa (dónde empieza la ejecución).
 *      - La dirección base donde se cargará el kernel en memoria.
 *      - Cómo se organizan las secciones (código, datos, BSS) en el binario
 *        final.
 *      - El orden de las secciones en el archivo ELF resultante.
 *
 *  Sin un linker script, ld usaría valores por defecto que asumen un
 *  programa de usuario con biblioteca estándar de C (crt0, etc.), lo que
 *  NO funciona para un kernel.
 *
 *  Formato:  lenguaje de scripts de GNU ld (LD Script Language).
 *  Target:   x86 (32 bits), ELF32, freestanding (sin SO subyacente).
 * ============================================================================
 */


/*
 * ============================================================================
 *  ENTRY(_start)
 * ============================================================================
 *
 *  Declara el punto de entrada del kernel: _start.
 *
 *  ¿Qué significa?
 *    Le dice a ld que cuando el binario se cargue en memoria, la primera
 *    instrucción a ejecutar es la etiqueta _start, definida en boot.asm.
 *
 *  ¿Qué pasaría sin esto?
 *    ld usaría el entry point por defecto (normalmente _start ya es el
 *    default, pero se define explícitamente para claridad y seguridad).
 *
 *  ¿Cómo se relaciona con GRUB?
 *    1. GRUB carga el binario en 1M.
 *    2. GRUB lee la cabecera ELF para encontrar el punto de entrada.
 *    3. GRUB salta a _start (en boot.asm).
 *
 *  Convención: _start es el nombre tradicional del entry point en
 *  sistemas sin biblioteca estándar. En programas con libc, suele ser
 *  proporcionado por crt0.
 */
ENTRY(_start)


/*
 * ============================================================================
 *  SECTIONS — Definición del layout en memoria
 * ============================================================================
 *
 *  La directiva SECTIONS agrupa todas las secciones del binario final y
 *  define dónde se coloca cada una en el espacio de direcciones.
 *
 *  Sintaxis general:
 *    SECTIONS {
 *        . = <dirección_base>;    ← contador de posición (location counter)
 *        .<nombre_sección> : {
 *            <archivos_objeto>(<secciones>)
 *        }
 *    }
 *
 *  El contador de posición (.) representa la dirección actual dentro
 *  del espacio de memoria del programa. Se puede asignar y reasignar
 *  para controlar dónde se ubica cada sección.
 */
SECTIONS
{
    /*
     * ======================================================================
     *  . = 1M;
     *
     *  Coloca el contador de posición en 1 MB (0x100000).
     *
     *  ¿Por qué 1 MB?
     *    La memoria entre 0x00000000 y 0x000FFFFF (primer MB) está
     *    mayormente ocupada por:
     *
     *      0x00000000 - 0x000003FF  → IVT (Interrupt Vector Table)
     *      0x00000400 - 0x000004FF  → BDA (BIOS Data Area)
     *      0x00007C00 - 0x00007DFF  → Boot sector (carga inicial)
     *      0x00007E00 - 0x0007FFFF  → Usado por el bootloader
     *      0x0009FC00 - 0x0009FFFF  → EBDA (Extended BIOS Data Area)
     *      0x000A0000 - 0x000BFFFF  → VGA / memoria de video
     *      0x000C0000 - 0x000FFFFF  → ROMs de dispositivos (BIOS, VGA, etc.)
     *
     *    El estándar Multiboot recomienda cargar el kernel en o por encima
     *    de 1 MB, ya que esa zona está garantizada como libre.
     *
     *    Además, 1 MB = 0x100000 es la dirección tradicional para kernels
     *    en x86 (Linux también carga aquí).
     * ======================================================================
     */
    . = 1M;

    /*
     * ======================================================================
     *  .text : { *(.multiboot) *(.text) }
     *
     *  Sección de código ejecutable (read-only).
     *
     *  Orden interno:
     *    1. *(.multiboot) — Primero la cabecera Multiboot.
     *       - GRUB necesita encontrarla en los primeros 8 KB del binario.
     *       - Por eso va PRIMERO en la sección .text.
     *       - Contiene: magic 0x1BADB002, flags 0x0, checksum.
     *       - Definida en boot.asm como:  section .multiboot
     *
     *    2. *(.text)      — Luego el código ejecutable del kernel.
     *       - Código assembly: _start, hang (boot.asm)
     *       - Código C compilado: kmain(), clear_screen() (kernel.c)
     *
     *  El símbolo comodín (*) significa "todos los archivos objeto".
     *  La sintaxis es:
     *    archivo(sección)  →  *(.text)  = "de todos los .o, toma .text"
     *
     *  Propiedades de .text:
     *    - Solo lectura (el código no se modifica en ejecución).
     *    - Executable (la CPU lee instrucciones de aquí).
     *    - Compartido en sistemas con memoria virtual (no aplica aquí).
     * ======================================================================
     */
    .text : {
        *(.multiboot)
        *(.text)
    }

    /*
     * ======================================================================
     *  .data : { *(.data) }
     *
     *  Sección de datos inicializados (lectura/escritura).
     *
     *  Contiene:
     *    - Variables globales/estáticas con valor inicial distinto de cero.
     *    - Constantes (strings literales, etc.) — aunque las constantes
     *      suelen ir en .rodata (read-only data).
     *
     *  En este kernel no hay variables de este tipo aún, pero la sección
     *  está definida para cuando se agreguen.
     *
     *  Diferencia con .text:
     *    .text es solo-lectura + ejecutable.
     *    .data es lectura/escritura, NO ejecutable.
     *
     *  En sistemas con MMU, .data tendría permisos rw- (sin ejecución).
     * ======================================================================
     */
    .data : {
        *(.data)
    }

    /*
     * ======================================================================
     *  .bss : { *(COMMON) *(.bss) }
     *
     *  Sección de datos no inicializados (lectura/escritura).
     *
     *  ¿Qué la hace especial?
     *    En el archivo ELF (kernel.bin), .bss NO ocupa espacio en disco.
     *    Solo se definen su dirección y tamaño. El cargador (GRUB) debe
     *    reservar la memoria y llenarla con ceros al cargar el kernel.
     *
     *  ¿Qué contiene?
     *    - Variables globales/estáticas SIN inicializar o inicializadas a 0.
     *    - En este kernel: el stack de 16 KB (stack_bottom..stack_top en
     *      boot.asm, section .bss).
     *
     *  *(COMMON):
     *    COMMON es una sección especial usada por compiladores antiguos
     *    (como Fortran) y por variables globales no inicializadas en C
     *    con ciertos modelos de memoria. En GCC moderno, las variables
     *    no inicializadas van directamente a .bss, pero incluimos COMMON
     *    por compatibilidad.
     *
     *  El stack:
     *    Aunque el stack se define en boot.asm con resb 16384, el linker
     *    lo coloca en .bss. GRUB lo carga y lo pone a cero. Luego _start
     *    configura ESP = stack_top, y el stack comienza a usarse.
     *
     *  Ejemplo visual de cómo GRUB carga .bss:
     *
     *    Archivo kernel.bin en disco:      En memoria RAM:
     *    ┌─────────────────────┐           ┌─────────────────────┐
     *    │ .multiboot (16 B)   │           │ .multiboot          │
     *    │ .text     (X bytes) │   GRUB    │ .text               │
     *    │ .data     (Y bytes) │  ──────→  │ .data               │
     *    │ .bss      (0 B)  ←─┘│ Sin datos │ .bss (16 KB) ←──────│─→ todo ceros
     *    └─────────────────────┘           └─────────────────────┘
     *                                          GRUB asigna y llena con 0
     * ======================================================================
     */
    .bss : {
        *(COMMON)
        *(.bss)
    }
}
