; =========================
; MULTIBOOT HEADER
; =========================

section .multiboot        ; Sección especial donde colocamos el header multiboot
                         ; GRUB buscará esta sección para saber si el kernel es válido

align 4                  ; Alinea los datos a 4 bytes (requisito del estándar multiboot)

dd 0x1BADB002           ; "magic number" → identifica el kernel como multiboot compatible

dd 0x0                  ; flags → opciones (0 = configuración básica sin extras)

dd -(0x1BADB002)        ; checksum → hace que:
                        ; magic + flags + checksum = 0
                        ; GRUB usa esto para verificar integridad


; =========================
; STACK (memoria para llamadas a función)
; =========================

section .bss            ; Sección de datos no inicializados (no ocupa espacio en el binario)

align 16                ; Alineación a 16 bytes (mejor práctica para stack)

stack_bottom:           ; Inicio del stack

resb 16384              ; Reserva 16 KB de memoria para el stack

stack_top:              ; Final del stack (aquí apuntará ESP)


; =========================
; CÓDIGO EJECUTABLE
; =========================

section .text           ; Sección de código

global _start           ; Hace visible _start al linker (entry point del kernel)

extern kmain            ; Declaramos que kmain está definido en C


; =========================
; ENTRY POINT
; =========================

_start:
    mov esp, stack_top  ; Inicializamos el stack pointer (CRÍTICO)
                        ; Sin esto, call/ret romperían el programa

    call kmain          ; Llamamos a la función principal en C
                        ; Internamente:
                        ; - guarda dirección de retorno en el stack
                        ; - salta a kmain


; =========================
; LOOP INFINITO (seguridad)
; =========================

hang:
    jmp hang            ; Bucle infinito para evitar ejecutar memoria basura
                        ; Si kmain termina, la CPU se queda aquí para siempre
