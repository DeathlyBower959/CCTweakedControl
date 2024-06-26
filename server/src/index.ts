import { WebSocketServer } from 'ws';

import { names } from './names';
import { ExtractKey, TTurtleDataTypes, TurtlePos } from './schema/message';

import type { WebSocket } from 'ws';
export const port = 2828;
export const web_port = 3000;

// WebSocket Server
const wss = new WebSocketServer({ port });
const turtles: Map<
  string,
  {
    ws: WebSocket;
    data: { pos: ExtractKey<typeof TurtlePos, 'data'> | undefined };
  }
> = new Map();

wss.on('connection', turtle => {
  const id = names[turtles.size % names.length];
  console.log(`Turtle connected: ${id}`);
  turtles.set(id, { ws: turtle, data: { pos: undefined } });

  turtle.on('message', data => {
    let currTurtle = turtles.get(id);
    if (!currTurtle) return console.log(`Failed to find turtle: ${id}`);

    const parse = JSON.parse(data.toString());

    switch (parse.type as TTurtleDataTypes) {
      case 'pos':
        const dt = TurtlePos.parse(parse).data;

        currTurtle.data.pos = dt;
        console.log(`POS (${id}): ${dt.x}, ${dt.y}, ${dt.z}`);
        break;
      default:
        console.log(`Unhandled message from ${id}: ${data}`);
        break;
    }
  });

  turtle.on('close', () => {
    turtles.delete(id);
    console.log(`${id} disconnected`);
  });

  turtle.send(
    JSON.stringify({
      type: 'exec',
      data: `
        local name = '${id}'
        os.setComputerLabel(name)
    `,
    })
  );
});

wss.on('listening', () => {
  console.log(`Listening on ws://localhost:${port}`);
});

// Web Server

// const app = express();

// app.use(express.static(path.join(__dirname, '../interface/dist')));

// app.post('/ws', (req) => {

// })
// app.listen(web_port, () => {
//   console.log(`Web live at http://localhost:${web_port}`);
// });
