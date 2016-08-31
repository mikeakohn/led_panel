#!/usr/bin/env python

import time
from led_panel import led_panel

leds = led_panel("/dev/ttyUSB0")

leds.clear_draw_buffer()
leds.page_flip()

for x in range(0, 32):
  leds.copy_display_buffer()
  leds.plot(x, 0, 2)
  leds.plot(x, 15, 1)
  leds.page_flip()
  time.sleep(0.1)

for y in range(0, 16):
  leds.copy_display_buffer()
  leds.plot(11, y, 1)
  leds.plot(12, y, 2)
  leds.plot(13, y, 3)
  leds.plot(14, y, 4)
  leds.plot(15, y, 5)
  leds.plot(16, y, 6)
  leds.plot(17, y, 7)
  leds.page_flip()
  time.sleep(0.1)

time.sleep(1)

for count in range(0, 11):
  leds.copy_display_buffer()
  leds.shift_left()
  leds.page_flip()
  time.sleep(0.1)

for y in range(0, 16):
  leds.copy_display_buffer()
  leds.plot(25, y, 1)
  leds.plot(26, y, 2)
  leds.plot(27, y, 3)
  leds.plot(28, y, 4)
  leds.plot(29, y, 5)
  leds.plot(30, y, 6)
  leds.plot(31, y, 7)
  leds.page_flip()
  time.sleep(0.1)

for count in range(0, 11):
  leds.copy_display_buffer()
  leds.shift_right()
  leds.page_flip()
  time.sleep(0.1)

leds.copy_display_buffer()
color = 1
for x in range(0, 32):
  leds.plot(x, 0, color)
  leds.plot(x, 15, color)
  color += 1
  if color == 8: color = 1

for y in range(0, 16):
  if y < 8: color2 = 1
  else: color2 = 2

  leds.plot(0, y, color)
  leds.plot(2, y, color2)
  leds.plot(31, y, color)
  color += 1
  if color == 8: color = 1

leds.page_flip()
time.sleep(1)

for count in range(0, 11):
  leds.copy_display_buffer()
  leds.shift_up()
  leds.page_flip()
  time.sleep(0.1)

leds.copy_display_buffer()

for y in range(0, 16):
  if y < 8: color2 = 1
  else: color2 = 2

  #leds.plot(0, y, color)
  leds.plot(8, y, color2)
  #leds.plot(31, y, color)
  color += 1
  if color == 8: color = 1

leds.page_flip()

for count in range(0, 11):
  leds.copy_display_buffer()
  leds.shift_down()
  leds.page_flip()
  time.sleep(0.1)

#leds.clear_draw_buffer()
#leds.page_flip()



