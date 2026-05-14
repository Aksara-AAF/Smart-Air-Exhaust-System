#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global dht11_init
.global dht11_read
.global dht11_humidity
.global dht11_temperature

.section .bss
dht11_humidity:    .skip 1
dht11_temperature: .skip 1
dht_buffer:        .skip 5

.section .text

; Set awal pin DHT11 sebagai INPUT dengan Pull-up
dht11_init:
    cbi DDRD, DHT11_PIN ; Set sebagai INPUT
    sbi PORTD, DHT11_PIN    
    ret

dht11_read:         
    ; Start Signal
    sbi DDRD, DHT11_PIN      ; Set OUTPUT
    cbi PORTD, DHT11_PIN     
    rcall delay_18ms         
    
    sbi PORTD, DHT11_PIN   
    cbi DDRD, DHT11_PIN      ; Set INPUT
    rcall delay_30us
    
    ; Response Signal
    sbic PIND, DHT11_PIN
    rjmp dht_error          
    
wait_high:
    sbis PIND, DHT11_PIN
    rjmp wait_high
    
wait_low_again:
    sbic PIND, DHT11_PIN
    rjmp wait_low_again

    ; Read 40 bit data
    ldi r26, lo8(dht_buffer)
    ldi r27, hi8(dht_buffer)
    ldi r21, 5  ; 5 Byte              

read_byte_loop:
    ldi r22, 8  ; 8 Bit              
    clr r23  ; Buffer 1 byte                 

read_bit_loop:
wait_high_bit:
    sbis PIND, DHT11_PIN
    rjmp wait_high_bit

    clr r24 ; Counter mikrodetik                  
count_high_time:
    sbis PIND, DHT11_PIN ; Jika LOW, bit selesai     
    rjmp evaluate_bit
    inc r24
    NOP2                      
    NOP4                  
    nop
    nop
    rjmp count_high_time

evaluate_bit:
    lsl r23
    cpi r24, 40   ; Jika durasi > 40us, maka bit '1'            
    brlo bit_is_zero
    ori r23, 1  ; Set LSB jadi 1              
bit_is_zero:
    dec r22
    brne read_bit_loop

    st X+, r23
    dec r21
    brne read_byte_loop

    ; Validasi Checksum and Save to global variable
    lds r16, dht_buffer  ; Hum Int     
    lds r17, dht_buffer+1  ; Hum Dec   
    lds r18, dht_buffer+2  ; Temp Int   
    lds r19, dht_buffer+3  ; Temp Dec   
    
    add r16, r17
    add r16, r18
    add r16, r19
    
    lds r17, dht_buffer+4  ; Checksum   
    cp r16, r17
    brne dht_error            
    
    ; Simpan data ke variabel eksternal yang di request main.S
    lds r16, dht_buffer       
    sts dht11_humidity, r16
    lds r16, dht_buffer+2     
    sts dht11_temperature, r16

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