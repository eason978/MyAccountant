# 智能記帳軟體開發設計規格書

**版本:** 1.0  
**日期:** 2025-08-21

## 0. 技術棧
- 後端：FastAPI, Python 3.11+
- 前端：Vue 3, TypeScript
- 資料庫：PostgreSQL
- 部署：Docker, Kubernetes

## 1. 軟體需求 (Software Requirement)

### 1.1 系統目標 (System Goal)
開發一套以自動化為核心的智能記帳軟體。系統需能解析使用者上傳的銀行對帳單、信用卡帳單等文件，透過 AI 輔助自動完成記帳，並提供多樣化的操作介面（Web, Chatbot）。系統後端需基於嚴謹的複式記帳法，並能與開源記帳軟體 Firefly III 進行串接。

### 1.2 使用者場景 (User Scenarios)

#### 手機端
- 使用者透過響應式網頁 (RWD) 或專屬 App，快速手動記錄一筆開銷。
- 使用者透過 LINE 或 Discord Bot，上傳一張信用卡帳單的截圖，系統自動解析並提示使用者確認。
- 使用者透過 Bot 下達指令，查詢上個月的餐飲支出總額。

#### 電腦端
- 使用者登入網頁，批次上傳過去一年的銀行 PDF 對帳單，系統在背景進行處理。
- 處理完成後，使用者在網頁的「待審核區」一次性確認數筆 AI 無法百分之百確定的交易分類。
- 使用者在網頁上設定自動化規則，例如「所有包含『捷運』的交易都自動分類到『交通-大眾運輸』」。

### 1.3 核心功能需求 (Core Functional Requirements)

#### 自動化記帳
- **多源匯入:** 支援從 PDF、PNG、JPG 格式的銀行/信用卡對帳單、電子支付交易紀錄中匯入。
- **智能解析:** 具備 OCR 及 AI 自然語言理解能力，從非結構化資料中提取交易日期、金額、商家、摘要等關鍵資訊。
- **自動分類:** 系統能基於使用者自訂的規則，或根據歷史交易數據，由 AI 推薦並設定交易的分類。
- **重複偵測:** 系統能標示出可能重複匯入的交易，防止重複記帳。

#### 手動與輔助記帳
- 提供完整的 CRUD (Create, Read, Update, Delete) 功能，用於手動管理交易。
- 支援收入、支出、轉帳三種交易類型。
- 支援多帳戶、多幣種記帳。
- 支援層級式分類（主分類/子分類）。

#### 核心記帳邏輯
- 底層必須採用複式記帳法 (Double-entry Bookkeeping)，確保帳務的準確性與平衡。

### 1.4 非功能性需求 (Non-Functional Requirements)

#### 部署與平台
- **雲端優先:** 優先部署於 Google Cloud Platform (GCP)。
- **Serverless 架構:** 應用後端應採用 Cloud Run 進行容器化部署，以實現「縮減至零」節省成本。
- **資料庫:** 必須使用關聯式資料庫 (Cloud SQL for PostgreSQL) 以確保資料的完整性與交易的 ACID特性。

#### 效能
- 系統應能處理非同步的長時間任務（如批次 OCR），並在完成時通知使用者。
- 日常 API 請求應在 500ms 內回應。

#### 安全性
- 使用者憑證（密碼、外部服務 API Key、Email App Password）在資料庫中必須使用強加密儲存。
- 所有使用者上傳的檔案應有嚴格的存取權限控制。

#### 可維護性
- 系統應採用模組化、低耦合的設計，便於獨立開發、測試與升級。

### 1.5 支援介面 (Supported Interfaces)
- **Web:** 響應式網頁 (RWD)，適配電腦與行動裝置。
- **Chatbot:** LINE Bot, Discord Bot。
- **自動化:** Email 監控匯入。

## 2. 軟體架構設計與元件拆解 (Software Architecture Design and Component Decompose)

### 2.1 架構原則 (Architectural Principles)
- **分層架構:** 明確劃分介面層 (IO Layer)、業務邏輯層 (Business Logic Layer) 與 資料存取層 (Data Access Layer)。
- **非同步事件驅動:** 檔案上傳、信件接收等觸發的自動化流程，應作為非同步任務來處理，避免阻塞主應用。
- **資料庫為核心:** 以 Cloud SQL 為唯一信任的資料來源 (Single Source of Truth)，所有操作都必須確保資料庫的交易一致性。
- **介面與邏輯分離:** IO 元件僅負責資料的接收與呈現，不應包含複雜的業務邏輯。

### 2.2 系統架構流程圖 (System Architecture Flow)

```text
[User] --> [IO Layer] --> [Business Logic Layer] --> [Data Access Layer] --> [Data Store]
   ^            |                  |                        |                  |
   |------------+------------------+------------------------+------------------+
   (Feedback & Display)

IO Layer: io-web, io-chatbot, io-mail_monitor
Business Logic Layer: data_processor (Orchestrator), document_processor, ai_agent, uOperator
Data Access Layer: ifQuery
Data Store: Cloud SQL (PostgreSQL), Firefly III API
```

### 2.3 元件拆解與職責 (Component Decomposition & Responsibilities)
- **io-web:** 負責所有 Web UI 的互動，提供圖形化操作介面。
- **io-chatbot:** 負責 LINE/Discord 的訊息互動，提供指令式操作介面。
- **io-mail_monitor:** 負責監控指定信箱，觸發自動匯入流程。
- **document_processor:** 負責將圖片與 PDF 文件轉換為純文字（OCR）。
- **ai_agent:** 負責解析純文字，提取交易資訊並輸出為結構化 JSON。
- **data_processor:** 流程協調器，接收來自 IO 層的請求，調度 document_processor 和 ai_agent。
- **uOperator:** 記帳操作器，負責驗證資料、應用規則、處理使用者互動，並最終執行記帳。
- **ifQuery:** 資料存取抽象層，隔離業務邏輯與實際的資料庫操作。

## 3. 軟體元件設計 (Software Component Design)

### 3.1 io-web
- **主要職責:** 提供功能完整且友善的圖形化介面。
- **輸入:** 使用者的 HTTP 請求 (點擊、表單提交、檔案上傳)。
- **輸出:** HTML/CSS/JavaScript 頁面，JSON API 回應。
- **核心邏輯:**
  - 實現使用者註冊、登入與身份驗證 (JWT)。
  - 提供手動記帳表單。
  - 提供儀表板與各類財務報表（與 MOZE UI/UX 看齊）。
  - 實現檔案上傳介面，支援拖拽與進度條顯示。
  - 提供「待審核交易」管理介面，讓使用者可以批次確認或修改 AI 解析的結果。
  - 提供 `automation_rules` 的設定介面。
  - 必須採用 RWD 設計，確保在手機瀏覽器上也有良好的體驗。
- **測試重點:**
  - **單元測試：** 表單驗證邏輯。
  - **整合測試：** 測試檔案上傳 API 是否能成功觸發後端流程。
  - **E2E 測試：** 模擬使用者從登入到完成一筆手動記帳的完整流程。

### 3.2 io-chatbot
- **主要職責:** 提供基於文字指令的快速記帳與查詢介面。
- **輸入:** LINE/Discord Webhook 事件 (文字訊息、圖片訊息)。
- **輸出:** 回應給 LINE/Discord API 的訊息封包 (文字、按鈕模板)。
- **核心邏輯:**
  - 串接 LINE Messaging API 與 Discord Bot API。
  - 設計一套 CLI 風格的指令系統 (e.g., `spend 50 coffee`, `search food last month`)。
  - 當收到圖片/檔案時，確認檔案類型後，將其傳遞給 `data_processor` 處理。
  - 當後端（`uOperator`）需要使用者互動時（如輸入 PDF 密碼、確認分類），能夠管理對話狀態，並向使用者發出提問。
  - 選項應以數字編號呈現，方便使用者快速回覆。
- **測試重點:**
  - **單元測試：** 測試指令解析器的正確性。
  - **整合測試：** 測試接收圖片後是否能正確呼叫後端 API。
  - **E2E 測試：** 模擬在 LINE 中上傳一張帳單截圖，並根據 Bot 的提示完成所有確認步驟，最終驗證資料庫中是否生成了正確的交易。

### 3.3 io-mail_monitor
- **主要職責:** 作為一個背景服務，定期檢查信箱並觸發自動化流程。
- **輸入:** 使用者在資料庫中設定的信箱憑證、監控規則（寄件人、主旨關鍵字）。
- **輸出:** 將下載的附件與郵件資訊傳遞給 `data_processor`。
- **核心邏輯:**
  - 應作為一個獨立的背景任務運行 (e.g., Cloud Functions triggered by Cloud Scheduler)。
  - 安全地從資料庫讀取加密後的信箱憑證並解密。
  - 使用 IMAP 協議連接信箱，根據規則搜尋新郵件。
  - 下載符合條件的附件。如果附件加密，需記錄下來並透過 `uOperator` 通知使用者。
  - 呼叫 `data_processor` 的 API 來啟動處理流程。
- **測試重點:**
  - **整合測試：** 測試能否成功連接 IMAP 伺服器並下載附件。
  - **安全性測試：** 確保信箱憑證的加解密流程安全無虞。
  - **錯誤處理測試：** 測試在網路中斷或信箱憑證錯誤時的行為。

### 3.4 document_processor
- **主要職責:** 接收文件，輸出純文字。
- **輸入:** 圖片 (PNG/JPG) 或 PDF 檔案的二進位資料。
- **輸出:** 純文字 (string)。
- **核心邏輯:**
  - 優先串接 Google Cloud Vision API。它對印刷體文字的辨識率高，且作為 GCP 服務易於整合。
  - 不建議在初期就實作本地的 Tesseract，以避免在 Cloud Run 或小型伺服器上產生過高的 CPU/記憶體負載。
  - 應包含錯誤處理機制，若 OCR 服務無法辨識或返回錯誤，需記錄並通知上游服務。
- **測試重點:**
  - **單元測試：** 提供多種清晰度的銀行對帳單圖片，驗證 OCR 結果的準確性。
  - **效能測試：** 測試處理一個 10 頁 PDF 檔案所需的時間。

### 3.5 ai_agent
- **主要職責:** 接收純文字，輸出結構化的交易資料 JSON。
- **輸入:** 從 OCR 來的純文字字串、使用者手動輸入的自然語言描述。
- **輸出:** `raw_transactions` 的 JSON 物件陣列。
- **核心邏輯:**
  - 主要使用 Gemini Pro API。需設計可擴展的架構，未來可輕易接入 OpenAI 或其他模型。
  - **Prompt Engineering:** 設計精巧的 Prompt，指導 AI 扮演一個細心的會計師，從雜亂的文字中提取交易日期、摘要、金額、幣別等欄位。
  - **輔助資訊:** 在呼叫 AI 前，可以從資料庫中讀取使用者的帳戶列表、分類列表作為上下文提供給 AI，以提高其辨識 `ai_suggested_source_account_id` 和 `ai_suggested_category_id` 的準確性。
  - **重複偵測:** 根據文字中的商家、金額、日期，生成一個 `duplicate_check_hash`。同時，可查詢資料庫中日期相近且金額相同的交易，標示出 `ai_suspected_duplicate_of_transaction_id`。
- **測試重點:**
  - **單元測試：** 針對各種邊角案例的文字輸入（如多筆交易在一行、金額格式混亂），驗證 JSON 輸出的穩定性與準確性。
  - **準確性評估：** 建立一個評估集，手動標記正確答案，用來衡量 AI Agent 的準確率 (Precision/Recall)。

### 3.6 data_processor
- **主要職責:** 作為自動化流程的總指揮，協調 IO 層與後續處理元件。
- **輸入:** 來自 IO 層的檔案或文字，以及來源資訊。
- **輸出:** 觸發 `uOperator` 執行記帳或審核流程。
- **核心邏輯:**
  - 提供一個統一的 API 端點給所有 IO 元件呼叫。
  - 建立一個 `import_jobs` 記錄，追蹤整個處理流程的狀態。
  - **流程控制:**
    - IF 輸入是檔案: 呼叫 `document_processor` 取得文字。
    - 呼叫 `ai_agent` 將文字轉換為 `raw_transactions` JSON 陣列。
    - 將這些 `raw_transactions` 存入資料庫，狀態為 `pending_review`。
    - 呼叫 `uOperator` 開始處理這些待審核項目。
- **測試重點:**
  - **整合測試：** 測試從接收檔案到成功在資料庫中建立 `import_jobs` 和 `raw_transactions` 的完整流程。
  - **錯誤處理測試：** 測試當 `document_processor` 或 `ai_agent` 失敗時，`import_jobs` 的狀態是否能被正確更新為 `failed`。

### 3.7 uOperator
- **主要職責:** 記帳的執行者，是業務規則和資料庫寫入前的最後一道關卡。
- **輸入:** `raw_transactions` 的 ID 列表。
- **輸出:** 在資料庫中建立/更新正式的 `transactions` 和 `transaction_splits`。
- **核心邏輯:**
  - **規則優先:** 對每一筆 `raw_transaction`，首先遍歷 `automation_rules` 表。若命中規則，直接採用規則設定的分類與帳戶，並跳過 AI 建議。
  - **AI 輔助:** 若無規則命中，則採用 `ai_agent` 提供的建議。
  - **互動判斷:**
    - IF (`AI 信心分數` < `預設閾值`) OR (`交易需要使用者提供額外資訊`，如密碼) OR (`ai_suspected_duplicate_of_transaction_id` 存在):
      - 則將交易維持在 `pending_review` 狀態，並產生一個通知事件（e.g., 透過 Chatbot 或 Web 推播）。
    - ELSE:
      - 直接進行記帳。
  - **複式記帳轉換:** 將單筆 `raw_transaction` 轉換為符合複式記帳原則的 `transactions` (事件) 和 `transaction_splits` (資金流動)。例如，一筆支出會生成至少兩條 split：一條 debit 到支出帳戶，一條 credit 到資產/負債帳戶。
  - **原子操作:** 所有對資料庫的寫入（建立 `transactions`, `transaction_splits`, 更新 `raw_transactions` 狀態）必須包裹在一個資料庫 TRANSACTION 中，確保資料一致性。
- **測試重點:**
  - **單元測試：** 測試複式記帳轉換邏輯的正確性（借貸方是否平衡）。
  - **單元測試：** 測試自動化規則匹配的邏輯。
  - **整合測試：** 測試當需要使用者互動時，是否能正確地停止流程並發出通知。

### 3.8 ifQuery
- **主要職責:** 資料庫存取抽象層 (Repository Pattern)。
- **輸入:** 業務邏輯層的呼叫，例如 `createTransaction(data)` 或 `findUserById(id)`。
- **輸出:** 從資料庫查詢到的資料模型，或操作結果。
- **核心邏輯:**
  - 定義清晰的介面 (Interface)，如 `ITransactionRepository`。
  - 提供至少兩種實現 (Implementation):
    - **PostgresTransactionRepository:** 負責將業務物件轉換為 SQL 語句，與 Cloud SQL 互動。
    - **FireflyIIIRepository:** 負責將業務物件轉換為 HTTP API 請求，與 Firefly III 的 API 互動。
  - 所有上層元件（如 `uOperator`）只能依賴這個抽象介面，而不能直接接觸 SQL 或 HTTP Client。
- **測試重點:**
  - **整合測試：** 針對 `PostgresTransactionRepository`，在測試資料庫上驗證其 CRUD 操作的正確性。
  - **整合測試：** 針對 `FireflyIIIRepository`，使用 Mock Server 模擬 Firefly III API，驗證其 API 呼叫的格式與邏輯是否正確。