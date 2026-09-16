ALTER TABLE "User"
ADD COLUMN "firstName" TEXT,
ADD COLUMN "lastName" TEXT,
ADD COLUMN "passwordHash" TEXT,
ADD COLUMN "authProvider" TEXT NOT NULL DEFAULT 'email',
ADD COLUMN "deletedAt" TIMESTAMP(3);

CREATE INDEX "User_deletedAt_idx" ON "User"("deletedAt");
