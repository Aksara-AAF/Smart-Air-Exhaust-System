# ============================================================
# Makefile — Smart Air Exhaust System
# ATmega328P @ 16MHz, AVR-GCC toolchain
# ============================================================
# Cara penggunaan:
#   make          → compile & link semua file
#   make flash    → upload ke Arduino via avrdude
#   make clean    → hapus file build
#   make serial   → buka serial monitor (COM port harus diubah)
# ============================================================

# --- Konfigurasi ---
TARGET   = smart_exhaust
MCU      = atmega328p
F_CPU    = 16000000UL
PORT     = COMx          # Ganti sesuai port Arduino di PC
BAUD     = 115200        # Baud untuk upload (bukan serial monitor)

# --- Toolchain ---
# (Ganti 'username' dengan nama User PC)
AVR_GCC_DIR = C:/Users/username/AppData/Local/Arduino15/packages/arduino/tools/avr-gcc/7.3.0-atmel3.6.1-arduino7/bin
AVRDUDE_DIR = C:/Users/username/AppData/Local/Arduino15/packages/arduino/tools/avrdude/8.0.0-arduino1/bin
AVRDUDE_CONF= C:/Users/username/AppData/Local/Arduino15/packages/arduino/tools/avrdude/8.0.0-arduino1/etc/avrdude.conf

CC       = "$(AVR_GCC_DIR)/avr-gcc"
OBJCOPY  = "$(AVR_GCC_DIR)/avr-objcopy"
AVRDUDE  = "$(AVRDUDE_DIR)/avrdude"
SIZE     = "$(AVR_GCC_DIR)/avr-size"

# --- Flags ---
CFLAGS   = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -Wall -Wextra

# --- Source files ---
SRCS     = src/main.S     \
           src/adc.S      \
           src/dht11.S    \
           src/i2c_lcd.S  \
           src/timer.S    \
           src/usart.S    \
           src/eeprom.S   \
           src/gpio.S     \
           src/interrupt.S

# --- Output files ---
ELF      = build/$(TARGET).elf
HEX      = build/$(TARGET).hex
MAP      = build/$(TARGET).map

# ============================================================
# Default target: build ELF dan HEX
# ============================================================
all: build_dir $(ELF) $(HEX) size

# Buat direktori build jika belum ada
build_dir:
	@if not exist build mkdir build

# Compile semua .S menjadi .elf
$(ELF): $(SRCS) src/macros.inc
	$(CC) $(CFLAGS) -nostartfiles -Isrc -o $@ $(SRCS) -Wl,-Map,$(MAP)

# Convert .elf ke .hex untuk upload
$(HEX): $(ELF)
	$(OBJCOPY) -O ihex -R .eeprom $< $@

# Tampilkan ukuran program
size: $(ELF)
	$(SIZE) --format=avr --mcu=$(MCU) $<

# ============================================================
# Upload ke Arduino
# ============================================================
flash: $(HEX)
	$(AVRDUDE) -C "$(AVRDUDE_CONF)" -c arduino -p $(MCU) -P $(PORT) -b $(BAUD) -U flash:w:$(HEX):i

# ============================================================
# Serial Monitor (gunakan Python atau PuTTY)
# ============================================================
serial:
	@echo "Buka Serial Monitor di IDE Arduino / PuTTY port $(PORT) baud 9600"

# ============================================================
# Clean
# ============================================================
clean:
	@if exist build rmdir /s /q build
	@echo "Build directory cleaned."

.PHONY: all build_dir size flash serial clean
