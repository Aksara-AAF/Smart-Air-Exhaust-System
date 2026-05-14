#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global interrupt_init

.section .text

interrupt_init:
    ; Set PD2 as input
    in      r16, DDRD
    andi    r16, ~(1 << BTN_OVERRIDE)
    out     DDRD, r16

    ; Enable pull-up internal on PD2
    in      r16, PORTD
    ori     r16, (1 << BTN_OVERRIDE)
    out     PORTD, r16

    ; Set INT0: falling edge trigger
    lds     r16, EICRA
    andi    r16, 0xFC               ; Clear ISC01:ISC00
    ori     r16, (1 << ISC01)       ; ISC01=1, ISC00=0 -> falling edge
    sts     EICRA, r16

    ; Enable INT0 on EIMSK
    in      r16, EIMSK
    ori     r16, (1 << INT0)
    out     EIMSK, r16

    ret
