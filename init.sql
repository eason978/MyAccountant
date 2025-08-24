-- ----------------------------
-- Enum Types for PostgreSQL
-- ----------------------------
CREATE TYPE "public"."account_type" AS ENUM ('asset', 'liability', 'expense', 'revenue');
CREATE TYPE "public"."split_type" AS ENUM ('debit', 'credit');
CREATE TYPE "public"."import_source_type" AS ENUM ('web_upload', 'line_bot', 'discord_bot', 'email_monitor', 'manual_entry');
CREATE TYPE "public"."job_status" AS ENUM ('pending', 'processing', 'awaiting_user_review', 'completed', 'failed');
CREATE TYPE "public"."raw_transaction_status" AS ENUM ('pending_review', 'processed_and_linked', 'user_skipped');


-- ----------------------------
-- Table Structure
-- ----------------------------

-- Core Tables: 使用者與帳戶設定

CREATE TABLE "public"."users" (
  "id" SERIAL PRIMARY KEY,
  "email" VARCHAR UNIQUE NOT NULL,
  "hashed_password" VARCHAR NOT NULL,
  "name" VARCHAR,
  "currency_preference" VARCHAR(3), -- Default user currency, e.g., TWD
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "public"."currencies" (
  "id" SERIAL PRIMARY KEY,
  "code" VARCHAR(3) UNIQUE NOT NULL, -- e.g., TWD, USD
  "name" VARCHAR NOT NULL, -- e.g., New Taiwan Dollar
  "symbol" VARCHAR(5)
);

CREATE TABLE "public"."accounts" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INT NOT NULL,
  "name" VARCHAR NOT NULL,
  "type" "public"."account_type" NOT NULL,
  "initial_balance" DECIMAL(15, 4) NOT NULL DEFAULT 0,
  "currency_id" INT NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true, -- 可以隱藏不使用的帳戶
  "credit_limit" DECIMAL(15, 4),
  "billing_cycle_day" INT, -- e.g., 15 for 15th of the month
  "payment_due_day" INT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ
);
COMMENT ON TABLE "public"."accounts" IS '不直接儲存 current_balance，它應該由 transaction_splits 動態計算得出，以確保資料一致性。';

-- User-defined Hierarchical Categories

CREATE TABLE "public"."categories" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INT NOT NULL,
  "parent_id" INT, -- Self-referencing for subcategories. NULL for top-level.
  "name" VARCHAR NOT NULL,
  "icon" VARCHAR, -- Icon name or URL for UI
  "color" VARCHAR(7), -- Hex color code for UI
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE "public"."categories" IS '透過 parent_id 實現無限層級的子分類';

-- Automation & Import Pipeline Tables

CREATE TABLE "public"."import_jobs" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INT NOT NULL,
  "source" "public"."import_source_type" NOT NULL,
  "original_filename" VARCHAR,
  "status" "public"."job_status" NOT NULL DEFAULT 'pending',
  "raw_content_path" VARCHAR, -- Path to stored raw file or OCR text
  "error_message" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "completed_at" TIMESTAMPTZ
);

CREATE TABLE "public"."raw_transactions" (
  "id" SERIAL PRIMARY KEY,
  "import_job_id" INT NOT NULL,
  "status" "public"."raw_transaction_status" NOT NULL DEFAULT 'pending_review',
  "raw_date" VARCHAR,
  "raw_description" TEXT,
  "raw_amount" VARCHAR,
  "raw_currency" VARCHAR,
  "raw_source_account" VARCHAR,
  "raw_destination_account" VARCHAR,
  "raw_full_text" TEXT, -- The original line item text
  "duplicate_check_hash" VARCHAR UNIQUE, -- SHA256 hash of key fields to prevent re-importing
  "ai_suggested_description" VARCHAR,
  "ai_suggested_transaction_date" DATE,
  "ai_suggested_amount" DECIMAL(15, 4),
  "ai_suggested_source_account_id" INT,
  "ai_suggested_destination_account_id" INT,
  "ai_suggested_category_id" INT,
  "ai_confidence_score" REAL, -- 0.0 to 1.0
  "ai_suspected_duplicate_of_transaction_id" INT,
  "ai_notes" TEXT,
  "user_overrode_ai" BOOLEAN DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Double-Entry Bookkeeping Core

CREATE TABLE "public"."transactions" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INT NOT NULL,
  "description" VARCHAR NOT NULL, -- 使用者看到的主要描述，e.g., "7-11 購物"
  "transaction_date" TIMESTAMPTZ NOT NULL, -- 交易發生的日期與時間
  "notes" TEXT, -- 更詳細的備註
  "raw_transaction_id" INT, -- 標示此交易是由哪個原始匯入項目生成的
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ
);

CREATE TABLE "public"."transaction_splits" (
  "id" SERIAL PRIMARY KEY,
  "transaction_id" INT NOT NULL,
  "account_id" INT NOT NULL, -- 資金從哪個帳戶流動
  "category_id" INT, -- 使用者定義的分類，主要用於支出/收入帳戶的標記
  "type" "public"."split_type" NOT NULL,
  "amount" DECIMAL(15, 4) NOT NULL, -- Always positive. Type determines direction.
  "foreign_currency_id" INT,
  "foreign_amount" DECIMAL(15, 4),
  "exchange_rate" DECIMAL(15, 6)
);
COMMENT ON TABLE "public"."transaction_splits" IS '一筆交易中，所有debit的amount總和必須等於所有credit的amount總和';

-- Rules Engine for Automation

CREATE TABLE "public"."automation_rules" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INT NOT NULL,
  "priority" INT NOT NULL DEFAULT 0, -- Lower number runs first
  "condition_field" VARCHAR NOT NULL, -- e.g., "raw_description"
  "condition_operator" VARCHAR NOT NULL, -- e.g., "contains", "equals"
  "condition_value" VARCHAR NOT NULL,
  "action_field" VARCHAR NOT NULL, -- e.g., "set_category", "set_destination_account"
  "action_value_id" INT NOT NULL, -- e.g., the ID of a category or account
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ----------------------------
-- Foreign Key Constraints
-- ----------------------------
ALTER TABLE "public"."accounts" ADD CONSTRAINT "fk_accounts_user" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE CASCADE;
ALTER TABLE "public"."accounts" ADD CONSTRAINT "fk_accounts_currency" FOREIGN KEY ("currency_id") REFERENCES "public"."currencies" ("id") ON DELETE RESTRICT;

ALTER TABLE "public"."categories" ADD CONSTRAINT "fk_categories_user" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE CASCADE;
ALTER TABLE "public"."categories" ADD CONSTRAINT "fk_categories_parent" FOREIGN KEY ("parent_id") REFERENCES "public"."categories" ("id") ON DELETE SET NULL;

ALTER TABLE "public"."import_jobs" ADD CONSTRAINT "fk_import_jobs_user" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE CASCADE;

ALTER TABLE "public"."raw_transactions" ADD CONSTRAINT "fk_raw_transactions_import_job" FOREIGN KEY ("import_job_id") REFERENCES "public"."import_jobs" ("id") ON DELETE CASCADE;
ALTER TABLE "public"."raw_transactions" ADD CONSTRAINT "fk_raw_transactions_suggested_source_account" FOREIGN KEY ("ai_suggested_source_account_id") REFERENCES "public"."accounts" ("id") ON DELETE SET NULL;
ALTER TABLE "public"."raw_transactions" ADD CONSTRAINT "fk_raw_transactions_suggested_dest_account" FOREIGN KEY ("ai_suggested_destination_account_id") REFERENCES "public"."accounts" ("id") ON DELETE SET NULL;
ALTER TABLE "public"."raw_transactions" ADD CONSTRAINT "fk_raw_transactions_suggested_category" FOREIGN KEY ("ai_suggested_category_id") REFERENCES "public"."categories" ("id") ON DELETE SET NULL;
ALTER TABLE "public"."raw_transactions" ADD CONSTRAINT "fk_raw_transactions_suspected_duplicate" FOREIGN KEY ("ai_suspected_duplicate_of_transaction_id") REFERENCES "public"."transactions" ("id") ON DELETE SET NULL;

ALTER TABLE "public"."transactions" ADD CONSTRAINT "fk_transactions_user" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE CASCADE;
ALTER TABLE "public"."transactions" ADD CONSTRAINT "fk_transactions_raw_transaction" FOREIGN KEY ("raw_transaction_id") REFERENCES "public"."raw_transactions" ("id") ON DELETE SET NULL;

ALTER TABLE "public"."transaction_splits" ADD CONSTRAINT "fk_transaction_splits_transaction" FOREIGN KEY ("transaction_id") REFERENCES "public"."transactions" ("id") ON DELETE CASCADE;
ALTER TABLE "public"."transaction_splits" ADD CONSTRAINT "fk_transaction_splits_account" FOREIGN KEY ("account_id") REFERENCES "public"."accounts" ("id") ON DELETE CASCADE;
ALTER TABLE "public"."transaction_splits" ADD CONSTRAINT "fk_transaction_splits_category" FOREIGN KEY ("category_id") REFERENCES "public"."categories" ("id") ON DELETE SET NULL;
ALTER TABLE "public"."transaction_splits" ADD CONSTRAINT "fk_transaction_splits_foreign_currency" FOREIGN KEY ("foreign_currency_id") REFERENCES "public"."currencies" ("id") ON DELETE RESTRICT;

ALTER TABLE "public"."automation_rules" ADD CONSTRAINT "fk_automation_rules_user" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON DELETE CASCADE;


-- ----------------------------
-- Indexes
-- ----------------------------
CREATE UNIQUE INDEX "idx_categories_user_parent_name" ON "public"."categories" ("user_id", "parent_id", "name");

CREATE INDEX "idx_transactions_user_id" ON "public"."transactions" ("user_id");
CREATE INDEX "idx_transactions_transaction_date" ON "public"."transactions" ("transaction_date" DESC);

CREATE INDEX "idx_transaction_splits_transaction_id" ON "public"."transaction_splits" ("transaction_id");
CREATE INDEX "idx_transaction_splits_account_id" ON "public"."transaction_splits" ("account_id");
CREATE INDEX "idx_transaction_splits_category_id" ON "public"."transaction_splits" ("category_id");