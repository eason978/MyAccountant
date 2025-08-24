<#
.SYNOPSIS
    自動建立一個完整的專案目錄結構，包含後端、前端、文件和測試。

.DESCRIPTION
    此腳本會在當前目錄下建立一個新專案資料夾，並在其中創建預設的子目錄和檔案。
    結構包含：
    - 後端 (FastAPI)
    - 前端 (Vue)
    - 文件 (.md)
    - 測試 (包含後端和前端測試)

    每個主要元件都包含一個 SPEC.md (規格書) 和 TESTING.md (測試報告) 的模板。

.EXAMPLE
    .\scaffold.ps1 -ProjectName MyNewApp
    此指令會在當前目錄下建立一個名為 MyNewApp 的新專案。
#>

param (
    [string]$ProjectName = 'my-project'
)

# 變數定義
$currentDir = Get-Location
$projectPath = Join-Path -Path $currentDir -ChildPath $ProjectName
$backendDir = Join-Path -Path $projectPath -ChildPath 'backend'
$frontendDir = Join-Path -Path $projectPath -ChildPath 'frontend'
$docsDir = Join-Path -Path $projectPath -ChildPath 'docs'
$testsDir = Join-Path -Path $projectPath -ChildPath 'tests'

# 建立主要專案目錄
New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
Write-Host "專案結構已成功建立！" -ForegroundColor Green

# 建立子目錄
New-Item -ItemType Directory -Path $backendDir -Force | Out-Null
New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null
New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
New-Item -ItemType Directory -Path $testsDir -Force | Out-Null
Write-Host "正在建立子目錄..." -ForegroundColor Cyan

# 建立檔案模板
Write-Host "正在建立文件模板..." -ForegroundColor Cyan

# 主要 README
$readmeContent = @"
# $ProjectName
> 一個為...所設計的專案。

## 專案結構
- **backend/**：後端服務 (FastAPI)
- **frontend/**：前端應用程式 (Vue)
- **docs/**：專案文件
- **tests/**：測試程式碼

## 開發指南
- [後端開發指南](./backend/README.md)
- [前端開發指南](./frontend/README.md)
- [專案概覽](./docs/OVERVIEW.md)

## 聯絡方式
- 負責人：你的名字
- 電子郵件：你的信箱
"@
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $projectPath -ChildPath 'README.md') -Value $readmeContent -Encoding utf8

# 專案概覽文件
$overviewContent = @"
# 專案概覽 (Project Overview)

## 專案目的
簡要描述這個專案存在的目的和它要解決的問題。

## 技術棧
- 後端：FastAPI, Python 3.11+
- 前端：Vue 3, TypeScript
- 資料庫：PostgreSQL
- 部署：Docker, Kubernetes
"@
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $docsDir -ChildPath 'OVERVIEW.md') -Value $overviewContent -Encoding utf8

# 後端模板
$backendReadmeContent = "# 後端服務 (FastAPI)\n\n描述後端服務的架構、API 端點和主要功能。"
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $backendDir -ChildPath 'README.md') -Value $backendReadmeContent -Encoding utf8
$backendSpecContent = "# 後端規格書 (SPEC)\n\n## 概述\n描述 API 的核心功能、端點清單及資料模型。\n\n## API 端點範例\n- `GET /users`：取得使用者列表\n- `POST /users`：建立新使用者"
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $backendDir -ChildPath 'SPEC.md') -Value $backendSpecContent -Encoding utf8
$backendTestingContent = "# 後端測試報告 (TESTING)\n\n## 測試範圍\n描述本次測試涵蓋的模組或功能。\n\n## 測試結果\n- [ ] 單元測試\n- [ ] 整合測試\n- [ ] 效能測試"
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $backendDir -ChildPath 'TESTING.md') -Value $backendTestingContent -Encoding utf8

# 前端模板
$frontendReadmeContent = "# 前端應用程式 (Vue)\n\n描述前端應用程式的頁面流程和主要 UI/UX 設計。"
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $frontendDir -ChildPath 'README.md') -Value $frontendReadmeContent -Encoding utf8
$frontendSpecContent = "# 前端規格書 (SPEC)\n\n## 概述\n描述使用者介面的設計、主要頁面流程和元件結構。\n\n## 頁面範例\n- 登入頁面\n- 使用者儀表板\n- 報表頁面"
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $frontendDir -ChildPath 'SPEC.md') -Value $frontendSpecContent -Encoding utf8
$frontendTestingContent = "# 前端測試報告 (TESTING)\n\n## 測試範圍\n描述本次測試涵蓋的頁面或功能。\n\n## 測試結果\n- [ ] 元件測試\n- [ ] 端對端測試\n- [ ] 瀏覽器相容性測試"
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $frontendDir -ChildPath 'TESTING.md') -Value $frontendTestingContent -Encoding utf8

# 總體測試報告模板
$overallTestingContent = "# 測試報告 (TESTING)\n\n## 後端測試結果\n請參考 `backend/TESTING.md`\n\n## 前端測試結果\n請參考 `frontend/TESTING.md`."
# 在此處強制指定檔案編碼為 UTF-8
Set-Content -Path (Join-Path -Path $testsDir -ChildPath 'TESTING.md') -Value $overallTestingContent -Encoding utf8

Write-Host "專案結構已成功建立！" -ForegroundColor Green
Write-Host "請使用 'cd $ProjectName' 進入專案目錄。" -ForegroundColor Yellow
