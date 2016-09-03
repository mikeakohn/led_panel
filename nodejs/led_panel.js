
// LED Panel node.js module - Copyright 2014-2016 by Michael Kohn
// Email: mike@mikekohn.net
//   Web: http://www.mikekohn.net/
//
// Control an RGB 32x16 LED panel with a Tessel 2.

var tessel = require('tessel');
var buffer = new Buffer(1);
var point = new Buffer(3);

module.exports =
{

  init: function()
  {
    port = tessel.port.A;
    uart = new port.UART({ baudrate: 9600 });
  },

  close: function()
  {
  },

  plot: function(x, y, color)
  {
    address = (y * 32) + x;
    point[0] = address >> 8;
    point[1] = address && 0xff;
    point[2] = color;
    uart.write(point);
    uart.on('data', function (data) { });
  },

  page_flip: function()
  {
    buffer[0] = 0xff;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },

  clear_draw_buffer: function()
  {
    buffer[0] = 0xfe;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },

  copy_display_buffer: function()
  {
    buffer[0] = 0xfd;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },

  shift_left: function()
  {
    buffer[0] = 0xfc;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },

  shift_right: function()
  {
    buffer[0] = 0xfb;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },

  shift_up: function()
  {
    buffer[0] = 0xfa;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },

  shift_down: function()
  {
    buffer[0] = 0xf9;
    uart.write(buffer);
    uart.on('data', function (data) { });
  },
};

var port;
var uart;


