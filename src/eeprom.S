#define __SFR_OFFSET 0x00
#include "avr/io.h"
#include "macros.inc"

.global eeprom_write_byte
.global eeprom_read_byte
.global eeprom_save_threshold
.global eeprom_load_threshold

.extern threshold_l
.extern threshold_h

.section .text

; Tulis 1 byte ke EEPROM (r24 = alamat, r22 = data)
eeprom_write_byte:
    ; Tunggu EEPROM siap (EEPE = 0)
eeprom_write_wait:
    sbic EECR, EEPE
    rjmp eeprom_write_wait

    ; Set alamat EEPROM
    sts EEARL, r24
    clr r16
    sts EEARH, r16

    ; Set data yang akan ditulis
    sts EEDR, r22

    ; Sequence tulis: EEMPE lalu EEPE dalam 4 siklus
    cli
    ldi r16, (1 << EEMPE)
    out EECR, r16
    sbi EECR, EEPE
    sei

    ret

; Baca 1 byte dari EEPROM (r24 = alamat, return r24 = data)
eeprom_read_byte:
    ; Tunggu EEPROM siap
eeprom_read_wait:
    sbic EECR, EEPE
    rjmp eeprom_read_wait

    ; Set alamat EEPROM
    sts EEARL, r24
    clr r16
    sts EEARH, r16

    ; Mulai baca
    sbi EECR, EERE

    ; Ambil data hasil baca
    lds r24, EEDR
    ret

; Simpan threshold 16-bit ke EEPROM dengan magic byte
eeprom_save_threshold:
    ; Simpan threshold sementara di r16 (low) dan r17 (high)
    mov r16, r24
    mov r17, r25

    ; Tulis magic byte sebagai penanda data valid
    ldi r24, EEPROM_MAGIC
    ldi r22, EEPROM_MAGIC_VAL
    rcall eeprom_write_byte

    ; Tunggu magic byte selesai ditulis
eeprom_save_wait1:
    sbic EECR, EEPE
    rjmp eeprom_save_wait1

    ; Tulis low byte threshold
    ldi r24, EEPROM_THRESHOLD_L
    mov r22, r16
    rcall eeprom_write_byte

    ; Tunggu low byte selesai ditulis
eeprom_save_wait2:
    sbic EECR, EEPE
    rjmp eeprom_save_wait2

    ; Tulis high byte threshold
    ldi r24, EEPROM_THRESHOLD_H
    mov r22, r17
    rcall eeprom_write_byte

    ret

; Muat threshold dari EEPROM, default 512 jika magic byte tidak valid
eeprom_load_threshold:
    ; Cek magic byte
    ldi r24, EEPROM_MAGIC
    rcall eeprom_read_byte

    ; Jika magic tidak cocok, gunakan default
    cpi r24, EEPROM_MAGIC_VAL
    brne eeprom_load_default

    ; Baca low byte threshold
    ldi r24, EEPROM_THRESHOLD_L
    rcall eeprom_read_byte
    mov r16, r24

    ; Baca high byte threshold
    ldi r24, EEPROM_THRESHOLD_H
    rcall eeprom_read_byte
    mov r25, r24
    mov r24, r16

    ret

; Threshold default 512 (tengah skala ADC 10-bit)
eeprom_load_default:
    ldi r24, lo8(512)
    ldi r25, hi8(512)
    ret
