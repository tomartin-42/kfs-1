#include <stdint.h>

void clear_screen()
{
    volatile uint16_t* video = (uint16_t*)0xB8000;

    for (int i = 0; i < 80 * 25; i++)
    {
        video[i] = (0x07 << 8) | ' '; // espacio en blanco
    }
}

void kmain(void)
{
    clear_screen();
    volatile uint16_t* video = (uint16_t*)0xB8000;

    video[0] = (0x07 << 8) | '4';
    video[1] = (0x07 << 8) | '2';


    while (1);
}
