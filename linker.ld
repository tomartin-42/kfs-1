/* Punto de entrada definido en boot.asm. */
ENTRY(_start)

SECTIONS
{
    /* GRUB carga el kernel a partir de 1 MiB. */
    . = 1M;

    /* La cabecera Multiboot debe quedar al principio del ELF. */
    .text : {
        *(.multiboot)
        *(.text)
    }

    /* Datos globales inicializados. */
    .data : {
        *(.data)
    }

    /* Datos sin inicializar y la pila reservada en boot.asm. */
    .bss : {
        /* COMMON agrupa variables globales sin inicializar de objetos antiguos. */
        *(COMMON)
        *(.bss)
    }
}
