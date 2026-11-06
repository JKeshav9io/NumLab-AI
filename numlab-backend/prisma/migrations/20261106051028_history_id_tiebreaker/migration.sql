BEGIN;

DROP INDEX "solver_runs_user_id_created_at_idx";

CREATE INDEX "solver_runs_user_id_created_at_id_idx" ON "solver_runs"("user_id", "created_at" DESC, "id" DESC);

COMMIT;
