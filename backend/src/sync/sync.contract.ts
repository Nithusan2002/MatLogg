import { z } from 'zod';

export const SYNC_SCHEMA_VERSION = 1;
export const MAX_SYNC_EVENTS = 50;
export const MAX_SYNC_PAYLOAD_BYTES = 64 * 1024;
export const MAX_SYNC_PAYLOAD_BASE64_CHARS = 4 * Math.ceil(MAX_SYNC_PAYLOAD_BYTES / 3);

export function decodeBase64Payload(value: string): Buffer | null {
  if (value.length > MAX_SYNC_PAYLOAD_BASE64_CHARS || value.length % 4 !== 0) return null;
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) return null;

  const decoded = Buffer.from(value, 'base64');
  return decoded.toString('base64') === value ? decoded : null;
}

export const syncEventTypes = new Set([
  'log.create', 'log.update', 'log.upsert', 'log.delete',
  'goal.set', 'favorite.add', 'favorite.remove',
  'weight.add', 'weight.upsert', 'weight.delete', 'product.upsert',
  'saved_meal.upsert', 'saved_meal.delete',
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

export const savedMealPayloadSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(80),
  suggestedMealType: z.enum(['frokost', 'lunsj', 'middag', 'snacks']).optional().nullable(),
  updatedAt: z.string().datetime(),
  items: z.array(z.object({
    id: z.string().uuid(),
    productId: z.string().uuid(),
    productName: z.string().trim().min(1).max(200),
    amountG: z.number().positive().max(10_000),
    calories: z.number().int().nonnegative(),
    protein: z.number().nonnegative(),
    carbs: z.number().nonnegative(),
    fat: z.number().nonnegative(),
    nutritionSource: z.enum(['matvaretabellen', 'openFoodFacts', 'user']),
    sortIndex: z.number().int().nonnegative(),
  })).min(1).max(50),
});
