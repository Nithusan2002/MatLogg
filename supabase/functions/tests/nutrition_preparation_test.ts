import { assertEquals } from "@std/assert";
import { validateEvent } from "../_shared/sync-contract.ts";

const id = "550e8400-e29b-41d4-a716-446655440000";
function event(type: string, payload: Record<string, unknown>) {
  return { eventId: id, type, createdAt: "2026-10-12T10:00:00Z", entityId: id,
    schemaVersion: 1, payload: btoa(JSON.stringify(payload)) };
}
const product = { id, name: "Fixture", source: "openfoodfacts", nutrientsPer100g: { kcal: 76 } };
const log = { id, date: "2026-10-12T10:00:00Z", meal: "middag", grams: 200,
  kcal: 152, protein: 3.8, carbs: 21.2, fat: 5.6 };
const item = { id, productId: id, productName: "Fixture", amountG: 200,
  calories: 152, protein: 3.8, carbs: 21.2, fat: 5.6, nutritionSource: "openFoodFacts", sortIndex: 0 };
Deno.test("preparation metadata is validated and preserved for products, logs and meal snapshots", () => {
  for (const preparation of [undefined, "as_sold", "prepared", "unknown", null]) {
    const accepted = preparation === undefined || preparation === "as_sold" || preparation === "prepared";
    for (const [type, payload] of [
      ["product.upsert", { ...product, nutritionPreparation: preparation }],
      ["log.upsert", { ...log, nutritionPreparation: preparation }],
      ["saved_meal.upsert", { id, name: "Fixture meal", updatedAt: "2026-10-12T10:00:00Z",
        items: [{ ...item, nutritionPreparation: preparation }] }],
    ] as const) {
      const result = validateEvent(event(type, payload));
      assertEquals(result.success, accepted);
      if (result.success && preparation !== undefined) {
        const decoded = result.event.payloadJson as {
          nutritionPreparation?: string;
          items?: Array<{ nutritionPreparation?: string }>;
        };
        assertEquals(type === "saved_meal.upsert" ? decoded.items?.[0]?.nutritionPreparation : decoded.nutritionPreparation, preparation);
      }
    }
  }
});
