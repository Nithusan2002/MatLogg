ALTER TABLE "Log"
ADD COLUMN "unit" TEXT NOT NULL DEFAULT 'g';

ALTER TABLE "SavedMealItem"
ADD COLUMN "unit" TEXT NOT NULL DEFAULT 'g';

ALTER TABLE "Log"
ADD CONSTRAINT "Log_unit_check" CHECK ("unit" IN ('g', 'ml'));

ALTER TABLE "SavedMealItem"
ADD CONSTRAINT "SavedMealItem_unit_check" CHECK ("unit" IN ('g', 'ml'));
