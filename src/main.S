#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.extern gpio_init
.extern adc_init
.extern adc_read
.extern adc_read_gas
.extern adc_read_pot
.extern adc_to_8bit
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
.extern update_fan_hybrid

; Variabel global di SRAM
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

; String konstan di Flash
.section .progmem.data, "a", @progbits
str_init_ok: .asciz "Smart Exhaust OK\r\n"
str_lcd_init: .asciz "Smart Exhaust"
str_aman:     .asciz "AMAN   "
str_waspada:  .asciz "WASPADA"
str_bahaya:   .asciz "BAHAYA "
str_lcd_g:    .asciz "G:"
str_lcd_t:    .asciz " T:"
str_lcd_c:    .asciz "C "
str_lcd_h:    .asciz "H:"
str_lcd_pct:  .asciz "%  "

.section .text

; Interrupt Vector Table
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

; ISR INT0: Toggle override_flag saat tombol ditekan
ISR_INT0:
    push r16
    in r16, SREG
    push r16
    ; Toggle flag (0 jadi 1, 1 jadi 0)
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
    ; Restore SREG dan r16
    pop r16
    out SREG, r16
    pop r16
    reti

; ISR Timer1: Set flag setiap 1 detik
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

; Entry point: inisialisasi stack dan semua modul
RESET:
    ; Inisialisasi stack pointer ke RAMEND
    ldi r16, hi8(RAMEND)
    out SPH, r16
    ldi r16, lo8(RAMEND)
    out SPL, r16

    ; Bersihkan semua variabel SRAM
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

    ; Inisialisasi semua modul
    rcall gpio_init
    rcall adc_init
    rcall timer1_init
    rcall timer2_pwm_init
    rcall usart_init
    rcall i2c_init
    rcall lcd_init
    rcall dht11_init
    rcall interrupt_init

    ; Load threshold dari EEPROM
    rcall eeprom_load_threshold
    sts threshold_l, r24
    sts threshold_h, r25
    rcall adc_to_8bit
    sts threshold_8bit, r24

    ; Aktifkan global interrupt
    sei

    ; Kirim pesan init ke serial monitor
    ldi ZL, lo8(str_init_ok)
    ldi ZH, hi8(str_init_ok)
    rcall usart_send_string

    ; Tampilkan nama sistem di LCD
    rcall lcd_clear
    ldi r24, 0
    ldi r22, 0
    rcall lcd_set_cursor
    ldi ZL, lo8(str_lcd_init)
    ldi ZH, hi8(str_lcd_init)
    rcall lcd_print_string

; Loop utama: tunggu flag Timer1 setiap 1 detik
MAIN_LOOP:
    lds r16, timer1_flag
    cpi r16, 1
    brne MAIN_LOOP

    ; Reset flag dan proses
    clr r16
    sts timer1_flag, r16

    ; Baca sensor gas MQ-135
    rcall adc_read_gas
    sts gas_value_l, r24
    sts gas_value_h, r25
    rcall adc_to_8bit
    sts gas_8bit, r24

    ; Baca potensiometer dan simpan threshold
    rcall adc_read_pot
    sts threshold_l, r24
    sts threshold_h, r25
    rcall eeprom_save_threshold
    lds r24, threshold_l
    lds r25, threshold_h
    rcall adc_to_8bit
    sts threshold_8bit, r24

    ; Evaluasi status udara
    rcall evaluate_status
    rcall update_fan_hybrid

    ; Integrasi LCD
    rcall update_lcd_display

    rjmp MAIN_LOOP

; Fungsi untuk menampilkan data ke LCD (Anggota D)
update_lcd_display:
    ; Baris 0: "G:xxx T:xxC H:xx%"
    ldi r24, 0
    ldi r22, 0
    rcall lcd_set_cursor

    ldi ZL, lo8(str_lcd_g)
    ldi ZH, hi8(str_lcd_g)
    rcall lcd_print_string
    lds r24, gas_8bit
    rcall lcd_print_number

    ldi ZL, lo8(str_lcd_t)
    ldi ZH, hi8(str_lcd_t)
    rcall lcd_print_string
    lds r24, dht11_temperature
    rcall lcd_print_number
    ldi ZL, lo8(str_lcd_c)
    ldi ZH, hi8(str_lcd_c)
    rcall lcd_print_string

    ldi ZL, lo8(str_lcd_h)
    ldi ZH, hi8(str_lcd_h)
    rcall lcd_print_string
    lds r24, dht11_humidity
    rcall lcd_print_number
    ldi ZL, lo8(str_lcd_pct)
    ldi ZH, hi8(str_lcd_pct)
    rcall lcd_print_string

    ; Baris 1: Status (AMAN/WASPADA/BAHAYA)
    ldi r24, 0
    ldi r22, 1
    rcall lcd_set_cursor

    lds r16, air_status
    cpi r16, STATUS_AMAN
    breq print_lcd_aman
    cpi r16, STATUS_WASPADA
    breq print_lcd_waspada

print_lcd_bahaya:
    ldi ZL, lo8(str_bahaya)
    ldi ZH, hi8(str_bahaya)
    rjmp do_print_lcd_status
print_lcd_aman:
    ldi ZL, lo8(str_aman)
    ldi ZH, hi8(str_aman)
    rjmp do_print_lcd_status
print_lcd_waspada:
    ldi ZL, lo8(str_waspada)
    ldi ZH, hi8(str_waspada)

do_print_lcd_status:
    rcall lcd_print_string
    ret

; Evaluasi status udara berdasarkan gas_8bit dan threshold_8bit
evaluate_status:
    lds r16, gas_8bit
    lds r17, threshold_8bit
    mov r18, r17
    lsr r18 ; r18 = threshold / 2
    cp r16, r18
    brsh eval_check_warn
    ldi r16, STATUS_AMAN
    sts air_status, r16
    ret
eval_check_warn:
    lds r16, gas_8bit
    lds r17, threshold_8bit
    cp r16, r17
    brsh eval_bahaya
    ldi r16, STATUS_WASPADA
    sts air_status, r16
    ret
eval_bahaya:
    ldi r16, STATUS_BAHAYA
    sts air_status, r16
    ret
