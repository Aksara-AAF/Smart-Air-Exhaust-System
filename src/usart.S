#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global usart_init
.global usart_send_char
.global usart_send_string
.global usart_send_number
.global usart_send_newline


usart_init:
    ; Set baud rate to 9600
    ldi     r16, hi8(UBRR_9600)
    sts     UBRR0H, r16
    ldi     r16, lo8(UBRR_9600)
    sts     UBRR0L, r16

    ; Enable TX dan RX
    ldi     r16, (1 << TXEN0) | (1 << RXEN0)
    sts     UCSR0B, r16

    ; 8 data bit, 1 stop bit, no parity
    ldi     r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts     UCSR0C, r16

    ret


usart_send_char:
    ; Wait for data register empty
usart_send_char_wait:
    lds     r16, UCSR0A
    sbrs    r16, UDRE0
    rjmp    usart_send_char_wait

    ; Send character
    sts     UDR0, r24
    ret


usart_send_string:
    lpm     r24, Z+ ; Load byte from Flash, increment Z
    cpi     r24, 0  ; Check null terminator
    breq    usart_send_string_done
    rcall   usart_send_char
    rjmp    usart_send_string
usart_send_string_done:
    ret


usart_send_newline:
    ldi     r24, '\r'
    rcall   usart_send_char
    ldi     r24, '\n'
    rcall   usart_send_char
    ret


usart_send_number:
    ; Store r25:r24 to r19:r18 (number that will be divided)
    mov     r18, r24
    mov     r19, r25

    ; Count total digit and push to stack
    ldi     r20, 0              ; Count total digit

    ; Special case: number = 0
    cpi     r18, 0
    cpc     r19, r1             ; r1 is always 0 after RESET
    brne    usart_num_loop
    ldi     r24, '0'
    rcall   usart_send_char
    ret

usart_num_loop:
    ; Check if number = 0
    cpi     r18, 0
    cpc     r19, r1
    breq    usart_num_print

    ; Divide r19:r18 by 10 using repeated subtraction
    rcall   divide_by_10        ; Result in r19:r18, remainder in r16

    ; Push remainder digit to stack
    push    r16
    inc     r20                 ; Increment digit count
    rjmp    usart_num_loop

usart_num_print:
    ; Pop digit from stack and send as ASCII
    cpi     r20, 0
    breq    usart_num_done
    pop     r16
    ldi     r24, '0'
    add     r24, r16            ; '0' + digit
    rcall   usart_send_char
    dec     r20
    rjmp    usart_num_print

usart_num_done:
    ret

divide_by_10:
    ldi     r16, 0              ; Initialize remainder
    ldi     r17, 16             ; 16-bit loop
divide_by_10_loop:
    ; Shift r16:r19:r18 left 1 bit (remainder:high:low)
    lsl     r18
    rol     r19
    rol     r16

    ; Check if r16 >= 10
    cpi     r16, 10
    brcs    divide_by_10_no_sub ; If r16 < 10, no need to subtract

    subi    r16, 10             ; Subtract 10 from remainder
    ori     r18, 0x01           ; Set bit0 of quotient

divide_by_10_no_sub:
    dec     r17
    brne    divide_by_10_loop

    ret
