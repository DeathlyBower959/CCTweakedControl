import { WebSocketServer } from 'ws';

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
  const id = (turtles.size + 1).toString();
  console.log(`Turtle connected: ${id}`);
  turtles.set(id, { ws: turtle, data: { pos: undefined } });

  turtle.on('message', data => {
    console.log(`Received message from ${id}: ${JSON.stringify(data)}`);

    let currTurtle = turtles.get(id);
    if (!currTurtle) return console.log(`Failed to find turtle: ${id}`);

    const parse = JSON.parse(data.toString());

    switch (parse.type as TTurtleDataTypes) {
      case 'pos':
        const dt = TurtlePos.parse(parse).data;

        currTurtle.data.pos = dt;
        break;
    }
  });

  turtle.on('close', () => {
    turtles.delete(id);
    console.log(`${id} disconnected`);
  });

  turtle.send(`
os.setComputerLabel(${id})
local name = '${id}'
term.clear()
print('From mama: Welcome to the world ${id}!')
  `);
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
