import { z } from 'zod';

export const TurtlePos = z.object({
  type: z.literal('pos'),
  data: z.object({
    x: z.number(),
    y: z.number(),
    z: z.number(),
  }),
});

export type ExtractKey<
  T extends z.ZodType,
  TKey extends keyof z.infer<T> = 'type'
> = z.infer<T> extends { type: string } ? z.infer<T>[TKey] : never;

export type TTurtleDataTypes = ExtractKey<typeof TurtlePos>;
