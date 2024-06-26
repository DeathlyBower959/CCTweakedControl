import { z } from 'zod';

const CoordinateSchema = z.object({
  x: z.number(),
  y: z.number(),
  z: z.number(),
  direction: z.enum(['north', 'east', 'south', 'west']).optional(),
});

export const TurtlePos = z.object({
  type: z.literal('pos'),
  data: CoordinateSchema,
});

export const WorldState = z.object({
  type: z.literal('world'),
  data: z.object({
    blocks: z.array(
      z.object({
        id: z.string(),
        pos: CoordinateSchema,
      })
    ),
  }),
});

export type ExtractKey<
  T extends z.ZodType,
  TKey extends keyof z.infer<T> = 'type'
> = z.infer<T> extends { type: string } ? z.infer<T>[TKey] : never;

export type TTurtleDataTypes = ExtractKey<typeof TurtlePos>;
