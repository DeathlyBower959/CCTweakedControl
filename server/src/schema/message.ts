import { z } from 'zod';

const CoordinateSchema = z.object({
  x: z.number(),
  y: z.number(),
  z: z.number(),
  direction: z.number().min(1).max(4).optional(),
});

export const TurtlePos = z.object({
  type: z.literal('pos'),
  data: CoordinateSchema,
});
export type ITurtlePos = z.infer<typeof TurtlePos>;

export const WorldState = z.object({
  type: z.literal('world'),
  data: z.array(
    z.object({
      id: z.string(),
      pos: CoordinateSchema,
    })
  ),
});
export type IWorldState = z.infer<typeof WorldState>;

export const ReadyPing = z.object({
  type: z.literal('ready'),
  data: z.object({
    id: z.string(),
  }),
});
export type ISetupPing = z.infer<typeof ReadyPing>;

export const FuelPing = z.object({
  type: z.literal('fuel'),
  data: z.object({ remaining: z.number(), capacity: z.number() }),
});
export type IFuelPing = z.infer<typeof FuelPing>;

export type TTurtleDataTypes =
  | ITurtlePos['type']
  | IWorldState['type']
  | ISetupPing['type']
  | IFuelPing['type'];
