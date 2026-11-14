import { assertEquals } from "@std/assert";
import { validateEvent } from "../_shared/sync-contract.ts";

const id = "550e8400-e29b-41d4-a716-446655440000";
function product(nutrientsPer100g: unknown) {
  return validateEvent({ eventId: id, type: "product.upsert", schemaVersion: 1,
    createdAt: "2026-10-12T10:00:00Z",
    payload: btoa(JSON.stringify({ id, name: "Test", source: "user", nutrientsPer100g })) });
}

Deno.test("product nutrients accept partial legacy data without guessing missing values", () => {
  const result = product({ kcal: 100.25 });
  assertEquals(result.success, true);
  if (result.success) {
    assertEquals((result.event.payloadJson as { nutrientsPer100g: unknown }).nutrientsPer100g, { kcal: 100.25 });
  }
  for (const nutrients of [{}, { protein: 0 }, { customNutrient: 0.25 }, { kcal: Number.MAX_VALUE }]) {
    const accepted = product(nutrients);
    assertEquals(accepted.success, true);
    if (accepted.success) {
      assertEquals((accepted.event.payloadJson as { nutrientsPer100g: unknown }).nutrientsPer100g, nutrients);
    }
  }
});

Deno.test("product nutrients reject invalid numeric values and shapes", () => {
  for (const nutrients of [{ kcal: "100" }, { kcal: -1 }, { kcal: null }, { kcal: {} }, { kcal: true }, { kcal: [] }, [], null]) {
    const result = product(nutrients);
    assertEquals(result.success, false);
    if (!result.success) assertEquals(result.code, "VALIDATION_ERROR");
  }
});

Deno.test("product nutrients reject numeric overflow in raw JSON", () => {
  const result = validateEvent({ eventId: id, type: "product.upsert", schemaVersion: 1,
    createdAt: "2026-10-12T10:00:00Z",
    payload: btoa(`{"id":"${id}","name":"Test","source":"user","nutrientsPer100g":{"kcal":1e309}}`) });
  assertEquals(result.success, false);
  if (!result.success) assertEquals(result.code, "VALIDATION_ERROR");
});
