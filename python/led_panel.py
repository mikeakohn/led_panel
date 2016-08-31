#!/usr/bin/env python

import serial

class led_panel:
  def __init__(self, device):
    self.ser = serial.Serial(device, 9600)
    #print self.ser

  def close(self):
    self.ser.close()

  def plot(self, x, y, color):
    address = (y * 32) + x
    self.ser.write(chr(address >> 8))
    self.ser.write(chr(address & 0xff))
    self.ser.write(chr(color))
    self.ser.read(1)

  def page_flip(self):
    self.ser.write(chr(0xff))
    self.ser.read(1)

  def clear_draw_buffer(self):
    self.ser.write(chr(0xfe))
    self.ser.read(1)

  def copy_display_buffer(self):
    self.ser.write(chr(0xfd))
    self.ser.read(1)

  def shift_left(self):
    self.ser.write(chr(0xfc))
    self.ser.read(1)

  def shift_right(self):
    self.ser.write(chr(0xfb))
    self.ser.read(1)

  def shift_up(self):
    self.ser.write(chr(0xfa))
    self.ser.read(1)

  def shift_down(self):
    self.ser.write(chr(0xf9))
    self.ser.read(1)


