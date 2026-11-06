BEGIN;

ALTER TABLE "solver_runs" ADD COLUMN     "summary_payload" JSONB NOT NULL DEFAULT '{}';

UPDATE "solver_runs"
SET "summary_payload" = jsonb_build_object(
  'method', COALESCE("output_payload"->>'method', "method"),
  'status', "output_payload"->>'status',
  'equation', LEFT(COALESCE("input_payload"->>'equation', ''), 120)
);

COMMIT;
