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
.extern lcd_print_number_2
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

.global gas_8bit

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
lcd_page_counter: .skip 1

; String konstan di Flash
.section .progmem.data, "a", @progbits
str_init_ok: .asciz "Smart Exhaust OK\r\n"
str_lcd_init: .asciz "Smart Exhaust"
str_lcd_g:    .asciz "G:"
str_lcd_t:    .asciz "|T:"
str_lcd_h:    .asciz "|H:"
str_lcd_fan:  .asciz "FAN SPEED:      "
str_lcd_pwm:  .asciz "/255"
str_aman:     .asciz "AMAN|"
str_waspada:  .asciz "WASPADA|"
str_bahaya:   .asciz "BAHAYA|"
str_mode_auto:.asciz "AUTO  "
str_mode_man: .asciz "MANUAL"

; String untuk serial log USART
str_log_gas:  .asciz "Gas:"
str_log_tmp:  .asciz "|Tmp:"
str_log_hum:  .asciz "|Hum:"
str_log_pipe: .asciz "|"
str_log_aman: .asciz "AMAN|"
str_log_waspada: .asciz "WASPADA|"
str_log_bahaya: .asciz "BAHAYA|"
str_log_auto: .asciz "AUTO|Fan:"
str_log_manual: .asciz "MANUAL|Fan:"

.section .vectors

; Interrupt Vector Table
.org 0x0000
    jmp RESET
.org 0x0004
    jmp ISR_INT0
.org 0x0008
    reti
.org 0x000C
    reti
.org 0x0010
    reti
.org 0x0014
    reti
.org 0x0018
    reti
.org 0x001C
    reti
.org 0x0020
    reti
.org 0x0024
    reti
.org 0x0028
    reti
.org 0x002C
    jmp ISR_TIMER1_COMPA

.section .text

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
    sts lcd_page_counter, r16

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

    ; Baca suhu dan kelembaban dari DHT11
    rcall dht11_read

    ; Evaluasi status udara
    rcall evaluate_status

    ; Override & Aktuator
    rcall update_actuators
    
    lds r16, override_flag
    cpi r16, 1
    breq manual_override_fan
    rcall update_fan_hybrid
    rjmp fan_override_done
manual_override_fan:
    ldi r24, PWM_MAX
    rcall fan_set_speed
fan_override_done:

    ; Integrasi LCD
    rcall update_lcd_display

    ; Log USART
    rcall send_serial_log

    rjmp MAIN_LOOP

; Fungsi untuk menampilkan data ke LCD
update_lcd_display:
    ; Increment page counter
    lds r16, lcd_page_counter
    inc r16
    cpi r16, 5
    brne lcd_page_save
    ldi r16, 0
lcd_page_save:
    sts lcd_page_counter, r16

    ; Check if we should show page 2
    cpi r16, 3
    brsh draw_page_2

draw_page_1:
    ; Baris 0: "G:XXX|T:XX|H:XX"
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
    rcall lcd_print_number_2

    ldi ZL, lo8(str_lcd_h)
    ldi ZH, hi8(str_lcd_h)
    rcall lcd_print_string
    lds r24, dht11_humidity
    rcall lcd_print_number_2

    ; Spasi untuk membersihkan karakter sisa
    ldi r24, ' '
    rcall lcd_send_data

    ; Baris 1: Status (AMAN|AUTO)
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

    ; Cetak Mode Override
    lds r16, override_flag
    cpi r16, 1
    breq print_lcd_man
print_lcd_auto:
    ldi ZL, lo8(str_mode_auto)
    ldi ZH, hi8(str_mode_auto)
    rjmp do_print_lcd_mode
print_lcd_man:
    ldi ZL, lo8(str_mode_man)
    ldi ZH, hi8(str_mode_man)
do_print_lcd_mode:
    rcall lcd_print_string
    ret

draw_page_2:
    ; Baris 0: FAN SPEED:
    ldi r24, 0
    ldi r22, 0
    rcall lcd_set_cursor
    ldi ZL, lo8(str_lcd_fan)
    ldi ZH, hi8(str_lcd_fan)
    rcall lcd_print_string

    ; Baris 1: xxx /255
    ldi r24, 0
    ldi r22, 1
    rcall lcd_set_cursor
    
    lds r24, 0xB3 ; Baca register OCR2A (Kecepatan PWM)
    rcall lcd_print_number

    ldi ZL, lo8(str_lcd_pwm)
    ldi ZH, hi8(str_lcd_pwm)
    rcall lcd_print_string

    ; Clear the rest of the line
    ldi r17, 8
lcd_clear_pwm:
    ldi r24, ' '
    rcall lcd_send_data
    dec r17
    brne lcd_clear_pwm

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


; Update LED dan Buzzer berdasarkan status
update_actuators:
    lds r16, air_status
    cpi r16, STATUS_AMAN
    breq act_aman
    cpi r16, STATUS_WASPADA
    breq act_waspada
act_bahaya:
    rcall led_set_bahaya
    rcall buzzer_on
    ret
act_aman:
    rcall led_set_aman
    rcall buzzer_off
    ret
act_waspada:
    rcall led_set_waspada
    rcall buzzer_beep
    ret


; Kirim format log USART
send_serial_log:
    ; "Gas:"
    ldi ZL, lo8(str_log_gas)
    ldi ZH, hi8(str_log_gas)
    rcall usart_send_string
    lds r24, gas_8bit
    clr r25
    rcall usart_send_number

    ; "|Tmp:"
    ldi ZL, lo8(str_log_tmp)
    ldi ZH, hi8(str_log_tmp)
    rcall usart_send_string
    lds r24, dht11_temperature
    clr r25
    rcall usart_send_number

    ; "|Hum:"
    ldi ZL, lo8(str_log_hum)
    ldi ZH, hi8(str_log_hum)
    rcall usart_send_string
    lds r24, dht11_humidity
    clr r25
    rcall usart_send_number

    ; "|"
    ldi ZL, lo8(str_log_pipe)
    ldi ZH, hi8(str_log_pipe)
    rcall usart_send_string

    ; Status aman/waspada/bahaya
    lds r16, air_status
    cpi r16, STATUS_AMAN
    breq log_stat_aman
    cpi r16, STATUS_WASPADA
    breq log_stat_waspada
log_stat_bahaya:
    ldi ZL, lo8(str_log_bahaya)
    ldi ZH, hi8(str_log_bahaya)
    rjmp log_stat_done
log_stat_aman:
    ldi ZL, lo8(str_log_aman)
    ldi ZH, hi8(str_log_aman)
    rjmp log_stat_done
log_stat_waspada:
    ldi ZL, lo8(str_log_waspada)
    ldi ZH, hi8(str_log_waspada)
log_stat_done:
    rcall usart_send_string

    ; Status override (auto/manual)
    lds r16, override_flag
    cpi r16, 1
    breq log_mode_manual
log_mode_auto:
    ldi ZL, lo8(str_log_auto)
    ldi ZH, hi8(str_log_auto)
    rjmp log_mode_done
log_mode_manual:
    ldi ZL, lo8(str_log_manual)
    ldi ZH, hi8(str_log_manual)
log_mode_done:
    rcall usart_send_string

    ; Cetak Fan Speed (OCR2A)
    lds r24, 0xB3
    clr r25
    rcall usart_send_number

    ; Tambahkan "/255" ke log
    ldi ZL, lo8(str_lcd_pwm)
    ldi ZH, hi8(str_lcd_pwm)
    rcall usart_send_string

    ; Baris baru
    rcall usart_send_newline
    ret
