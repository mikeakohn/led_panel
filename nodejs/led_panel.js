
// LED Panel node.js module - Copyright 2014-2016 by Michael Kohn
// Email: mike@mikekohn.net
//   Web: http://www.mikekohn.net/
//
// Control an RGB 32x16 LED panel with a Tessel 2.

var tessel = require('tessel');
//var sleep = require('sleep');

var buffer = new Buffer(1);
var point = new Buffer(3);
var port;
var uart;

var uart_busy = false;

function sleep(millis)
{
  return new Promise((resolve) => setTimeout(resolve, millis));
}

function send_bytes(buffer)
{
  uart_busy = true;
  uart.write(buffer);
}

module.exports =
{
  init: function()
  {
    port = tessel.port.A;
    uart = new port.UART({ baudrate: 9600 });
    uart.on('data', function (data)
      {
        uart_busy = false;
        //console.log(data);
      });
  },

  close: function()
  {
  },

  is_busy: function()
  {
    return uart_busy;
  },

  plot: function(x, y, color)
  {
    address = (y * 32) + x;
    point[0] = address >> 8;
    point[1] = address & 0xff;
    point[2] = color;
    send_bytes(point);
  },

  page_flip: function()
  {
    buffer[0] = 0xff;
    send_bytes(buffer);
  },

  clear_draw_buffer: function()
  {
    buffer[0] = 0xfe;
    send_bytes(buffer);
  },

  copy_display_buffer: function()
  {
    buffer[0] = 0xfd;
    send_bytes(buffer);
  },

  shift_left: function()
  {
    buffer[0] = 0xfc;
    send_bytes(buffer);
  },

  shift_right: function()
  {
    buffer[0] = 0xfb;
    send_bytes(buffer);
  },

  shift_up: function()
  {
    buffer[0] = 0xfa;
    send_bytes(buffer);
  },

  shift_down: function()
  {
    buffer[0] = 0xf9;
    send_bytes(buffer);
  },
};



