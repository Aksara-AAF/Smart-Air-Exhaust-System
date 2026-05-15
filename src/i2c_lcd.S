#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global i2c_init
.global i2c_start
.global i2c_write
.global i2c_stop
.global lcd_init
.global lcd_send_cmd
.global lcd_send_data
.global lcd_print_string
.global lcd_set_cursor
.global lcd_clear
.global lcd_print_number


i2c_init:
    ; Set TWI bit rate register untuk 100kHz
    ldi     r16, 72
    sts     TWBR, r16

    ; Set prescaler = 1 (TWPS1:TWPS0 = 00)
    ldi     r16, 0x00
    sts     TWSR, r16

    ; Enable TWI
    ldi     r16, (1 << TWEN)
    sts     TWCR, r16

    ret


i2c_start:
    ldi     r16, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN)
    sts     TWCR, r16

    ; Tunggu TWINT set (START terkirim)
i2c_start_wait:
    lds     r16, TWCR
    sbrs    r16, TWINT
    rjmp    i2c_start_wait

    ; Cek status: 0x08 = START, 0x10 = REPEATED START
    lds     r16, TWSR
    andi    r16, 0xF8           ; Mask prescaler bits
    cpi     r16, 0x08
    breq    i2c_start_ok
    cpi     r16, 0x10
    breq    i2c_start_ok
    ldi     r24, 1              ; Error
    ret
i2c_start_ok:
    ldi     r24, 0
    ret


i2c_write:
    ; Masukkan data ke TWDR
    sts     TWDR, r24

    ; Kirim data (clear TWINT)
    ldi     r16, (1 << TWINT) | (1 << TWEN)
    sts     TWCR, r16

    ; Tunggu TWINT set (data terkirim)
i2c_write_wait:
    lds     r16, TWCR
    sbrs    r16, TWINT
    rjmp    i2c_write_wait

    ; Cek status: 0x28 = data ACK, 0x18 = address ACK
    lds     r16, TWSR
    andi    r16, 0xF8
    cpi     r16, 0x28
    breq    i2c_write_ok
    cpi     r16, 0x18
    breq    i2c_write_ok
    ldi     r24, 1
    ret
i2c_write_ok:
    ldi     r24, 0
    ret


i2c_stop:
    ldi     r16, (1 << TWINT) | (1 << TWSTO) | (1 << TWEN)
    sts     TWCR, r16

    ; Tunggu STOP selesai (TWSTO kembali 0)
i2c_stop_wait:
    lds     r16, TWCR
    sbrc    r16, TWSTO
    rjmp    i2c_stop_wait

    ret


lcd_i2c_write_byte:
    mov     r25, r24            ; Simpan data
    rcall   i2c_start
    ldi     r24, LCD_ADDR       ; Alamat LCD
    rcall   i2c_write
    mov     r24, r25            ; Kembalikan data
    rcall   i2c_write
    rcall   i2c_stop
    ret


lcd_pulse_enable:
    mov     r25, r24

    ; Kirim dengan EN=1
    mov     r24, r25
    ori     r24, LCD_EN         ; Set EN bit
    rcall   lcd_i2c_write_byte

    ; Delay pendek (>450ns, pakai nop)
    nop
    nop
    nop
    nop

    ; Kirim dengan EN=0
    mov     r24, r25
    andi    r24, ~LCD_EN        ; Clear EN bit (komplemen)
    rcall   lcd_i2c_write_byte

    ; Delay >37µs (setelah instruksi LCD diproses)
    ldi     r16, 60
lcd_pulse_delay:
    dec     r16
    brne    lcd_pulse_delay

    ret


lcd_send_nibble:
    rcall   lcd_pulse_enable
    ret


lcd_send_byte:
    mov     r23, r24            ; Simpan byte

    ; High Nibble (bit7:4)
    mov     r24, r23
    andi    r24, 0xF0           ; Ambil 4 bit atas
    ori     r24, LCD_BACKLIGHT  ; Set backlight

    cpi     r22, 0
    breq    lcd_send_byte_cmd_high

    ori     r24, LCD_RS         ; Set RS=1 untuk data
lcd_send_byte_cmd_high:
    rcall   lcd_pulse_enable

    ; Low Nibble (bit3:0)
    mov     r24, r23
    swap    r24                 ; Swap nibble (bit3:0 jadi bit7:4)
    andi    r24, 0xF0
    ori     r24, LCD_BACKLIGHT

    cpi     r22, 0
    breq    lcd_send_byte_cmd_low

    ori     r24, LCD_RS
lcd_send_byte_cmd_low:
    rcall   lcd_pulse_enable

    ret


lcd_send_cmd:
    ldi     r22, 0              ; RS = 0 (command)
    rcall   lcd_send_byte
    ret


lcd_send_data:
    ldi     r22, 1              ; RS = 1 (data)
    rcall   lcd_send_byte
    ret


lcd_delay_ms:
    push    r24
lcd_delay_ms_outer:
    ldi     r16, 250
lcd_delay_ms_inner:
    nop
    nop
    nop
    dec     r16
    brne    lcd_delay_ms_inner
    ldi     r16, 250
lcd_delay_ms_inner2:
    nop
    nop
    nop
    dec     r16
    brne    lcd_delay_ms_inner2
    pop     r24
    dec     r24
    push    r24
    brne    lcd_delay_ms_outer
    pop     r24
    ret

lcd_init:
    ; Tunggu >40ms setelah power-on
    ldi     r24, 50
    rcall   lcd_delay_ms

    ; Kirim 0x30 tiga kali (init sequence 8-bit mode emulation)
    ldi     r24, 0x30
    andi    r24, 0xF0
    ori     r24, LCD_BACKLIGHT
    rcall   lcd_pulse_enable
    ldi     r24, 5
    rcall   lcd_delay_ms        ; Tunggu >4.1ms

    ldi     r24, 0x30
    andi    r24, 0xF0
    ori     r24, LCD_BACKLIGHT
    rcall   lcd_pulse_enable
    ldi     r24, 5
    rcall   lcd_delay_ms

    ldi     r24, 0x30
    andi    r24, 0xF0
    ori     r24, LCD_BACKLIGHT
    rcall   lcd_pulse_enable
    ldi     r24, 2
    rcall   lcd_delay_ms

    ; Set ke 4-bit mode
    ldi     r24, 0x20
    andi    r24, 0xF0
    ori     r24, LCD_BACKLIGHT
    rcall   lcd_pulse_enable
    ldi     r24, 2
    rcall   lcd_delay_ms

    ; Function Set: 4-bit, 2 baris, 5x8 font → 0x28
    ldi     r24, 0x28
    rcall   lcd_send_cmd
    ldi     r24, 2
    rcall   lcd_delay_ms

    ; Display OFF → 0x08
    ldi     r24, 0x08
    rcall   lcd_send_cmd

    ; Clear display → 0x01
    ldi     r24, 0x01
    rcall   lcd_send_cmd
    ldi     r24, 3              ; Tunggu >1.52ms untuk clear
    rcall   lcd_delay_ms

    ; Entry Mode Set: increment cursor, no shift → 0x06
    ldi     r24, 0x06
    rcall   lcd_send_cmd

    ; Display ON, cursor OFF, blink OFF → 0x0C
    ldi     r24, 0x0C
    rcall   lcd_send_cmd

    ret


lcd_clear:
    ldi     r24, 0x01           ; Clear display command
    rcall   lcd_send_cmd
    ldi     r24, 3
    rcall   lcd_delay_ms        ; Tunggu clear selesai
    ret


lcd_set_cursor:
    cpi     r22, 0              ; Baris 0?
    breq    lcd_cursor_row0

    ; Baris 1: address = 0x40 + kolom
    ori     r24, 0x40
lcd_cursor_row0:
    ori     r24, 0x80           ; Set DDRAM address command
    rcall   lcd_send_cmd
    ret


lcd_print_string:
    lpm     r24, Z+
    cpi     r24, 0
    breq    lcd_print_done
    rcall   lcd_send_data
    rjmp    lcd_print_string
lcd_print_done:
    ret


lcd_print_number:
    mov     r18, r24
    ; Ratusan
    ldi     r16, 0
lcd_num_hundreds:
    cpi     r18, 100
    brcs    lcd_num_tens_start
    subi    r18, 100
    inc     r16
    rjmp    lcd_num_hundreds
lcd_num_tens_start:
    ldi     r24, '0'
    add     r24, r16
    rcall   lcd_send_data

    ; Puluhan
    ldi     r16, 0
lcd_num_tens:
    cpi     r18, 10
    brcs    lcd_num_ones
    subi    r18, 10
    inc     r16
    rjmp    lcd_num_tens
lcd_num_ones:
    ldi     r24, '0'
    add     r24, r16
    rcall   lcd_send_data

    ; Satuan
    ldi     r24, '0'
    add     r24, r18
    rcall   lcd_send_data

    ret

.global lcd_print_number_2
lcd_print_number_2:
    mov     r18, r24
    ; Puluhan
    ldi     r16, 0
lcd_num2_tens:
    cpi     r18, 10
    brcs    lcd_num2_ones
    subi    r18, 10
    inc     r16
    rjmp    lcd_num2_tens
lcd_num2_ones:
    ldi     r24, '0'
    add     r24, r16
    rcall   lcd_send_data

    ; Satuan
    ldi     r24, '0'
    add     r24, r18
    rcall   lcd_send_data

    ret
