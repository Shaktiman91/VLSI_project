
CROSS = /data/picorv32-utils/riscv32imc/bin/riscv32-unknown-elf-
CFLAGS = -O0
# 4 MB flash - space for 16*1024 (~16k) 32-bit (4 byte) numbers
MAX_HEX_SIZE := $(shell echo $$((4*1024*1024-16*1024*4)))

all: accel_audio.hex

accel: accel_audio.hex

accel_audio.hex: accel_audio.elf
	$(CROSS)objcopy -O verilog $^ $@
# Make sure accel_audio.hex is not too large to fit on the flash together with the to-be-FFT'd numbers
	@if [ $$(python count_bytes_in_hex_file.py "accel_audio.hex") -gt $(MAX_HEX_SIZE) ]; then \
		echo "accel_audio.hex is too large to also fit the to-be FFT'd numbers in the flash memory"; \
		rm -f accel_audio.hex; \
		exit 1; \
	fi; \
	python prepare_fft.py $(N_CHUNKS)

accel_audio.elf: accel_audio.c fft.c uart.c flash.c linkerscript.ld
	# $(CROSS)gcc -march=rv32imc -S accel_audio.c -o accel_audio.s
	# $(CROSS)gcc -c accel_audio.s -o accel_audio.o
	# $(CROSS)gcc -march=rv32imc -S fft.c -o fft.s
	# $(CROSS)gcc -c fft.s -o fft.o
	# $(CROSS)gcc -march=rv32imc -S uart.c -o uart.s
	# $(CROSS)gcc -c uart.s -o uart.o
	# $(CROSS)gcc -march=rv32imc -S flash.c -o flash.s
	# $(CROSS)gcc -c flash.s -o flash.o
	# $(CROSS)ld -T linkerscript.ld accel_audio.o fft.o uart.o flash.o -o $@
	# $(CROSS)ld accel_audio.o fft.o uart.o flash.o -o $@
	$(CROSS)gcc $(CFLAGS) -march=rv32imc \
		-T linkerscript.ld \
		-nostdlib \
		-o $@ \
		$< fft.c uart.c flash.c

# ---- Clean ----
clean:
	rm -f accel_audio.elf accel_audio.hex

.PHONY: all
.PHONY: clean
.PHONY: accel
