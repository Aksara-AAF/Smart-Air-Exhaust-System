#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.extern gpio_init
.extern adc_init
.extern adc_read
.extern timer1_init
.extern timer2_pwm_init
.extern fan_set_speed
.extern usart_init
.extern usart_send_char
.extern usart_send_string
.extern usart_send_number
.extern usart_send_newline
.extern i2c_init
.extern lcd_init
.extern lcd_clear
.extern lcd_set_cursor
.extern lcd_send_data
.extern lcd_print_string
.extern lcd_print_number
.extern interrupt_init
.extern eeprom_save_threshold
.extern eeprom_load_threshold
.extern dht11_init
.extern dht11_read
.extern dht11_humidity
.extern dht11_temperature
.extern led_all_off
.extern led_set_aman
.extern led_set_waspada
.extern led_set_bahaya
.extern buzzer_on
.extern buzzer_off
.extern buzzer_beep

.section .bss
gas_value_l: .skip 1
gas_value_h: .skip 1
gas_8bit: .skip 1
threshold_l: .skip 1
threshold_h: .skip 1
threshold_8bit: .skip 1
air_status: .skip 1
override_flag: .skip 1
timer1_flag: .skip 1

.section .progmem.data, "a", @progbits
str_init_ok: .asciz "Smart Exhaust OK\r\n"
str_lcd_init: .asciz "Smart Exhaust"

.section .text

.org 0x0000
    jmp RESET
.org 0x0002
    jmp ISR_INT0
.org 0x0004
    reti
.org 0x0006
    reti
.org 0x0008
    reti
.org 0x000A
    reti
.org 0x000C
    reti
.org 0x000E
    reti
.org 0x0010
    reti
.org 0x0012
    reti
.org 0x0014
    reti
.org 0x0016
    jmp ISR_TIMER1_COMPA

.org 0x0050

ISR_INT0:
    push r16
    in r16, SREG
    push r16
    lds r16, override_flag
    cpi r16, 0
    breq isr_int0_set_on
    clr r16
    sts override_flag, r16
    rjmp isr_int0_done
isr_int0_set_on:
    ldi r16, 1
    sts override_flag, r16
isr_int0_done:
    pop r16
    out SREG, r16
    pop r16
    reti

ISR_TIMER1_COMPA:
    push r16
    in r16, SREG
    push r16
    ldi r16, 1
    sts timer1_flag, r16
    pop r16
    out SREG, r16
    pop r16
    reti

RESET:
    ldi r16, hi8(RAMEND)
    out SPH, r16
    ldi r16, lo8(RAMEND)
    out SPL, r16

    clr r1
    clr r16
    sts gas_value_l, r16
    sts gas_value_h, r16
    sts gas_8bit, r16
    sts threshold_l, r16
    sts threshold_h, r16
    sts threshold_8bit, r16
    sts air_status, r16
    sts override_flag, r16
    sts timer1_flag, r16

    rcall gpio_init
    rcall adc_init
    rcall timer1_init
    rcall timer2_pwm_init
    rcall usart_init
    rcall i2c_init
    rcall lcd_init
    rcall dht11_init
    rcall interrupt_init

    sei

    ldi ZL, lo8(str_init_ok)
    ldi ZH, hi8(str_init_ok)
    rcall usart_send_string

    rcall lcd_clear
    ldi r24, 0
    ldi r22, 0
    rcall lcd_set_cursor
    ldi ZL, lo8(str_lcd_init)
    ldi ZH, hi8(str_lcd_init)
    rcall lcd_print_string

MAIN_LOOP:
    lds r16, timer1_flag
    cpi r16, 1
    brne MAIN_LOOP

    clr r16
    sts timer1_flag, r16

    rjmp MAIN_LOOP
