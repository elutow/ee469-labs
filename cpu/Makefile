#!/usr/bin/make -f

TARGET=lab2_code

.PHONY: default clean

default: $(TARGET).hex $(TARGET).objdump

$(TARGET).o: $(TARGET).s
	arm-linux-gnueabi-gcc -o $(TARGET).o -c $(TARGET).s

$(TARGET).hex: $(TARGET).o
	./elftohex.sh $(TARGET).o $(TARGET).hex

$(TARGET).raw: $(TARGET).hex
	xxd -r -p $(TARGET).hex $(TARGET).raw

$(TARGET).objdump: $(TARGET).raw
	arm-linux-gnueabi-objdump --disassemble-all --target=binary --endian=big \
		--architecture=armv2 --show-raw-insn $(TARGET).raw > $(TARGET).objdump

clean:
	rm $(TARGET).o || true
	rm $(TARGET).hex || true
	rm $(TARGET).raw || true
	rm $(TARGET).objdump || true
