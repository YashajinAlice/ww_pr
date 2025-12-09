# WutheringWaves Bot - 遊戲統計數據一鍵導入腳本
# 完全自包含，無需下載任何文件
# 
# 使用方法（一行命令，無需下載）：
#   $env:WW_BOT_TOKEN="YOUR_TOKEN"; $env:WW_BOT_UID="YOUR_UID"; iwr -UseBasicParsing https://raw.githubusercontent.com/YashajinAlice/ww_pr/main/scripts/import.ps1 | iex
#
# 或交互式輸入：
#   iwr -UseBasicParsing https://raw.githubusercontent.com/YashajinAlice/ww_pr/main/scripts/import.ps1 | iex
#
# 首次使用可能需要執行：
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Uid = ""
)

# API 基礎 URL
$ApiBaseUrl = "https://fukuroapi.fulin-net.top"
$ApiUrl = "$ApiBaseUrl/api/game-stats/upload"

# 顏色輸出
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }

# 設置控制台編碼為 UTF-8（避免亂碼）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 顯示歡迎信息
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WutheringWaves Bot - Game Stats Import" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 如果缺少參數，嘗試從環境變數讀取
if (-not $Token) {
    $Token = $env:WW_BOT_TOKEN
}

if (-not $Uid) {
    $Uid = $env:WW_BOT_UID
}

# 如果還是沒有，引導用戶輸入
if (-not $Token) {
    Write-Host "[!] Please use /generate_upload_token in Discord to get Token" -ForegroundColor Yellow
    Write-Host ""
    $Token = Read-Host "Enter Token"
    if (-not $Token) {
        Write-Error "[X] Token cannot be empty"
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 3
        }
        exit 1
    }
}

if (-not $Uid) {
    $Uid = Read-Host "Enter your Game UID"
    if (-not $Uid) {
        Write-Error "[X] UID cannot be empty"
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 3
        }
        exit 1
    }
}

# 獲取遊戲根目錄
Write-Info "[*] Please enter your game root directory"
Write-Host ""
Write-Host "Example: C:\Program Files\Wuthering Waves" -ForegroundColor Gray
Write-Host "         D:\Games\Wuthering Waves" -ForegroundColor Gray
Write-Host ""
$GameRootDir = Read-Host "Game Root Directory"

if (-not $GameRootDir) {
    Write-Error "[X] Game root directory cannot be empty"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 3
    }
    exit 1
}

# 檢查路徑是否存在
if (-not (Test-Path $GameRootDir)) {
    Write-Error "[X] Directory not found: $GameRootDir"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 3
    }
    exit 1
}

# 構建數據庫路徑
$GameDbRelativePath = "Client\Saved\LocalStorage\LocalStorage.db"
$DbPath = Join-Path $GameRootDir $GameDbRelativePath

# 檢查數據庫文件是否存在
if (-not (Test-Path $DbPath)) {
    Write-Error "[X] Game database not found at: $DbPath"
    Write-Host ""
    Write-Host "Please confirm:" -ForegroundColor Yellow
    Write-Host "  1. The game root directory is correct" -ForegroundColor White
    Write-Host "  2. You have launched the game using WutheringWavesTool" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 5
    }
    exit 1
}

Write-Success "[OK] Database found: $DbPath"

# 讀取統計數據（使用內嵌 Python 代碼）
Write-Info "[*] Reading statistics data..."

$DateStr = (Get-Date).ToString("yyyy-MM-dd")

# 檢查 Python
$PythonCmd = $null
$PythonCommands = @("python", "python3", "py")

foreach ($cmd in $PythonCommands) {
    try {
        $null = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0 -or $?) {
            $PythonCmd = $cmd
            break
        }
    } catch {
        continue
    }
}

if (-not $PythonCmd) {
    Write-Error "[X] Python not found"
    Write-Host ""
    Write-Host "Solution:" -ForegroundColor Yellow
    Write-Host "  1. Install Python: https://www.python.org/downloads/" -ForegroundColor Green
    Write-Host "  2. Check 'Add Python to PATH' during installation" -ForegroundColor Green
    Write-Host ""
    Write-Host "After installation, please run this command again" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "按任意鍵退出..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 5
    }
    exit 1
}

# 使用 Python 讀取 SQLite（SQLite 是 Python 標準庫，無需額外安裝）
$PythonScript = @"
import sqlite3
import json
import sys
from datetime import datetime

db_path = r'$($DbPath -replace '\\', '\\')'
uid = '$Uid'
date_str = '$DateStr'

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT 
            role_change,
            role_death,
            battle,
            phantom_get,
            (parry_front + parry_back) as parry_count,
            transfer,
            used_strength
        FROM game_record
        WHERE role_id = ? AND create_date = ?
    ''', (uid, date_str))
    
    row = cursor.fetchone()
    
    if row:
        stats = {
            'date': date_str,
            'role_change_count': row[0] or 0,
            'role_death_count': row[1] or 0,
            'battle_count': row[2] or 0,
            'phantom_get_count': row[3] or 0,
            'parry_count': row[4] or 0,
            'transfer_count': row[5] or 0,
            'used_strength': row[6] or 0
        }
    else:
        stats = {
            'date': date_str,
            'battle_count': 0,
            'phantom_get_count': 0,
            'parry_count': 0,
            'role_change_count': 0,
            'role_death_count': 0,
            'transfer_count': 0,
            'used_strength': 0
        }
    
    print(json.dumps(stats, ensure_ascii=False))
    conn.close()
except Exception as e:
    print(json.dumps({'error': str(e)}), file=sys.stderr)
    sys.exit(1)
"@

try {
    $StatsJson = $PythonScript | & $PythonCmd 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        $ErrorMsg = $StatsJson | Out-String
        Write-Error "❌ 讀取數據庫失敗"
        Write-Host $ErrorMsg -ForegroundColor Red
        exit 1
    }
    
    $Stats = $StatsJson | ConvertFrom-Json
    
    if ($Stats.error) {
        throw $Stats.error
    }
    
} catch {
    Write-Error "[X] Failed to read database: $_"
    Write-Host ""
    Write-Host "按任意鍵退出..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 5
    }
    exit 1
}

# 顯示統計數據
Write-Host ""
Write-Host "[*] Date: $($Stats.date)" -ForegroundColor Cyan
Write-Host "   Battle Count: $($Stats.battle_count)"
Write-Host "   Phantom Get: $($Stats.phantom_get_count)"
Write-Host "   Parry Success: $($Stats.parry_count)"
Write-Host "   Role Change: $($Stats.role_change_count)"
Write-Host "   Role Death: $($Stats.role_death_count)"
Write-Host "   Transfer: $($Stats.transfer_count)"
Write-Host "   Used Strength: $($Stats.used_strength)"
Write-Host ""

# 檢查是否有數據
$TotalEvents = $Stats.battle_count + $Stats.phantom_get_count + $Stats.parry_count + 
               $Stats.role_change_count + $Stats.role_death_count + $Stats.transfer_count

if ($TotalEvents -eq 0) {
    Write-Warning "[!] Warning: No statistics data for this date"
    $Response = Read-Host "Still upload? (y/N)"
    if ($Response -ne "y" -and $Response -ne "Y") {
        Write-Host "Upload cancelled"
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 2
        }
        exit 0
    }
}

# 上傳數據
Write-Info "[*] Uploading data to API..."

try {
    $Payload = @{
        token = $Token
        stats = $Stats
    } | ConvertTo-Json -Depth 10
    
    $Headers = @{
        "Content-Type" = "application/json"
        "User-Agent" = "WutheringWavesBot-CLI/1.0"
    }
    
    $Response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $Payload -Headers $Headers -ErrorAction Stop
    
    if ($Response.success) {
        Write-Host ""
        Write-Success "[OK] Data uploaded successfully!"
        Write-Host ""
        Write-Host "[OK] Done! You can now use /game_stats in Discord to view the data" -ForegroundColor Green
        Write-Host ""
        
        # 如果不是在交互式終端，暫停讓用戶看到結果
        if (-not [Environment]::UserInteractive) {
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        exit 0
    } else {
        Write-Error "[X] Upload failed: $($Response.msg)"
        
        # 暫停讓用戶看到錯誤
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    
} catch {
    Write-Error "[X] Upload failed: $_"
    if ($_.Exception.Response) {
        try {
            $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $ResponseBody = $Reader.ReadToEnd()
            $ErrorBody = $ResponseBody | ConvertFrom-Json
            Write-Error "   錯誤信息: $($ErrorBody.msg)"
        } catch {
            Write-Error "   響應: $($_.Exception.Message)"
        }
    }
    
    # 暫停讓用戶看到錯誤
    Write-Host ""
    Write-Host "按任意鍵退出..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        # 如果無法讀取按鍵（非交互式終端），等待幾秒
        Start-Sleep -Seconds 5
    }
    exit 1
}

