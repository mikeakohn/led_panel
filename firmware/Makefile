
PROGRAM=led_panel

default: $(PROGRAM).hex

$(PROGRAM).hex: $(PROGRAM).asm
	naken_asm -l -I/usbdisk/devkits/atmel -o $(PROGRAM).hex $(PROGRAM).asm

program:
	@echo "Not correct..."
	#avrdude -c stk500v2 -p t85 -P /dev/ttyUSB0 -U flash:w:$(PROGRAM).hex
	#sudo avrdude -c usbtiny -p t85 -U flash:w:$(PROGRAM).hex:i

setfuse:
	@echo "Not correct..."
	#sudo avrdude -c usbtiny -p t85 -U lfuse:w:0xee:m
	#sudo avrdude -c usbtiny -p t85 -U hfuse:w:0xdf:m

clean:
	@rm -f *.hex
	@rm -f *.lst
	@echo "Clean!"


