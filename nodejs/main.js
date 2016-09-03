
var led_panel = require("./led_panel.js");
var letters = require("./letters.js");
const dgram = require('dgram');
const server = dgram.createSocket('udp4');

var need_flip = false;
var need_letter = true;
var shift_delay = 30;
var points = [];
var text = "START";
var color = 1;

function draw_letter(letter, color)
{
  var x, y;

  if (letter >= 65 && letter <= 90) { letter -= 65; }
  else if (letter >= 48 && letter <= 57) { letter = (letter - 48) + 26; }
  else if (letter == 46) { letter = 26 + 10; }
  else { letter = 26 + 10 + 1; }

  letter = letters.letters[letter];

  //console.log(letter);

  for (x = 0; x < 6; x++)
  {
    for (y = 0; y < 8; y++)
    {
      if (letter[y][x] == 1)
      {
        points.push([ x, y + 4, color ]);
      }
      else
      {
        points.push([ x, y + 4, 0 ]);
      }
    }
  }

  for (y = 0; y < 8; y++)
  {
    points.push([ x, y + 4, 0 ]);
  }
}

function send_next()
{
  if (led_panel.is_busy()) { return; }

  if (need_letter == true)
  {
    if (text.length != 0)
    {
      draw_letter(text.charCodeAt(0), color);
      text = text.slice(1);
    }
    else
    {
      draw_letter(26 + 10 + 1, color);
    }

    need_letter = false;
    //need_flip = true;

    return;
  }

  if (need_flip == true)
  {
    led_panel.page_flip();
    need_flip = false;
    return;
  }

  shift_delay--;

  if (shift_delay == 9)
  {
    led_panel.copy_display_buffer();
  }
  else if (shift_delay == 8)
  {
    led_panel.shift_left();
  }
  else if (shift_delay < 8)
  {
    if (points.length != 0)
    {
      point = points.shift();
      //console.log(point);
      led_panel.plot(31, point[1], point[2]);
    }

    if (shift_delay == 0)
    {
      need_flip = true;
      need_letter = points.length == 0;
      shift_delay = 15;
    }
  }
}

server.on('error', (err) =>
{
  console.log(`error: ${err.stack}`);
  server.close();
});

server.on('message', (msg, src) =>
{
  console.log(`message: ${msg} from ${src.address} port ${src.port}`);

  if (text.length == 0)
  {
    message = msg.toString();
    c = message.charAt(0);

    if (c == 'R') { color = 1; }
    else if (c == 'G') { color = 2; }
    else if (c == 'B') { color = 4; }
    else { color = 15; }

    text = message.slice(1);
  }
});

server.on('listening', () =>
{
  var address = server.address();

  console.log(`listening: ${address.address} port ${address.port}`);
});

server.bind(10000);

led_panel.init();
//draw_letter(letters.letters[3]);
//led_panel.clear_draw_buffer();
//led_panel.plot(0, 0, 1);
//led_panel.page_flip();
//led_panel.shift_down();
//led_panel.close();

setInterval(send_next, 1);



