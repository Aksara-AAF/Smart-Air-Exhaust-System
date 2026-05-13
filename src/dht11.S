#include <avr/io.h>

.equ DHT_PORT, PORTD
.equ DHT_DDR,  DDRD
.equ DHT_PIN,  PIND
.equ DHT_BIT,  4

.global dht11_read

.cseg
dht11_read:         ; Untuk mengirim start signal ke DHT11 & cek response
    ; PD4 sebagai OUTPUT
    sbi DHT_DDR, DHT_BIT
    
    cbi DHT_PORT, DHT_BIT ;Set Low
    rcall delay_18ms
    
    sbi DHT_PORT, DHT_BIT ;Set High
    cbi DHT_DDR, DHT_BIT
    rcall delay_30us
    
    ; Respon dari DHT11 
    sbic DHT_PIN, DHT_BIT
    rjmp dht_error          
    
wait_high:
    sbis DHT_PIN, DHT_BIT
    rjmp wait_high
    
wait_low_again:
    sbic DHT_PIN, DHT_BIT
    rjmp wait_low_again

dht_error:
    ret

delay_18ms:
    ldi r18, 23
d18_outer:
    ldi r19, 255
d18_inner:
    ldi r20, 16
d18_deep:
    dec r20
    brne d18_deep
    dec r19
    brne d18_inner
    dec r18
    brne d18_outer
    ret

delay_30us:
    ldi r18, 160
d30_loop:
    dec r18
    brne d30_loop
    ret