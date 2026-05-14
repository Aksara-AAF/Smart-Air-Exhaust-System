#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global timer1_init
.global timer2_pwm_init
.global fan_set_speed
.global update_fan_hybrid

.extern gas_8bit
.extern dht11_temperature

.section .text

; Inisialisasi Timer1 Mode CTC 1 detik
timer1_init:
    ldi r16, hi8(TIMER1_1S)
    sts OCR1AH, r16
    ldi r16, lo8(TIMER1_1S)
    sts OCR1AL, r16
    
    clr r16
    sts TCCR1A, r16
    
    ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)
    sts TCCR1B, r16
    
    lds r16, TIMSK1
    ori r16, (1 << OCIE1A)
    sts TIMSK1, r16
    ret

; Inisialisasi Timer2 Mode Fast PWM untuk Fan
timer2_pwm_init:
    sbi DDRB, FAN_PWM
    
    ldi r16, (1 << COM2A1) | (1 << WGM21) | (1 << WGM20)
    sts TCCR2A, r16
    
    ldi r16, (1 << CS22)
    sts TCCR2B, r16
    
    ldi r16, PWM_OFF
    sts OCR2A, r16
    ret

; Mengubah kecepatan Fan (Duty Cycle)
fan_set_speed:
    sts OCR2A, r24
    ret

; Kalkulasi PWM hybrid (Gas + Suhu) 
update_fan_hybrid:
    lds r16, gas_8bit
    lds r17, dht11_temperature

    ; Cek apakah suhu di atas batas normal
    cpi r17, TEMP_THRESHOLD
    brlo apply_pwm
    breq apply_pwm

    ; Kalkulasi temp_bonus = (suhu - TEMP_THRESHOLD) * 4
    subi r17, TEMP_THRESHOLD
    lsl r17
    lsl r17

    ; Tambahkan bonus suhu ke kecepatan kipas
    add r16, r17
    brcc set_pwm_value

    ; Clamp ke batas maksimum jika overflow
    ldi r16, PWM_MAX

set_pwm_value:
apply_pwm:
    mov r24, r16
    rcall fan_set_speed
    ret