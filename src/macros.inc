#ifndef MACROS_INC
#define MACROS_INC

.equ LED_HIJAU, 2
.equ FAN_PWM, 3
.equ LED_KUNING, 4
.equ LED_MERAH, 5

.equ ADC_GAS, 0
.equ ADC_POT, 1

.equ BTN_OVERRIDE, 2
.equ DHT11_PIN, 4
.equ BUZZER_PIN, 5

.equ STATUS_AMAN, 0
.equ STATUS_WASPADA, 1
.equ STATUS_BAHAYA, 2

.equ PWM_OFF, 0
.equ PWM_MAX, 255
.equ TEMP_THRESHOLD, 30

.equ UBRR_9600, 103

.equ TIMER1_1S, 15624

.equ LCD_ADDR, 0x4E
.equ LCD_BACKLIGHT, 0x08
.equ LCD_EN, 0x04
.equ LCD_RS, 0x01

.equ EEPROM_THRESHOLD_L, 0x00
.equ EEPROM_THRESHOLD_H, 0x01
.equ EEPROM_MAGIC, 0x02
.equ EEPROM_MAGIC_VAL, 0xAB

.macro NOP2
    nop
    nop
.endm

.macro NOP4
    nop
    nop
    nop
    nop
.endm

#endif
