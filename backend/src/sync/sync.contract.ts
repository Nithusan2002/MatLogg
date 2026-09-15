import { z } from 'zod';

export const SYNC_SCHEMA_VERSION = 1;
export const MAX_SYNC_EVENTS = 50;
export const MAX_SYNC_PAYLOAD_BYTES = 64 * 1024;

export const syncEventTypes = new Set([
  'log.create', 'log.update', 'log.upsert', 'log.delete',
  'goal.set', 'favorite.add', 'favorite.remove',
  'weight.add', 'weight.upsert', 'weight.delete', 'product.upsert',
]);

export const logPayloadSchema = z.object({
  id: z.string().uuid(), date: z.string().datetime(), meal: z.string().min(1),
  grams: z.number().positive(), kcal: z.number().nonnegative(),
  protein: z.number().nonnegative(), carbs: z.number().nonnegative(), fat: z.number().nonnegative(),
  productRef: z.string().uuid().optional().nullable(),
});

export const goalPayloadSchema = z.object({
  kcalTarget: z.number().positive(), proteinTarget: z.number().nonnegative(),
  carbTarget: z.number().nonnegative(), fatTarget: z.number().nonnegative(),
});

export const favoritePayloadSchema = z.object({ productId: z.string().uuid() });
export const weightPayloadSchema = z.object({
  id: z.string().uuid(), date: z.string().datetime(), weightKg: z.number().positive(),
});
export const productPayloadSchema = z.object({
  id: z.string().uuid(), name: z.string().min(1), brand: z.string().optional().nullable(),
  barcode: z.string().optional().nullable(), nutrientsPer100g: z.record(z.any()),
  imageUrl: z.string().optional().nullable(), source: z.string().min(1),
});
