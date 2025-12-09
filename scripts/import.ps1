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

# 顯示歡迎信息
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WutheringWaves Bot - 遊戲統計導入" -ForegroundColor Cyan
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
    Write-Host "📝 請在 Discord 使用 /生成上傳令牌 獲取 Token" -ForegroundColor Yellow
    Write-Host ""
    $Token = Read-Host "請輸入 Token"
    if (-not $Token) {
        Write-Error "❌ Token 不能為空"
        Write-Host ""
        Write-Host "按任意鍵退出..." -ForegroundColor Gray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 3
        }
        exit 1
    }
}

if (-not $Uid) {
    $Uid = Read-Host "請輸入您的遊戲 UID"
    if (-not $Uid) {
        Write-Error "❌ UID 不能為空"
        Write-Host ""
        Write-Host "按任意鍵退出..." -ForegroundColor Gray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 3
        }
        exit 1
    }
}

# 查找遊戲數據庫
Write-Info "🔍 正在查找遊戲數據庫..."

$GameDbRelativePath = "Client\Saved\LocalStorage\LocalStorage.db"
$DbPath = $null

# 嘗試常見路徑
$CommonPaths = @(
    "$env:LOCALAPPDATA\Wuthering Waves",
    "C:\Program Files\Wuthering Waves",
    "C:\Program Files (x86)\Wuthering Waves",
    "D:\Wuthering Waves",
    "E:\Wuthering Waves",
    "F:\Wuthering Waves"
)

foreach ($BasePath in $CommonPaths) {
    $TestPath = Join-Path $BasePath $GameDbRelativePath
    if (Test-Path $TestPath) {
        $DbPath = $TestPath
        break
    }
}

if (-not $DbPath) {
    Write-Error "❌ 找不到遊戲數據庫"
    Write-Host ""
    Write-Host "請確認：" -ForegroundColor Yellow
    Write-Host "  1. 已安裝 WutheringWavesTool" -ForegroundColor White
    Write-Host "  2. 已使用 WutheringWavesTool 啟動過遊戲" -ForegroundColor White
    Write-Host ""
    Write-Host "如果遊戲安裝在非默認位置，請聯繫管理員" -ForegroundColor Yellow
    exit 1
}

Write-Success "✅ 找到數據庫: $DbPath"

# 讀取統計數據（使用內嵌 Python 代碼）
Write-Info "📊 正在讀取統計數據..."

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
    Write-Error "❌ 未找到 Python"
    Write-Host ""
    Write-Host "解決方法：" -ForegroundColor Yellow
    Write-Host "  1. 安裝 Python: https://www.python.org/downloads/" -ForegroundColor Green
    Write-Host "  2. 安裝時勾選 'Add Python to PATH'" -ForegroundColor Green
    Write-Host ""
    Write-Host "安裝完成後，請重新執行此命令" -ForegroundColor Cyan
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
    Write-Error "❌ 讀取數據庫失敗: $_"
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
Write-Host "📅 日期: $($Stats.date)" -ForegroundColor Cyan
Write-Host "   戰鬥次數: $($Stats.battle_count)"
Write-Host "   獲取聲骸: $($Stats.phantom_get_count)"
Write-Host "   閃避成功: $($Stats.parry_count)"
Write-Host "   切換角色: $($Stats.role_change_count)"
Write-Host "   角色死亡: $($Stats.role_death_count)"
Write-Host "   傳送次數: $($Stats.transfer_count)"
Write-Host "   消耗體力: $($Stats.used_strength)"
Write-Host ""

# 檢查是否有數據
$TotalEvents = $Stats.battle_count + $Stats.phantom_get_count + $Stats.parry_count + 
               $Stats.role_change_count + $Stats.role_death_count + $Stats.transfer_count

if ($TotalEvents -eq 0) {
    Write-Warning "⚠️  警告: 該日期沒有統計數據"
    $Response = Read-Host "是否仍要上傳？(y/N)"
    if ($Response -ne "y" -and $Response -ne "Y") {
        Write-Host "已取消上傳"
        Write-Host ""
        Write-Host "按任意鍵退出..." -ForegroundColor Gray
        try {
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } catch {
            Start-Sleep -Seconds 2
        }
        exit 0
    }
}

# 上傳數據
Write-Info "📤 正在上傳數據到 API..."

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
        Write-Success "✅ 數據上傳成功！"
        Write-Host ""
        Write-Host "🎉 完成！現在可以在 Discord 使用 /遊戲統計 查看數據" -ForegroundColor Green
        Write-Host ""
        
        # 如果不是在交互式終端，暫停讓用戶看到結果
        if (-not [Environment]::UserInteractive) {
            Write-Host "按任意鍵退出..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        exit 0
    } else {
        Write-Error "❌ 上傳失敗: $($Response.msg)"
        
        # 暫停讓用戶看到錯誤
        Write-Host ""
        Write-Host "按任意鍵退出..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    
} catch {
    Write-Error "❌ 上傳失敗: $_"
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

