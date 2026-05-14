#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global adc_init
.global adc_read
.global adc_read_gas
.global adc_read_pot
.global adc_to_8bit

; Inisialisasi ADC dengan referensi AVCC dan prescaler 128
adc_init:
    ; Set ADMUX: AVCC sebagai Vref, right-adjusted, channel 0
    ldi r16, (1 << REFS0)
    sts ADMUX, r16

    ; Enable ADC dengan prescaler 128 (ADC clock = 125kHz)
    ldi r16, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
    sts ADCSRA, r16

    ; Konversi dummy pertama untuk stabilisasi ADC
    lds r16, ADCSRA
    ori r16, (1 << ADSC)
    sts ADCSRA, r16
adc_init_wait_dummy:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_init_wait_dummy

    ret

; Baca ADC dari channel yang dipilih, hasilnya 10-bit di r25:r24
adc_read:
    ; Set channel di ADMUX, pertahankan AVCC reference
    andi r24, 0x0F
    ori r24, (1 << REFS0)
    sts ADMUX, r24

    ; Tunggu MUX stabil
    nop
    nop

    ; Mulai konversi
    lds r16, ADCSRA
    ori r16, (1 << ADSC)
    sts ADCSRA, r16

    ; Tunggu konversi selesai
adc_read_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_read_wait

    ; Baca hasil (ADCL harus dibaca sebelum ADCH)
    lds r24, ADCL
    lds r25, ADCH

    ret

; Baca sensor gas MQ-135 pada channel 0
adc_read_gas:
    ldi r24, ADC_GAS
    rcall adc_read
    ret

; Baca potensiometer threshold pada channel 1
adc_read_pot:
    ldi r24, ADC_POT
    rcall adc_read
    ret

; Konversi nilai 10-bit ke 8-bit dengan shift kanan 2x
adc_to_8bit:
    lsr r25
    ror r24
    lsr r25
    ror r24
    ret
