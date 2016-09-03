
var led_panel = require("./led_panel.js");
const dgram = require('dgram');
const server = dgram.createSocket('udp4');

server.on('error', (err) =>
{
  console.log(`error: ${err.stack}`);
  server.close();
});

server.on('message', (msg, src) =>
{
  console.log(`message: ${msg} from ${src.address} port ${src.port}`);
});

server.on('listening', () =>
{
  var address = server.address();

  console.log(`listening: ${address.address} port ${address.port}`);
});

server.bind(10000);

led_panel.init();
led_panel.clear_draw_buffer();
led_panel.plot(0, 0, 1);
led_panel.page_flip();
//led_panel.shift_down();
//led_panel.close();



