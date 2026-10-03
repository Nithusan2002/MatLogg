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

const portion = {
  servingId: "550e8400-e29b-81d4-a716-446655440001",
  label: "Polarbrød", count: 2, amountPerServing: 37.5,
  unit: "g", source: "openFoodFacts", kind: "piece",
};
function portionEvent(extra: Record<string, unknown>) {
  return validateEvent({
    eventId: id, type: "log.upsert", createdAt: "2026-10-02T10:00:00Z", schemaVersion: 1,
    payload: btoa(String.fromCharCode(...new TextEncoder().encode(JSON.stringify({ id, date: "2026-10-02T10:00:00Z", meal: "lunsj", grams: 75,
      kcal: 195, protein: 7.5, carbs: 30, fat: 3, ...extra })))),
  });
}
Deno.test("portion snapshot survives validation including deterministic UUID", () => {
  const result = portionEvent({ portionSelection: portion });
  assertEquals(result.success, true);
  if (result.success) assertEquals((result.event.payloadJson as Record<string, unknown>).portionSelection, portion);
});
Deno.test("portion rejects mismatch, invalid count, unit and kind", () => {
  for (const patch of [{ count: 3 }, { count: 0 }, { unit: "ml" }, { kind: "baseAmount" }, { amountPerServing: 1e308 }]) {
    assertEquals(portionEvent({ portionSelection: { ...portion, ...patch } }).success, false);
  }
});
Deno.test("portion null is an explicit clear; legacy field absence stays absent", () => {
  const cleared = portionEvent({ portionSelection: null });
  const legacy = portionEvent({});
  assertEquals(cleared.success, true);
  assertEquals(legacy.success, true);
  if (cleared.success) assertEquals((cleared.event.payloadJson as Record<string, unknown>).portionSelection, null);
  if (legacy.success) assertEquals(Object.hasOwn(legacy.event.payloadJson as object, "portionSelection"), false);
});

Deno.test("saved meal portion metadata validates and retains UTF8 labels", () => {
  const item = { id, productId: id, productName: "Fixture", amountG: 75, amountUnit: "g",
    calories: 195, protein: 7.5, carbs: 30, fat: 3, nutritionSource: "openFoodFacts", sortIndex: 0,
    portionSelection: portion };
  function event(value: unknown) {
    return validateEvent({ eventId: id, type: "saved_meal.upsert", createdAt: "2026-10-02T10:00:00Z", schemaVersion: 1,
      payload: btoa(String.fromCharCode(...new TextEncoder().encode(JSON.stringify({ id, name: "Fixture",
        updatedAt: "2026-10-02T10:00:00Z", items: [value] })))) });
  }
  const result = event(item);
  assertEquals(result.success, true);
  if (result.success) assertEquals((result.event.payloadJson as { items: unknown[] }).items[0], item);
  assertEquals(event({ ...item, amountUnit: "ml" }).success, false);
  assertEquals(event({ ...item, amountG: 100 }).success, false);
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
