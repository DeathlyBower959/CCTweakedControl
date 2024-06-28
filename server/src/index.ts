import express from 'express';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { WebSocketServer } from 'ws';

import { names } from './names';
import { FuelPing, ReadyPing, TurtlePos, WorldState } from './schema/message';

import type { WebSocket } from 'ws';
import type { IFuelPing, ITurtlePos, TTurtleDataTypes } from './schema/message';
export const port = 2828;
export const web_port = 3000;

// WebSocket Server
const wss = new WebSocketServer({ port });
export const turtles: Map<
  string,
  {
    ws: WebSocket;
    alive: boolean;
    queen: boolean;
    data: {
      pos?: ITurtlePos['data'];

      fuel?: IFuelPing['data'];
    };
    job?: string;
  }
> = new Map();

// Provide a number to this server, if you want to designate who the mother is via
// computerID (use the F3 menu on the right to see the ID of a placed turtle)
const QUEEN_ID: number | undefined = 43;

wss.on('connection', ws => {
  handleTurtleConnection(ws);
});

function handleTurtleConnection(turtle: WebSocket) {
  let id = uuidv4();
  const name_repeat = Math.floor(turtles.size / names.length);
  const name_idx = turtles.size % names.length;
  const name = names[name_idx] + (name_repeat > 0 ? ` (${name_repeat})` : '');

  if (turtles.size == 0) names.splice(name_idx, 1);

  const exisitingTurt = turtles.get(id);
  console.log(`Turtle connected: ${name} (${id})`);
  turtles.set(id, {
    ws: turtle,
    alive: true,
    queen: exisitingTurt ? exisitingTurt.queen : turtles.size == 0,
    data: exisitingTurt?.data || {},
  });

  turtle.on('message', data => {
    let turt = turtles.get(id);
    if (!turt) return console.log(`Failed to find turtle: ${id}`);

    let batch = JSON.parse(data.toString());

    if (!batch[0]) batch = [batch];
    for (const parse of batch) {
      switch (parse.type as TTurtleDataTypes) {
        case 'pos':
          const pos = TurtlePos.parse(parse).data;

          turt.data.pos = pos;
          break;
        case 'world':
          const blocks = WorldState.parse(parse).data.map(x => ({
            ...x,
            parent: id,
          }));
          // TODO: World state
          break;
        case 'fuel':
          const fuel = FuelPing.parse(parse).data;

          turt.data.fuel = fuel;
          break;
        case 'ready':
          const ready = ReadyPing.parse(parse).data;
          if (QUEEN_ID != undefined) {
            if (ready.id == QUEEN_ID) {
              turt.queen = true;
              turtles.set(id, turt);
            } else {
              turt.queen = false;
              turtles.set(id, turt);
            }
          }
          turtle.send(
            JSON.stringify({
              type: 'exec',
              data: `
                name = '${turtles.get(id)?.queen ? 'Queen ' : ''}${name}${
                !turtles.get(id)?.queen ? ' (Worker)' : ''
              }'
                os.setComputerLabel(name)
                `,
            })
          );
          break;
        default:
          console.log(`Unhandled message from ${name}: ${data}`);
          break;
      }
      turtles.set(id, turt);
    }
  });

  turtle.on('close', () => {
    const tt = turtles.get(id);
    console.log(`${name} disconnected`);
    if (!tt) return console.log(`Failed to cleanup ${name}`);
    if (tt.queen) names.push(name);
    turtles.set(id, { ...tt, alive: false });
  });
}

wss.on('listening', () => {
  console.log(`Listening on ws://localhost:${port}`);
});

// Web Server

const app = express();

app.use(express.static(path.join(__dirname, '../../interface/dist')));
app.use(express.json());

app.post('/ws', (req, res) => {
  const turtle = turtles.get(req.body.id);

  if (!turtle) return res.send('Failed to find turtle').status(400);

  turtle?.ws.send(
    JSON.stringify({
      type: 'exec',
      data: req.body.data,
    })
  );

  return res.status(200);
});

app.listen(web_port, () => {
  console.log(`Web live at http://localhost:${web_port}`);
});
