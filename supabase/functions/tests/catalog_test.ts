import { assertEquals } from "@std/assert";
import {
  isValidGTIN,
  normalizeCatalogText,
  nutrients,
} from "../_shared/catalog.ts";

Deno.test("normalizes Norwegian catalog names deterministically", () => {
  assertEquals(
    normalizeCatalogText("  Pålegg—Økologisk! "),
    "palegg økologisk",
  );
});

Deno.test("validates GTIN check digits", () => {
  assertEquals(isValidGTIN("7038010054822"), true);
  assertEquals(isValidGTIN("7038010054821"), false);
  assertEquals(isValidGTIN("123"), false);
});

Deno.test("rejects impossible required macro totals", () => {
  assertEquals(
    nutrients.safeParse({ kcal: 500, protein: 50, carbs: 50, fat: 10 }).success,
    false,
  );
  assertEquals(
    nutrients.safeParse({ kcal: 250, protein: 10, carbs: 30, fat: 5 }).success,
    true,
  );
});
