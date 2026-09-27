-- Preserve calculated energy until presentation instead of rounding each log item.
ALTER TABLE "Log"
ALTER COLUMN "kcal" TYPE DOUBLE PRECISION USING "kcal"::DOUBLE PRECISION;

ALTER TABLE "SavedMealItem"
ALTER COLUMN "kcal" TYPE DOUBLE PRECISION USING "kcal"::DOUBLE PRECISION;
