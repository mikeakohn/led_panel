
ATmega168 firmware to control an LED panel.

In order to avoid tearing due to the pixels changing in the middle of
drawing, this firmware does dubble buffering.  The display buffer is
the buffer that will currently be drawn.  The drawing buffer is the
hidden buffer that the user can draw into.  After drawing an image
in the drawing buffer, the user will issue a "page flip" command (0xff)
to the firmware to tell it to make the hidden buffer the new display
buffer.

Commands:
<HIBYTE> <LOWBYTE> <COLOR>     Set pixel number to color.
0xff                           Page flip
0xfe                           Clear drawing buffer
0xfd                           Copy display buffer to drawing buffer
0xfc                           Shift drawing buffer left 
0xfb                           Shift drawing buffer right 
0xfa                           Shift drawing buffer up 
0xf9                           Shift drawing buffer down 


