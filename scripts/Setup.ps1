#requires -version 5
# 1) 管理者確認
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Error "管理者で実行してください。"
  exit 1
}

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$appSrc = Join-Path $root "app"
$appDst = "C:\Program Files\tv-state-local"
$scripts = Join-Path $root "scripts"
$installDir = Join-Path $root "install"
$cecMsi = Get-ChildItem -Path (Join-Path $installDir "libcec-setup") -Filter *.msi -ErrorAction SilentlyContinue | Select-Object -First 1
$nodeMsi = Get-ChildItem -Path (Join-Path $installDir "node-setup") -Filter *.msi -ErrorAction SilentlyContinue | Select-Object -First 1

Write-Host "=== tv-state-local セットアップ開始 ==="

# 2) libCEC (cec-client) インストール（サイレント）
$cecClientExeDefault = "C:\Program Files (x86)\Pulse-Eight\USB-CEC Adapter\cec-client.exe"
if (!(Test-Path $cecClientExeDefault)) {
  if ($cecMsi) {
    Write-Host "libCEC をインストール中: $($cecMsi.FullName)"
    Start-Process "msiexec.exe" -ArgumentList "/i `"$($cecMsi.FullName)`" /qn /norestart" -Wait
  } else {
    Write-Warning "libCEC インストーラが見つかりませんでした。後で手動導入してください。"
  }
} else {
  Write-Host "libCEC は既に存在: $cecClientExeDefault"
}

# 3) Node.js 導入（優先: winget / 次: 同梱MSI）
function Have-Winget { (Get-Command winget -ErrorAction SilentlyContinue) -ne $null }
function Have-Node { (Get-Command node -ErrorAction SilentlyContinue) -ne $null }

if (-not (Have-Node)) {
  if (Have-Winget) {
    Write-Host "Node.js LTS を winget で導入します"
    winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent
  } elseif ($nodeMsi) {
    Write-Host "Node.js をMSIで導入します: $($nodeMsi.FullName)"
    Start-Process "msiexec.exe" -ArgumentList "/i `"$($nodeMsi.FullName)`" /qn /norestart" -Wait
  } else {
    Write-Warning "Node.js が見つからず導入もできませんでした。手動でインストールしてください。"
  }
} else {
  Write-Host "Node.js は既に導入済み"
}

# 4) アプリ配置
Write-Host "アプリを配置: $appDst"
New-Item -Force -ItemType Directory $appDst | Out-Null
Copy-Item -Recurse -Force (Join-Path $appSrc "*") $appDst

# 5) .env 作成（無ければテンプレから）
$envPath = Join-Path $appDst ".env"
if (!(Test-Path $envPath)) {
  $tpl = Join-Path $appSrc ".env.template"
  if (Test-Path $tpl) {
    Copy-Item $tpl $envPath
  } else {
    @"
CEC_CLIENT_PATH=$cecClientExeDefault
PORT=8765
CEC_LOGICAL_ADDR=0
"@ | Out-File -Encoding utf8 $envPath
  }
  Write-Host ".env を作成: $envPath"
} else {
  Write-Host ".env は既に存在: $envPath"
}

# 6) npm install（失敗しても続行）
try {
  Push-Location $appDst
  if (Test-Path "package.json") {
    Write-Host "npm install 実行中..."
    npm install --silent
  }
} catch { Write-Warning "npm install でエラー: $_" } finally { Pop-Location }

# 7) Firewall（ローカルポート8765）
$ruleName = "tv-state-local 8765"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort 8765 -Action Allow | Out-Null
  Write-Host "Firewall 例外を登録: $ruleName"
} else {
  Write-Host "Firewall 例外は既に存在: $ruleName"
}

# 8) ログディレクトリ作成
$logsDir = Join-Path $appDst "logs"
New-Item -Force -ItemType Directory $logsDir | Out-Null

# 9) PM2によるデーモン化設定
$pm2Exe = (Get-Command pm2 -ErrorAction SilentlyContinue)?.Source
if ($pm2Exe) {
  Write-Host "PM2 を使用してデーモン化を設定中..."
  Push-Location $appDst
  try {
    # PM2でプロセスを開始
    & $pm2Exe start ecosystem.config.js
    # PM2の自動起動設定
    & $pm2Exe startup
    & $pm2Exe save
    Write-Host "PM2 デーモン化完了"
  } catch { 
    Write-Warning "PM2 設定失敗: $_"
    # フォールバック: 従来のタスクスケジューラ方式
    Write-Host "フォールバック: タスクスケジューラ方式を使用"
    $taskName = "tv-state-local"
    $nodeExe = (Get-Command node -ErrorAction SilentlyContinue)?.Source
    if (-not $nodeExe) { $nodeExe = "node.exe" }
    $action = New-ScheduledTaskAction -Execute $nodeExe -Argument "index.js" -WorkingDirectory $appDst
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest
    try {
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
      Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null
      Write-Host "タスク登録: $taskName"
    } catch { Write-Warning "タスク登録失敗: $_" }
  } finally { Pop-Location }
} else {
  Write-Warning "PM2 が見つかりません。従来のタスクスケジューラ方式を使用します。"
  # 従来のタスクスケジューラ方式
  $taskName = "tv-state-local"
  $nodeExe = (Get-Command node -ErrorAction SilentlyContinue)?.Source
  if (-not $nodeExe) { $nodeExe = "node.exe" }
  $action = New-ScheduledTaskAction -Execute $nodeExe -Argument "index.js" -WorkingDirectory $appDst
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest
  try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null
    Write-Host "タスク登録: $taskName"
  } catch { Write-Warning "タスク登録失敗: $_" }
}

# （任意）Edge キオスクの自動起動タスク
$kioskUrl = $env:TV_KIOSK_URL
if ($kioskUrl) {
  $edge = (Get-Command msedge -ErrorAction SilentlyContinue)?.Source
  if ($edge) {
    $kioskTask = "tv-kiosk-edge"
    $kioskArgs = "--kiosk `"$kioskUrl`" --edge-kiosk-type=fullscreen --no-first-run --disable-features=msEdgeTabPreloading"
    try {
      Unregister-ScheduledTask -TaskName $kioskTask -Confirm:$false -ErrorAction SilentlyContinue
      $edgeAction = New-ScheduledTaskAction -Execute $edge -Argument $kioskArgs -WorkingDirectory "C:\"
      Register-ScheduledTask -TaskName $kioskTask -Action $edgeAction -Trigger $trigger -Principal $principal | Out-Null
      Write-Host "キオスクタスク登録: $kioskTask"
    } catch { Write-Warning "キオスクタスク登録失敗: $_" }
  } else {
    Write-Warning "Edge が見つかりません。キオスクタスクをスキップ。"
  }
} else {
  Write-Host "TV_KIOSK_URL が未設定のためキオスク登録をスキップ。"
}

# 10) すぐ起動
try {
  if ($pm2Exe) {
    # PM2でプロセス管理されている場合は既に起動済み
    Write-Host "PM2 プロセス管理で起動済み"
  } else {
    # 従来のタスクスケジューラ方式
    Start-ScheduledTask -TaskName $taskName
  }
  Start-Sleep -Seconds 3
  # 動作確認（ローカルで GET /health）
  $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8765/health" -TimeoutSec 5
  Write-Host "サーバ応答: $($resp.Content)"
} catch {
  Write-Warning "起動確認に失敗: $_"
}

Write-Host "=== セットアップ完了 ==="
Read-Host "Enter を押して閉じます"
