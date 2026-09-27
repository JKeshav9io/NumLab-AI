-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "email_verified" BOOLEAN NOT NULL DEFAULT false,
    "last_login_at" TIMESTAMPTZ(6),
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "solver_runs" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "method" VARCHAR(100) NOT NULL,
    "input_payload" JSONB NOT NULL,
    "output_payload" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "solver_runs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_explanations" (
    "id" UUID NOT NULL,
    "solver_run_id" UUID NOT NULL,
    "focus_mode" VARCHAR(50) NOT NULL DEFAULT 'steps',
    "prompt_hash" VARCHAR(64) NOT NULL,
    "response_text" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_explanations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_email_idx" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_deleted_at_idx" ON "users"("deleted_at");

-- CreateIndex
CREATE INDEX "solver_runs_user_id_created_at_idx" ON "solver_runs"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "solver_runs_method_idx" ON "solver_runs"("method");

-- CreateIndex
CREATE INDEX "ai_explanations_prompt_hash_idx" ON "ai_explanations"("prompt_hash");

-- CreateIndex
CREATE INDEX "ai_explanations_solver_run_id_idx" ON "ai_explanations"("solver_run_id");

-- CreateIndex
CREATE INDEX "ai_explanations_expires_at_idx" ON "ai_explanations"("expires_at");

-- AddForeignKey
ALTER TABLE "solver_runs" ADD CONSTRAINT "solver_runs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_explanations" ADD CONSTRAINT "ai_explanations_solver_run_id_fkey" FOREIGN KEY ("solver_run_id") REFERENCES "solver_runs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
