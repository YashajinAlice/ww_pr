# WutheringWaves Bot - Game Stats Import Script
# Self-contained, no downloads required
# 
# Usage (one-line command):
#   $env:WW_BOT_TOKEN="YOUR_TOKEN"; $env:WW_BOT_UID="YOUR_UID"; iwr -UseBasicParsing https://raw.githubusercontent.com/YashajinAlice/ww_pr/main/scripts/import.ps1 | iex
#
# Or interactive input:
#   iwr -UseBasicParsing https://raw.githubusercontent.com/YashajinAlice/ww_pr/main/scripts/import.ps1 | iex
#
# First-time use may require:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Uid = ""
)

# API Base URL
$ApiBaseUrl = "https://fukuroapi.fulin-net.top"
$ApiUrl = "$ApiBaseUrl/api/game-stats/upload"

# Color output functions
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }

# Set console encoding to UTF-8 (avoid garbled text)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Display welcome message
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  WutheringWaves Bot - Game Stats Import" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# If parameters are missing, try reading from environment variables
if (-not $Token) {
    $Token = $env:WW_BOT_TOKEN
}

if (-not $Uid) {
    $Uid = $env:WW_BOT_UID
}

# If still missing, prompt user for input
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

# Find game log directory
Write-Info "[*] Searching for game log files..."

$LogDirRelativePath = "Client\Saved\Logs"
$LogFiles = @()

# Common game installation paths
$CommonPaths = @(
    "$env:LOCALAPPDATA\Wuthering Waves",
    "C:\Program Files\Wuthering Waves",
    "C:\Program Files (x86)\Wuthering Waves",
    "D:\Wuthering Waves",
    "E:\Wuthering Waves",
    "F:\Wuthering Waves"
)

foreach ($BasePath in $CommonPaths) {
    # Check if drive exists (avoid errors for non-existent drives)
    $DriveLetter = ($BasePath -split ':')[0]
    if ($DriveLetter -and $DriveLetter.Length -eq 1) {
        $Drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
        if (-not $Drive) {
            # Drive doesn't exist, skip
            continue
        }
    }
    
    # Check if path exists
    if (-not (Test-Path $BasePath)) {
        continue
    }
    
    $LogDir = Join-Path $BasePath $LogDirRelativePath
    if (Test-Path $LogDir) {
        # Find all Client*.log files
        $FoundFiles = Get-ChildItem -Path $LogDir -Filter "Client*.log" -ErrorAction SilentlyContinue
        if ($FoundFiles) {
            $LogFiles += $FoundFiles
        }
    }
}

# If not found, prompt user
if ($LogFiles.Count -eq 0) {
    Write-Warning "[!] Could not find game log files automatically"
    Write-Host ""
    Write-Host "Please enter your game root directory:" -ForegroundColor Yellow
    Write-Host "Example: C:\Program Files\Wuthering Waves" -ForegroundColor Gray
    Write-Host ""
    $GameRootDir = Read-Host "Game Root Directory"
    
    if ($GameRootDir) {
        $LogDir = Join-Path $GameRootDir $LogDirRelativePath
        if (Test-Path $LogDir) {
            $FoundFiles = Get-ChildItem -Path $LogDir -Filter "Client*.log" -ErrorAction SilentlyContinue
            if ($FoundFiles) {
                $LogFiles += $FoundFiles
            }
        }
    }
}

if ($LogFiles.Count -eq 0) {
    Write-Error "[X] Game log files not found"
    Write-Host ""
    Write-Host "Please confirm:" -ForegroundColor Yellow
    Write-Host "  1. The game is installed" -ForegroundColor White
    Write-Host "  2. You have played the game at least once" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Start-Sleep -Seconds 5
    }
    exit 1
}

Write-Success "[OK] Found $($LogFiles.Count) log file(s)"

# Analyze log files
Write-Info "[*] Analyzing log files..."

$DateStr = (Get-Date).ToString("yyyy-MM-dd")

# Initialize counters
$stats = @{
    date = $DateStr
    role_change_count = 0
    role_death_count = 0
    battle_count = 0
    phantom_get_count = 0
    parry_count = 0
    transfer_count = 0
    used_strength = 0
}

# Keywords to search for
$keywords = @{
    "角色下场，立即隐藏" = "role_change_count"
    "前台角色死亡进行切人" = "role_death_count"
    "切换玩家状态: 进入战斗造成伤害" = "battle_count"
    "[技能名称: 初次幻象收服]" = "phantom_get_count"
    "传送:完成" = "transfer_count"
    "结束技能名称:" = "parry"  # Special handling for parry
}

# Regex patterns
$parryFrontPattern = [regex]::new("结束技能名称: (.+)?极限闪避前闪")
$parryBackPattern = [regex]::new("结束技能名称: (.+)?极限闪避后闪")

# Process log files (sorted by modification time)
$SortedFiles = $LogFiles | Sort-Object LastWriteTime

foreach ($LogFile in $SortedFiles) {
    Write-Info "  Processing: $($LogFile.Name)"
    
    try {
        $content = Get-Content $LogFile.FullName -Encoding UTF8 -ErrorAction Stop
        
        foreach ($line in $content) {
            # Check for today's date in log line
            if ($line -match "\[(\d{4}\.\d{2}\.\d{2})") {
                $logDate = $matches[1] -replace '\.', '-'
                $logDate = $logDate -replace '(\d{4})-(\d{2})-(\d{2})', '$1-$2-$3'
                
                # Only process today's logs
                if ($logDate -ne $DateStr) {
                    continue
                }
            }
            
            # Check keywords
            foreach ($keyword in $keywords.Keys) {
                if ($line -like "*$keyword*") {
                    $statKey = $keywords[$keyword]
                    
                    if ($statKey -eq "parry") {
                        # Special handling for parry
                        if ($parryFrontPattern.IsMatch($line) -or $parryBackPattern.IsMatch($line)) {
                            $stats.parry_count++
                        }
                    } else {
                        $stats[$statKey]++
                    }
                }
            }
            
            # Check for strength usage
            if ($line -like "*当前体力数据 [data: *") {
                if ($line -match "UPs:(\d+)") {
                    # This is just for detection, actual strength calculation would need more logic
                }
            }
        }
    } catch {
        Write-Warning "  Failed to read: $($LogFile.Name)"
    }
}

# Display statistics
Write-Host ""
Write-Host "[*] Date: $($stats.date)" -ForegroundColor Cyan
Write-Host "   Battle Count: $($stats.battle_count)"
Write-Host "   Phantom Get: $($stats.phantom_get_count)"
Write-Host "   Parry Success: $($stats.parry_count)"
Write-Host "   Role Change: $($stats.role_change_count)"
Write-Host "   Role Death: $($stats.role_death_count)"
Write-Host "   Transfer: $($stats.transfer_count)"
Write-Host "   Used Strength: $($stats.used_strength)"
Write-Host ""

# Check if there's any data
$TotalEvents = $stats.battle_count + $stats.phantom_get_count + $stats.parry_count + 
               $stats.role_change_count + $stats.role_death_count + $stats.transfer_count

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

# Upload data
Write-Info "[*] Uploading data to API..."

try {
    $Payload = @{
        token = $Token
        stats = $stats
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
        
        # Pause to let user see the result
        if (-not [Environment]::UserInteractive) {
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        exit 0
    } else {
        Write-Error "[X] Upload failed: $($Response.msg)"
        
        # Pause to let user see error
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
            Write-Error "   Error: $($ErrorBody.msg)"
        } catch {
            Write-Error "   Response: $($_.Exception.Message)"
        }
    }
    
    # Pause to let user see error
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        # If can't read key (non-interactive terminal), wait a few seconds
        Start-Sleep -Seconds 5
    }
    exit 1
}
