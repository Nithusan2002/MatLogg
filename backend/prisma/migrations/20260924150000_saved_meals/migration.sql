CREATE TABLE "SavedMeal" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "suggestedMealType" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SavedMeal_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SavedMealItem" (
    "id" TEXT NOT NULL,
    "savedMealId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "productName" TEXT NOT NULL,
    "grams" DOUBLE PRECISION NOT NULL,
    "kcal" INTEGER NOT NULL,
    "protein" DOUBLE PRECISION NOT NULL,
    "carbs" DOUBLE PRECISION NOT NULL,
    "fat" DOUBLE PRECISION NOT NULL,
    "nutritionSource" TEXT NOT NULL,
    "sortIndex" INTEGER NOT NULL,
    CONSTRAINT "SavedMealItem_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "SavedMeal_userId_updatedAt_idx" ON "SavedMeal"("userId", "updatedAt");
CREATE INDEX "SavedMealItem_savedMealId_sortIndex_idx" ON "SavedMealItem"("savedMealId", "sortIndex");

ALTER TABLE "SavedMeal"
ADD CONSTRAINT "SavedMeal_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SavedMealItem"
ADD CONSTRAINT "SavedMealItem_savedMealId_fkey" FOREIGN KEY ("savedMealId") REFERENCES "SavedMeal"("id") ON DELETE CASCADE ON UPDATE CASCADE;
