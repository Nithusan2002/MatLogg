import { assertEquals } from "@std/assert";
import { validateEvent } from "../_shared/sync-contract.ts";

const id = "550e8400-e29b-41d4-a716-446655440000";
function validate(extra: Record<string, unknown>) {
  return validateEvent({ eventId: id, type: "product.upsert", schemaVersion: 1,
    createdAt: "2026-11-06T10:00:00Z", payload: btoa(JSON.stringify({
      id, name: "Synthetic product", source: "user", nutrientsPer100g: { kcal: 100 }, ...extra,
    })) });
}
Deno.test("visual groups preserve omission, explicit null and all stable IDs", () => {
  for (const extra of [{}, { selectedFoodGroup: null }, ...[
    "rice_pasta", "bread", "grain", "meat", "poultry", "fish", "egg", "dairy", "cheese",
    "oil_fat", "fruit", "vegetables", "nuts", "drinks", "other",
  ].map((selectedFoodGroup) => ({ selectedFoodGroup }))]) {
    const result = validate(extra);
    assertEquals(result.success, true);
    if (result.success) {
      const payload = result.event.payloadJson as Record<string, unknown>;
      assertEquals(Object.hasOwn(payload, "selectedFoodGroup"), Object.hasOwn(extra, "selectedFoodGroup"));
      assertEquals(payload.selectedFoodGroup, (extra as Record<string, unknown>).selectedFoodGroup);
    }
  }
});
Deno.test("invalid visual groups are rejected at the Edge boundary", () => {
  for (const selectedFoodGroup of ["unknown", "", "meat ", 1, {}, [], true]) {
    assertEquals(validate({ selectedFoodGroup }).success, false);
  }
});
