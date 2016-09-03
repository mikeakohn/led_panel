
ATmega168 firmware to control an LED panel.
===========================================

This is a some firmware for controlling an LED Panel.  The main code was
written in AVR8 assembly.  After the firmware is written to the chip, the
chip takes commands over the UART serial port.  I wrote a high level
API in both Python and node.js for controlling the board.  For more information
visit:

[http://www.mikekohn.net/micro/led_panel.php](http://www.mikekohn.net/micro/led_panel.php)

Python
------
The Python module has basically the following functions defined:

~~~~
__init__(device)
close()
plot(x, y, color)
page_flip()
clear_draw_buffer()
copy_display_buffer()
shift_left()
shift_right()
shift_up()
shift_down()
~~~~

Any plot, shift, etc, commands will go to a hidden buffer.  To make that buffer
the visible buffer just call page_flip().  If the new buffer should be a copy of
the current buffer, with some small changes (like a shift plus 1 new column of
LED's to make a scroller), the copy_display_buffer() function can be used.

node.js
-------
The node.js API was written to run on a Tessel 2, but could be easily ported to a
standard UART.  The following functions are implemented:

~~~~
init()
close()
is_busy()
plot()
page_flip()
clear_draw_buffer()
copy_display_buffer()
shift_left()
shift_right()
shift_up()
shift_down()
~~~~

The same rules for Python apply to the node.js API.

Firmware
--------
In order to avoid tearing due to the pixels changing in the middle of
drawing, this firmware does double buffering.  The display buffer is
the buffer that will currently be drawn.  The drawing buffer is the
hidden buffer that the user can draw into.  After drawing an image
in the drawing buffer, the user will issue a "page flip" command (0xff)
to the firmware to tell it to make the hidden buffer the new display
buffer.

~~~~
Commands:
<HIBYTE> <LOWBYTE> <COLOR>     Set pixel number to color.
0xff                           Page flip
0xfe                           Clear drawing buffer
0xfd                           Copy display buffer to drawing buffer
0xfc                           Shift drawing buffer left 
0xfb                           Shift drawing buffer right 
0xfa                           Shift drawing buffer up 
0xf9                           Shift drawing buffer down 
~~~~

