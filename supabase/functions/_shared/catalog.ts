import { z } from "zod";

export const uuid = z.string().uuid();
export const nutritionBasis = z.enum(["per100g", "per100ml"]);
export const nutrients = z.object({
  kcal: z.number().finite().min(0).max(900),
  protein: z.number().finite().min(0).max(100),
  carbs: z.number().finite().min(0).max(100),
  fat: z.number().finite().min(0).max(100),
  saturatedFat: z.number().finite().min(0).max(100).nullable().optional(),
  sugars: z.number().finite().min(0).max(100).nullable().optional(),
  fiber: z.number().finite().min(0).max(100).nullable().optional(),
  salt: z.number().finite().min(0).max(100).nullable().optional(),
  sodium: z.number().finite().min(0).max(100).nullable().optional(),
}).refine(
  (value) => value.protein + value.carbs + value.fat <= 100,
  "Makroer overstiger 100",
);

export function normalizeCatalogText(value: string): string {
  return value.normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("nb-NO")
    .replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

export function isValidGTIN(value: string): boolean {
  if (!/^\d{8,14}$/.test(value)) return false;
  const digits = [...value].map(Number);
  const check = digits.pop()!;
  const sum = digits.reverse().reduce(
    (total, digit, index) => total + digit * (index % 2 === 0 ? 3 : 1),
    0,
  );
  return (10 - (sum % 10)) % 10 === check;
}

export function requestSubject(request: Request): string {
  const forwarded =
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  return forwarded.slice(0, 128);
}
