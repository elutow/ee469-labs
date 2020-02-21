#!/usr/bin/make -f

TARGET=lab2_code

.PHONY: all clean

default: $(TARGET).hex

$(TARGET).o: $(TARGET).s
	arm-linux-gnueabi-gcc -o $(TARGET).o -c $(TARGET).s

$(TARGET).hex: $(TARGET).o
	./elftohex.sh $(TARGET).o $(TARGET).hex

clean:
	rm $(TARGET).o || true
	rm $(TARGET).hex || true
