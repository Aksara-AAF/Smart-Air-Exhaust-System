#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global gpio_init
.global led_all_off
.global led_set_aman
.global led_set_waspada
.global led_set_bahaya
.global buzzer_on
.global buzzer_off
.global buzzer_beep

.section .text

; Set LED and buzzer pin as output
gpio_init:
    ; Set PB2, PB4, PB5 as LED output
    in      r16, DDRB
    ori     r16, (1 << LED_HIJAU) | (1 << LED_KUNING) | (1 << LED_MERAH)
    out     DDRB, r16

    ; Set PD5 as buzzer output
    in      r16, DDRD
    ori     r16, (1 << BUZZER_PIN)
    out     DDRD, r16

    ; Turn off all LED and buzzer when initializing
    rcall   led_all_off
    rcall   buzzer_off

    ret


led_all_off:
    in      r16, PORTB
    andi    r16, ~((1 << LED_HIJAU) | (1 << LED_KUNING) | (1 << LED_MERAH))
    out     PORTB, r16
    ret


; Turn on green LED, turn off the others
led_set_aman:
    rcall   led_all_off
    in      r16, PORTB
    ori     r16, (1 << LED_HIJAU)
    out     PORTB, r16
    ret


; Turn on yellow LED, turn off the others
led_set_waspada:
    rcall   led_all_off
    in      r16, PORTB
    ori     r16, (1 << LED_KUNING)
    out     PORTB, r16
    ret


; Turn on red LED, turn off the others
led_set_bahaya:
    rcall   led_all_off
    in      r16, PORTB
    ori     r16, (1 << LED_MERAH)
    out     PORTB, r16
    ret


buzzer_on:
    in      r16, PORTD
    andi    r16, ~(1 << BUZZER_PIN)
    out     PORTD, r16
    ret


buzzer_off:
    in      r16, PORTD
    ori     r16, (1 << BUZZER_PIN)
    out     PORTD, r16
    ret


buzzer_beep:
    ; Brief beep
    rcall   buzzer_on
    ; Delay 200ms
    ldi     r18, 200
buzzer_beep_outer:
    ldi     r17, 250
buzzer_beep_inner:
    nop
    nop
    dec     r17
    brne    buzzer_beep_inner
    dec     r18
    brne    buzzer_beep_outer
    rcall   buzzer_off
    ret
