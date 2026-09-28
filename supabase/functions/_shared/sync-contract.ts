import { z } from "zod";

export const MAX_SYNC_EVENTS = 50;
export const MAX_SYNC_PAYLOAD_BYTES = 64 * 1024;
export const SYNC_SCHEMA_VERSION = 1;

const uuid = z.string().uuid();
const isoDate = z.string().datetime({ offset: true });
const nonNegative = z.number().finite().nonnegative();
const positive = z.number().finite().positive();

export const eventEnvelopeSchema = z.object({
  eventId: uuid,
  type: z.string().min(1).max(120),
  createdAt: isoDate,
  entityId: uuid.nullable().optional(),
  schemaVersion: z.number().int(),
  payload: z.string(),
});

export const syncRequestSchema = z.object({
  deviceId: uuid,
  clientTime: isoDate,
  events: z.array(z.unknown()),
});

const idPayload = z.object({ id: uuid });
const logPayload = z.object({
  id: uuid,
  date: isoDate,
  meal: z.string().min(1),
  grams: positive,
  unit: z.enum(["g", "ml"]).optional().default("g"),
  kcal: nonNegative,
  protein: nonNegative,
  carbs: nonNegative,
  fat: nonNegative,
  productRef: uuid.nullable().optional(),
});
const goalPayload = z.object({
  kcalTarget: positive,
  proteinTarget: nonNegative,
  carbTarget: nonNegative,
  fatTarget: nonNegative,
});
const favoritePayload = z.object({ productId: uuid });
const weightPayload = z.object({ id: uuid, date: isoDate, weightKg: positive });
const productPayload = z.object({
  id: uuid,
  name: z.string().trim().min(1),
  brand: z.string().nullable().optional(),
  barcode: z.string().nullable().optional(),
  nutrientsPer100g: z.record(z.unknown()),
  imageUrl: z.string().nullable().optional(),
  source: z.string().trim().min(1),
});
const savedMealPayload = z.object({
  id: uuid,
  name: z.string().trim().min(1).max(80),
  suggestedMealType: z.enum(["frokost", "lunsj", "middag", "snacks"]).nullable().optional(),
  updatedAt: isoDate,
  items: z.array(z.object({
    id: uuid,
    productId: uuid,
    productName: z.string().trim().min(1).max(200),
    amountG: positive.max(10_000),
    amountUnit: z.enum(["g", "ml"]).optional().default("g"),
    calories: nonNegative,
    protein: nonNegative,
    carbs: nonNegative,
    fat: nonNegative,
    nutritionSource: z.enum(["matvaretabellen", "openFoodFacts", "user"]),
    sortIndex: z.number().int().nonnegative(),
  })).min(1).max(50),
});

const payloadSchemas: Record<string, z.ZodType> = {
  "log.create": logPayload,
  "log.update": logPayload,
  "log.upsert": logPayload,
  "log.delete": idPayload,
  "goal.set": goalPayload,
  "favorite.add": favoritePayload,
  "favorite.remove": favoritePayload,
  "weight.add": weightPayload,
  "weight.upsert": weightPayload,
  "weight.delete": idPayload,
  "product.upsert": productPayload,
  "saved_meal.upsert": savedMealPayload,
  "saved_meal.delete": idPayload,
};

export type ValidatedEvent = z.infer<typeof eventEnvelopeSchema> & { payloadJson: unknown };

export type EventValidation =
  | { success: true; event: ValidatedEvent }
  | { success: false; eventId: string; code: string; message: string };

function decodeCanonicalBase64(value: string): Uint8Array | null {
  if (value.length === 0 || value.length % 4 !== 0) return null;
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) return null;
  try {
    const binary = atob(value);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    return btoa(String.fromCharCode(...bytes)) === value ? bytes : null;
  } catch {
    return null;
  }
}

export function validateEvent(value: unknown): EventValidation {
  const envelope = eventEnvelopeSchema.safeParse(value);
  const fallbackId = typeof value === "object" && value !== null && "eventId" in value
    ? String((value as { eventId: unknown }).eventId)
    : "00000000-0000-0000-0000-000000000000";
  if (!envelope.success) {
    return { success: false, eventId: fallbackId, code: "VALIDATION_ERROR", message: "Ugyldig event-envelope" };
  }
  if (envelope.data.schemaVersion !== SYNC_SCHEMA_VERSION) {
    return { success: false, eventId: envelope.data.eventId, code: "UNSUPPORTED_SCHEMA", message: "Ukjent schema-versjon" };
  }
  const schema = payloadSchemas[envelope.data.type];
  if (!schema) {
    return { success: false, eventId: envelope.data.eventId, code: "UNSUPPORTED_TYPE", message: "Ukjent type" };
  }
  const payloadBytes = decodeCanonicalBase64(envelope.data.payload);
  if (!payloadBytes) {
    return { success: false, eventId: envelope.data.eventId, code: "VALIDATION_ERROR", message: "Ugyldig base64" };
  }
  if (payloadBytes.byteLength > MAX_SYNC_PAYLOAD_BYTES) {
    return { success: false, eventId: envelope.data.eventId, code: "VALIDATION_ERROR", message: "Payload for stor" };
  }
  try {
    const payload = JSON.parse(new TextDecoder().decode(payloadBytes));
    const parsed = schema.safeParse(payload);
    if (!parsed.success) throw new Error("schema");
    return { success: true, event: { ...envelope.data, payloadJson: parsed.data } };
  } catch {
    return { success: false, eventId: envelope.data.eventId, code: "VALIDATION_ERROR", message: "Ugyldig hendelsespayload" };
  }
}
