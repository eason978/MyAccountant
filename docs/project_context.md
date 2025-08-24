# AI 指導手冊 (Project Context)

本文件為 AI 程式碼助理（例如 Gemini Code Assist）提供完整的專案背景、架構和規範，以確保生成一致、高品質且符合專案需求的程式碼。

## 1. 專案概覽 (Project Overview)

- **專案名稱:** Intelligent Accountant (智能記帳軟體)
- **核心目標:** 開發一個由 AI 驅動的智能記帳 Web 應用程式。
- **核心記帳法:** 採用會計學中的「複式記帳法 (Double-Entry Bookkeeping)」。
- **關鍵功能:**
    - 自動化交易匯入：支援從不同來源（檔案上傳、LINE Bot、Email 等）匯入原始交易紀錄。
    - AI 智能分析：AI 會自動解析原始紀錄，建議分類、描述、日期和對應帳戶。
    - 使用者審核流程：所有 AI 處理過的交易都需要經過使用者最終確認，才能正式入帳。
    - 自訂規則引擎：使用者可以建立規則，以自動化處理特定模式的交易。
    - 彈性的分類與帳戶管理。

## 2. 技術棧 (Technology Stack)

| 類別 | 技術 | 用途與備註 |
| :--- | :--- | :--- |
| **開發環境** | Windows 11 | 主要開發操作系統 |
| **後端** | Python 3.11+, FastAPI | 提供 RESTful API |
| **前端** | Vue 3, Vite, TypeScript | 建立響應式使用者介面 |
| **資料庫** | PostgreSQL | 核心資料儲存 |
| **容器化** | Docker | 用於開發環境一致性與部署打包 |
| **後端部署** | Google Cloud Run | Serverless 平台，用於運行後端 Docker 容器 |
| **前端部署** | Netlify | 用於託管和部署靜態前端應用程式 |

## 3. 系統架構 (System Architecture)

- **前端 (Vue/Vite):** 部署在 Netlify。使用者透過瀏覽器與前端互動，前端透過呼叫後端 API 來存取資料和執行操作。
- **後端 (FastAPI):** 打包成 Docker 映像檔並部署在 GCP Cloud Run。負責處理所有業務邏輯、資料庫互動和 AI 分析任務。
- **資料庫 (PostgreSQL):** 獨立的資料庫服務，後端應用程式會連接到此資料庫。
- **資料流:** `使用者 -> Netlify (Vue App) -> GCP Cloud Run (FastAPI API) -> PostgreSQL`

## 4. 檔案與目錄結構 (File & Directory Structure)

請嚴格遵守以下目錄結構。所有新檔案都應放置在對應的目錄下。

```
intelligent_accountant/
├── backend/                # 後端 FastAPI 應用程式
│   ├── app/
│   │   ├── api/            # API 端點 (Routers)
│   │   ├── core/           # 核心設定、配置
│   │   ├── crud/           # 資料庫 CRUD 操作
│   │   ├── models/         # SQLAlchemy 模型
│   │   ├── schemas/        # Pydantic 資料驗證模型
│   │   └── services/       # 業務邏輯服務
│   ├── main.py             # FastAPI 應用程式入口
│   ├── README.md
│   ├── SPEC.md
│   └── TESTING.md
├── frontend/               # 前端 Vue 應用程式
│   ├── src/
│   │   ├── assets/
│   │   ├── components/     # 可重用 Vue 元件
│   │   ├── views/          # 頁面級元件
│   │   ├── router/
│   │   ├── services/       # API 呼叫服務
│   │   └── stores/         # Pinia 狀態管理
│   ├── README.md
│   ├── SPEC.md
│   └── TESTING.md
├── docs/                   # 專案文件
│   ├── OVERVIEW.md
│   └── project_context.md  # (本文件)
├── tests/                  # 測試程式碼
│   ├── backend/
│   └── frontend/
└── README.md
```

## 5. 資料庫結構 (Database Schema)

資料庫採用 PostgreSQL，並使用以下 DBML (Database Markup Language) 定義的結構。

**核心概念:**
- **複式記帳:** `transactions` 表紀錄一筆交易的元數據，而 `transaction_splits` 表則詳細記錄該交易如何影響不同 `accounts`。**一筆交易中，所有借方(debit)分錄的總金額必須等於所有貸方(credit)分錄的總金額。**
- **動態餘額:** `accounts` 表不直接儲存當前餘額 (`current_balance`)。餘額應隨時透過計算相關 `transaction_splits` 的總和來動態得出，以確保資料的絕對一致性。
- **自動化管線:** 原始資料透過 `import_jobs` 進入系統，解析成 `raw_transactions`。AI 豐富化這些原始交易後，等待使用者審核。審核通過後，才會轉換為正式的 `transactions` 和 `transaction_splits`。

```dbml
Project intelligent_accountant {
  database_type: 'PostgreSQL'
  Note: '這是一個專為 AI 驅動的智能記帳軟體設計的資料庫結構，核心採用複式記帳法，並為自動化流程設計了暫存與審核機制。'
}

// ---------- Enums for consistency ----------

Enum account_type {
  asset // 資產 (現金、銀行存款、電子支付)
  liability // 負債 (信用卡、貸款)
  expense // 支出 (餐飲、交通)
  revenue // 收入 (薪資、投資)
}

Enum split_type {
  debit // 借方 (資產增加、負債減少、支出增加)
  credit // 貸方 (資產減少、負債增加、收入增加)
}

Enum import_source_type {
  web_upload
  line_bot
  discord_bot
  email_monitor
  manual_entry
}

Enum job_status {
  pending
  processing
  awaiting_user_review
  completed
  failed
}

Enum raw_transaction_status {
  pending_review
  processed_and_linked
  user_skipped
}


// ---------- Core Tables: 使用者與帳戶設定 ----------

Table users {
  id integer [pk, increment]
  email varchar [unique, not null]
  hashed_password varchar [not null]
  name varchar
  currency_preference varchar(3) [note: 'Default user currency, e.g., TWD']
  created_at timestamp [default: `now()`]
}

Table accounts {
  id integer [pk, increment]
  user_id integer [not null, ref: > users.id]
  name varchar [not null]
  type account_type [not null]
  initial_balance decimal(15, 4) [not null, default: 0]
  currency_id integer [not null, ref: > currencies.id]
  is_active boolean [not null, default: true, note: '可以隱藏不使用的帳戶']
  
  // For liability accounts like credit cards
  credit_limit decimal(15, 4)
  billing_cycle_day int [note: 'e.g., 15 for 15th of the month']
  payment_due_day int
  
  created_at timestamp [default: `now()`]
  updated_at timestamp
  
  Note: '不直接儲存 current_balance，它應該由 transaction_splits 動態計算得出，以確保資料一致性。'
}

Table currencies {
  id integer [pk, increment]
  code varchar(3) [unique, not null, note: 'e.g., TWD, USD']
  name varchar [not null, note: 'e.g., New Taiwan Dollar']
  symbol varchar(5)
}

// ---------- User-defined Hierarchical Categories ----------

Table categories {
  id integer [pk, increment]
  user_id integer [not null, ref: > users.id]
  parent_id integer [ref: > categories.id, note: 'Self-referencing for subcategories. NULL for top-level.']
  name varchar [not null]
  icon varchar [note: 'Icon name or URL for UI']
  color varchar(7) [note: 'Hex color code for UI']
  
  created_at timestamp [default: `now()`]
  
  indexes {
    (user_id, parent_id, name) [unique]
  }
  Note: '透過 parent_id 實現無限層級的子分類'
}


// ---------- Double-Entry Bookkeeping Core ----------

Table transactions {
  id integer [pk, increment]
  user_id integer [not null, ref: > users.id]
  description varchar [not null, note: '使用者看到的主要描述，e.g., "7-11 購物"']
  transaction_date timestamp [not null, note: '交易發生的日期與時間']
  notes text [note: '更詳細的備註']
  
  // Link back to the automation source
  raw_transaction_id integer [ref: > raw_transactions.id, note: '標示此交易是由哪個原始匯入項目生成的']

  created_at timestamp [default: `now()`]
  updated_at timestamp
  
  indexes {
    user_id
    transaction_date
  }
}

Table transaction_splits {
  id integer [pk, increment]
  transaction_id integer [not null, ref: > transactions.id]
  account_id integer [not null, ref: > accounts.id, note: '資金從哪個帳戶流動']
  category_id integer [ref: > categories.id, note: '使用者定義的分類，主要用於支出/收入帳戶的標記']
  type split_type [not null]
  amount decimal(15, 4) [not null, note: 'Always positive. Type determines direction.']
  
  // Multi-currency support
  foreign_currency_id integer [ref: > currencies.id]
  foreign_amount decimal(15, 4)
  exchange_rate decimal(15, 6)

  indexes {
    transaction_id
    account_id
    category_id
  }
  Note: '一筆交易中，所有debit的amount總和必須等於所有credit的amount總和'
}


// ---------- Automation & Import Pipeline Tables ----------

Table import_jobs {
  id integer [pk, increment]
  user_id integer [not null, ref: > users.id]
  source import_source_type [not null]
  original_filename varchar
  status job_status [not null, default: 'pending']
  raw_content_path varchar [note: 'Path to stored raw file or OCR text']
  error_message text
  
  created_at timestamp [default: `now()`]
  completed_at timestamp
}

Table raw_transactions {
  id integer [pk, increment]
  import_job_id integer [not null, ref: > import_jobs.id]
  status raw_transaction_status [not null, default: 'pending_review']

  // Raw data from OCR/AI (the JSON object)
  raw_date varchar
  raw_description text
  raw_amount varchar
  raw_currency varchar
  raw_source_account varchar
  raw_destination_account varchar
  raw_full_text text [note: 'The original line item text']
  duplicate_check_hash varchar [unique, note: 'SHA256 hash of key fields to prevent re-importing']

  // AI enrichment fields
  ai_suggested_description varchar
  ai_suggested_transaction_date date
  ai_suggested_amount decimal(15, 4)
  ai_suggested_source_account_id integer [ref: > accounts.id]
  ai_suggested_destination_account_id integer [ref: > accounts.id]
  ai_suggested_category_id integer [ref: > categories.id]
  ai_confidence_score float [note: '0.0 to 1.0']
  ai_suspected_duplicate_of_transaction_id integer [ref: > transactions.id]
  ai_notes text
  
  user_overrode_ai boolean [default: false]
  
  created_at timestamp [default: `now()`]
}


// ---------- Rules Engine for Automation ----------

Table automation_rules {
  id integer [pk, increment]
  user_id integer [not null, ref: > users.id]
  priority integer [not null, default: 0, note: 'Lower number runs first']
  
  // Condition
  condition_field varchar [not null, note: 'e.g., "raw_description"']
  condition_operator varchar [not null, note: 'e.g., "contains", "equals"']
  condition_value varchar [not null]
  
  // Action
  action_field varchar [not null, note: 'e.g., "set_category", "set_destination_account"']
  action_value_id integer [not null, note: 'e.g., the ID of a category or account']

  is_active boolean [not null, default: true]
  created_at timestamp [default: `now()`]
}
```

## 6. API 設計規範 (API Design)

- **風格:** 嚴格遵守 RESTful 設計原則。
- **格式:** 所有請求和回應的主體 (body) 均使用 JSON 格式。
- **端點 (Endpoints):**
    - 使用複數名詞來命名資源，例如 `/users`, `/accounts`, `/transactions`。
    - 使用標準 HTTP 方法:
        - `GET`: 讀取資源。
        - `POST`: 建立新資源。
        - `PUT` / `PATCH`: 更新現有資源。
        - `DELETE`: 刪除資源。
- **路徑參數:** 使用路徑來識別特定資源，例如 `GET /users/{user_id}`。
- **錯誤處理:** 使用標準的 HTTP 狀態碼來表示成功或失敗（例如 `200 OK`, `201 Created`, `400 Bad Request`, `404 Not Found`）。錯誤回應應包含一個 `detail` 欄位來描述錯誤原因。

## 7. 程式碼風格與慣例 (Coding Style & Conventions)

- **通用:**
    - 註解應清晰明瞭，必要時使用英文或中文。
    - 遵循 Don't Repeat Yourself (DRY) 原則。
- **後端 (Python / FastAPI):**
    - **風格:** 遵循 PEP 8。
    - **命名:** 變數、函式、模組使用 `snake_case` (小寫蛇形命名法)。類別使用 `PascalCase` (大駝峰命名法)。
    - **型別提示 (Type Hinting):** 所有函式簽名和變數都應盡可能加上型別提示。
    - **資料驗證:** 使用 Pydantic (`schemas/`) 來定義 API 的請求和回應模型，進行嚴格的資料驗證。
    - **資料庫操作:** 使用 SQLAlchemy Core 或 ORM (`models/`, `crud/`) 進行資料庫互動。
- **前端 (JavaScript / TypeScript / Vue):**
    - **風格:** 使用 Prettier 進行自動程式碼格式化。
    - **命名:** 變數和函式使用 `camelCase` (小駝峰命名法)。元件名稱使用 `PascalCase` (例如 `UserProfile.vue`)。
    - **Vue:**
        - 優先使用 Composition API 搭配 `<script setup>` 語法。
        - 使用 Pinia 進行全域狀態管理。
        - 元件應保持小而專一。
    - **TypeScript:** 盡可能使用 TypeScript 並為所有變數、函式參數和回傳值定義明確的型別。