/*
 * ============================================================================
 *  KFS-1 — kernel.c
 *  Núcleo mínimo del sistema operativo KFS-1.
 *
 *  Este archivo contiene la lógica principal del kernel en C. Se ejecuta
 *  después de que el bootloader (GRUB) y el código assembly en boot.asm
 *  hayan preparado el terreno mínimo: modo protegido (32 bits), stack
 *  configurado, y CPU en ring 0.
 *
 *  La función kmain() es llamada desde boot.asm y nunca debe retornar.
 * ============================================================================
 */

/*
 *  stdint.h — cabecera del compilador (GCC) que define tipos enteros
 *  de ancho fijo: uint8_t, uint16_t, uint32_t, etc.
 *  Se usa uint16_t porque cada "celda" de la pantalla VGA en modo texto
 *  ocupa exactamente 16 bits (2 bytes): 1 byte de carácter + 1 byte de
 *  atributos (color de frente, fondo, parpadeo).
 */
#include <stdint.h>

/*
 * ============================================================================
 *  clear_screen — Limpia la pantalla de texto VGA
 * ============================================================================
 *
 *  ¿Qué hace?
 *    Rellena toda la memoria de vídeo VGA (modo texto, 80×25 caracteres)
 *    con espacios en blanco con atributo gris claro sobre fondo negro (0x07).
 *
 *  ¿Por qué 0xB8000?
 *    Es la dirección base de la memoria de vídeo VGA en modo texto.
 *    En modo protegido sin paginación, esta dirección física se mapea
 *    directamente en el espacio de direcciones. Para un kernel mínimalista
 *    que corre sin MMU, escribir aquí = dibujar en pantalla.
 *
 *  ¿Por qué volatile?
 *    Le decimos al compilador que la memoria en 0xB8000 puede cambiar
 *    por razones ajenas al flujo del programa (en este caso, el hardware
 *    de vídeo la lee constantemente para refrescar la pantalla). Sin
 *    volatile, el optimizador podría eliminar escrituras que considera
 *    "innecesarias".
 *
 *  ¿Por qué 80 * 25?
 *    El modo texto VGA estándar tiene 80 columnas × 25 filas = 2000 celdas.
 */
void clear_screen()
{
    /*
     *  Declaramos un puntero a uint16_t apuntando a 0xB8000.
     *  Cada uint16_t representa una celda carácter/atributo:
     *
     *    Bits 0-7   → carácter ASCII (ej. 'A' = 0x41)
     *    Bits 8-11  → color de frente (foreground)
     *    Bits 12-14 → color de fondo (background)
     *    Bit 15     → parpadeo (blink)
     *
     *   0x07 = 0b00000111:
     *     - frente: gris claro (7)
     *     - fondo:  negro (0)
     *     - sin parpadeo
     */
    volatile uint16_t* video = (uint16_t*)0xB8000;

    /*
     *  Iteramos por las 2000 posiciones e insertamos un espacio en blanco
     *  con el atributo por defecto (0x07). El espacio (0x20) elimina
     *  cualquier carácter residual que haya dejado GRUB o el BIOS.
     */
    for (int i = 0; i < 80 * 25; i++)
    {
        /*
         *  Construimos el uint16_t:
         *    (0x07 << 8) | ' '
         *  = 0x0700 | 0x20
         *  = 0x0720
         *
         *  Donde:
         *    0x07 → atributo (gris/negro) en el byte alto
         *    ' '  → carácter espacio (0x20) en el byte bajo
         */
        video[i] = (0x07 << 8) | ' ';
    }
}

/*
 * ============================================================================
 *  kmain — Punto de entrada del kernel en C
 * ============================================================================
 *
 *  Llamada desde _start (boot.asm) justo después de:
 *    1. Configurar el stack pointer (ESP = stack_top).
 *    2. Pasar a modo protegido (ya lo hace GRUB).
 *
 *  Convenciones de llamada:
 *    - Al ser llamada desde assembly puro (sin CRT), kmain NO recibe
 *      argc/argv ni ningún parámetro estándar.
 *    - El stack ya está configurado y es funcional, por lo que podemos
 *      declarar variables locales, llamar a otras funciones, etc.
 *
 *  IMPORTANTE:
 *    kmain NUNCA debe retornar. Si lo hiciera, la CPU volvería a _start
 *    justo después del 'call kmain', donde nos espera un bucle infinito
 *    (hang: jmp hang) como medida de seguridad. Pero en teoría, un kernel
 *    que retorna deja el sistema en un estado indefinido.
 */
void kmain(void)
{
    /*
     *  Paso 1: Limpiar la pantalla.
     *  Queremos empezar con una terminal limpia, sin el mensaje de GRUB
     *  ni ningún resto del boot.
     */
    clear_screen();

    /*
     *  Paso 2: Obtener puntero a la memoria de vídeo VGA.
     *  Misma lógica que en clear_screen(): apuntamos a 0xB8000 para
     *  leer/escribir directamente el framebuffer de texto.
     */
    volatile uint16_t* video = (uint16_t*)0xB8000;

    /*
     *  Paso 3: Escribir "42" en la esquina superior izquierda.
     *
     *  video[0] → primera celda (columna 0, fila 0)
     *  video[1] → segunda celda (columna 1, fila 0)
     *
     *  Cada celda:
     *    video[0] = (0x07 << 8) | '4'
     *             = 0x0734
     *    - Carácter: '4' (0x34)
     *    - Atributo: 0x07 (gris claro sobre negro)
     *
     *  Resultado visual en pantalla:
     *    ┌───┬───┬───┬───┬───┐
     *    │ 4 │ 2 │   │   │   │ ...
     *    ├───┼───┼───┼───┼───┤
     *    │   │   │   │   │   │ ...
     *    └───┴───┴───┴───┴───┘
     *
     *  ¿Por qué '4' y '2'?
     *    Es el clásico "42" — la respuesta a la vida, el universo y todo
     *    lo demás (Douglas Adams, La Guía del Autoestopista Galáctico).
     *    Una tradición entre kernels didácticos mostrar "42" como primer
     *    mensaje.
     */
    video[0] = (0x07 << 8) | '4';
    video[1] = (0x07 << 8) | '2';

    /*
     *  Bucle infinito.
     *
     *  El kernel ha completado su trabajo inicial y no tiene más tareas
     *  que hacer (en este kernel mínimo no hay scheduler, interrupciones,
     *  ni procesos de usuario).
     *
     *  Este bucle evita que la CPU ejecute memoria no inicializada o
     *  instrucciones basura después de kmain, lo que causaría un crash
     *  o comportamiento impredecible.
     *
     *  while (1) genera algo como:
     *    jmp $     ← salto incondicional a sí mismo
     *
     *  En un kernel real, aquí entraría el planificador de procesos o
     *  un bucle principal de eventos.
     */
    while (1);
}
