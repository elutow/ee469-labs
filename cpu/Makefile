#!/usr/bin/make -f

TARGET=lab1_code

.PHONY: all clean

default: $(TARGET).hex

$(TARGET).o: $(TARGET).s
	arm-linux-gnueabi-gcc-8 -o $(TARGET).o -c $(TARGET).s

$(TARGET).hex: $(TARGET).o
	./elftohex.sh $(TARGET).o $(TARGET).hex

clean:
	rm $(TARGET).o || true
	rm $(TARGET).hex || true
