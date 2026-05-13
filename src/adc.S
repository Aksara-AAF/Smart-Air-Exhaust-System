#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global adc_init
.global adc_read

adc_init:
    ldi r16, (1 << REFS0)
    sts ADMUX, r16

    ldi r16, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
    sts ADCSRA, r16

    lds r16, ADCSRA
    ori r16, (1 << ADSC)
    sts ADCSRA, r16
adc_init_wait_dummy:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_init_wait_dummy

    ret

adc_read:
    andi r24, 0x0F
    ori r24, (1 << REFS0)
    sts ADMUX, r24

    nop
    nop

    lds r16, ADCSRA
    ori r16, (1 << ADSC)
    sts ADCSRA, r16

adc_read_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_read_wait

    lds r24, ADCL
    lds r25, ADCH

    ret
