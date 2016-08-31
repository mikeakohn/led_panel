#!/usr/bin/env python

import time
from led_panel import led_panel

def draw_mandel(real_start, real_end, imaginary_start, imaginary_end):
  #real_start = -2.0
  #real_end = 1.0
  #imaginary_start = -1.0
  #imaginary_end = 1.0

  dx = (real_end - real_start) / 32
  dy = (imaginary_end - imaginary_start) / 16

  imaginary = imaginary_start

  for y in range(0,16):
    real = real_start
    leds.copy_display_buffer()

    for x in range(0,32):
      z_real = 0
      z_imaginary = 0

      for count in range(0,16):
        temp_real = (z_real * z_real) - (z_imaginary * z_imaginary);
        temp_imaginary = 2 * z_real * z_imaginary;
        if (temp_real * temp_real) + (temp_imaginary * temp_imaginary) > 4:
          break;
        z_real = temp_real + real;
        z_imaginary = temp_imaginary + imaginary;

      leds.plot(x, y, (15 - count) / 2);

      real += dx
    leds.page_flip()
    imaginary += dy

# ---------------------------- fold here ----------------------------------

leds = led_panel("/dev/ttyUSB0")

leds.clear_draw_buffer()
leds.page_flip()

draw_mandel(-2.0, 1.0, -1.0, 1.0)

#for x in range(0, 32):
#  leds.plot(x, 0, 2)
#  leds.plot(x, 15, 1)
#  time.sleep(1)

time.sleep(5)
leds.clear_draw_buffer()
leds.page_flip()

