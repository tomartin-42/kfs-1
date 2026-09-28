#include <stdint.h>

/* Cada celda VGA contiene un carácter y un atributo de color de 8 bits. */
void clear_screen()
{
    /* volatile conserva las escrituras realizadas directamente al hardware. */
    volatile uint16_t* video = (uint16_t*)0xB8000;

    /* Limpia las 80 x 25 celdas con gris claro sobre fondo negro. */
    for (int i = 0; i < 80 * 25; i++)
    {
        video[i] = (0x07 << 8) | ' ';
    }
}

/* Punto de entrada llamado desde boot.asm; no debe retornar. */
void kmain(void)
{
    clear_screen();

    volatile uint16_t* video = (uint16_t*)0xB8000;
    video[0] = (0x07 << 8) | '4';
    video[1] = (0x07 << 8) | '2';

    while (1);
}
