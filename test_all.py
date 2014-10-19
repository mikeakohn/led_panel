#!/usr/bin/env python

import time
from led_panel import led_panel

leds = led_panel("/dev/ttyUSB1")

#ser = serial.Serial("/dev/ttyUSB0", 9600)

leds.clear_draw_buffer()
leds.plot(5,2)

