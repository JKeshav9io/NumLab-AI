-- AlterTable
ALTER TABLE "ai_explanations" ADD COLUMN     "user_id" UUID;

-- CreateIndex
CREATE INDEX "ai_explanations_user_id_idx" ON "ai_explanations"("user_id");

-- AddForeignKey
ALTER TABLE "ai_explanations" ADD CONSTRAINT "ai_explanations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
