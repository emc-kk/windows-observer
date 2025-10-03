#requires -version 5
# 管理者確認
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Error "管理者で実行してください。"
  exit 1
}

$ErrorActionPreference = "Stop"

Write-Host "=== tv-state-local アンインストール開始 ==="

$taskName = "tv-state-local"
$kioskTask = "tv-kiosk-edge"
$appDst = "C:\Program Files\tv-state-local"
$ruleName = "tv-state-local 8765"

# 1) PM2プロセスの停止
$pm2Exe = (Get-Command pm2 -ErrorAction SilentlyContinue)?.Source
if ($pm2Exe) {
  try {
    Write-Host "PM2プロセスを停止中..."
    & $pm2Exe stop tv-state-local
    & $pm2Exe delete tv-state-local
    & $pm2Exe unstartup
    Write-Host "PM2プロセス停止完了"
  } catch {
    Write-Warning "PM2プロセス停止に失敗: $_"
  }
}

# 2) タスクスケジューラの削除
try { 
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue 
  Write-Host "タスクスケジューラ削除: $taskName"
} catch {}

try { 
  Unregister-ScheduledTask -TaskName $kioskTask -Confirm:$false -ErrorAction SilentlyContinue 
  Write-Host "キオスクタスク削除: $kioskTask"
} catch {}

# 3) ファイアウォールルールの削除
try { 
  Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue 
  Write-Host "ファイアウォールルール削除: $ruleName"
} catch {}

# 4) Node.jsプロセスの停止
try { 
  Stop-Process -Name node -Force -ErrorAction SilentlyContinue 
  Write-Host "Node.jsプロセス停止"
} catch {}

# 5) アプリケーションディレクトリの削除
if (Test-Path $appDst) { 
  Remove-Item -Recurse -Force $appDst
  Write-Host "アプリケーションディレクトリ削除: $appDst"
}

# 6) ログファイルの削除（オプション）
$logDir = Join-Path $appDst "logs"
if (Test-Path $logDir) {
  $response = Read-Host "ログファイルも削除しますか？ (y/N)"
  if ($response -eq 'y' -or $response -eq 'Y') {
    Remove-Item -Recurse -Force $logDir
    Write-Host "ログファイル削除完了"
  }
}

Write-Host "=== アンインストール完了 ==="
Read-Host "Enter を押して閉じます"
