import { assertEquals } from "@std/assert";
import { MAX_SYNC_EVENTS, validateEvent } from "../_shared/sync-contract.ts";

const id = "550e8400-e29b-41d4-a716-446655440000";
const payload = btoa(JSON.stringify({
  id,
  date: "2026-09-28T10:00:00Z",
  meal: "lunsj",
  grams: 100,
  kcal: 200.5,
  protein: 10,
  carbs: 20,
  fat: 5,
}));

Deno.test("sync v1 accepts the canonical log envelope", () => {
  const result = validateEvent({
    eventId: id,
    type: "log.upsert",
    createdAt: "2026-09-28T10:00:00Z",
    entityId: id,
    schemaVersion: 1,
    payload,
  });
  assertEquals(result.success, true);
  assertEquals(MAX_SYNC_EVENTS, 50);
});

Deno.test("sync rejects unpadded base64", () => {
  let paddedPayload = payload;
  while (!paddedPayload.endsWith("=")) paddedPayload = btoa(`${atob(paddedPayload)} `);
  const result = validateEvent({
    eventId: id,
    type: "log.upsert",
    createdAt: "2026-09-28T10:00:00Z",
    entityId: id,
    schemaVersion: 1,
    payload: paddedPayload.replace(/=+$/, ""),
  });
  assertEquals(result.success, false);
});

Deno.test("sync accepts legacy event aliases", () => {
  const result = validateEvent({
    eventId: id,
    type: "log.create",
    createdAt: "2026-09-28T10:00:00Z",
    entityId: id,
    schemaVersion: 1,
    payload,
  });
  assertEquals(result.success, true);
});

Deno.test("sync rejects an unknown schema version", () => {
  const result = validateEvent({
    eventId: id,
    type: "log.upsert",
    createdAt: "2026-09-28T10:00:00Z",
    entityId: id,
    schemaVersion: 2,
    payload,
  });
  assertEquals(result.success, false);
  if (!result.success) assertEquals(result.code, "UNSUPPORTED_SCHEMA");
});

Deno.test("sync rejects an unknown event type", () => {
  const result = validateEvent({
    eventId: id,
    type: "unknown.event",
    createdAt: "2026-09-28T10:00:00Z",
    entityId: id,
    schemaVersion: 1,
    payload: btoa("{}"),
  });
  assertEquals(result.success, false);
  if (!result.success) assertEquals(result.code, "UNSUPPORTED_TYPE");
});

Deno.test("water events preserve one glass with explicit dates", () => {
  const envelope = {
    eventId: id, type: "water.upsert", createdAt: "2026-09-30T10:00:00Z",
    entityId: id, schemaVersion: 1,
    payload: btoa(JSON.stringify({ id, date: "2026-09-30T10:00:00Z", createdAt: "2026-09-30T10:00:00Z" })),
  };
  assertEquals(validateEvent(envelope).success, true);
  assertEquals(validateEvent({ ...envelope, payload: btoa(JSON.stringify({ id, date: "invalid" })) }).success, false);
  assertEquals(validateEvent({ ...envelope, type: "water.delete", payload: btoa(JSON.stringify({ id })) }).success, true);
});

Deno.test("manual products retain explicit nutrition basis and original serving input", () => {
  const product = {
    id, name: "Skive", source: "user", nutrientsPer100g: { kcal: 300 },
    nutritionBasis: "per100g",
    servings: [{ id, label: "Skive", grams: 40, unit: "g", source: "user", isDefaultSuggestion: true, kind: "portion", shortLabel: "Skive" }],
    manualNutritionInput: { basis: "serving", amount: 40, unit: "g", label: "Skive", calories: 120, protein: 4, carbs: 20, fat: 2 },
  };
  const validate = (body: unknown) => validateEvent({
    eventId: id, type: "product.upsert", createdAt: "2026-10-03T10:00:00Z",
    entityId: id, schemaVersion: 1, payload: btoa(JSON.stringify(body)),
  });
  assertEquals(validate(product).success, true);
  assertEquals(validate({ ...product, nutritionBasis: "perPiece" }).success, false);
  assertEquals(validate({ ...product, manualNutritionInput: { ...product.manualNutritionInput, amount: 0 } }).success, false);
  assertEquals(validate({ id, name: "Legacy", source: "user", nutrientsPer100g: { kcal: 300 } }).success, true);
});
