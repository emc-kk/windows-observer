#requires -version 5

$ErrorActionPreference = "Stop"

function Test-Administrator {
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Uninstall-LibCEC {
  try {
    Write-Host "libCEC のアンインストールを試行中..."

    # インストール済みのlibCECを検索
    $libcecProducts = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*libCEC*" }

    if ($libcecProducts) {
      foreach ($product in $libcecProducts) {
        Write-Host "libCEC を削除中: $($product.Name) (バージョン: $($product.Version))"
        $result = $product.Uninstall()

        if ($result.ReturnValue -eq 0) {
          Write-Host "libCEC のアンインストールが完了しました: $($product.Name)"
        } else {
          Write-Warning "libCEC のアンインストールに失敗しました: ReturnValue = $($result.ReturnValue)"
        }
      }
      return $true
    } else {
      Write-Host "libCEC はインストールされていません。"
      return $true
    }
  } catch {
    Write-Warning "libCEC のアンインストール中にエラーが発生しました: $_"
    return $false
  }
}

# 管理者権限チェック
if (-not (Test-Administrator)) {
  Write-Warning "このスクリプトは管理者権限で実行する必要があります。"
  Write-Host "Setup.batを右クリックして「管理者として実行」を選択してください。"
  exit 1
}

Write-Host "管理者権限を確認しました。"

Write-Host "=== tv-state-local アンインストール開始 ==="

$appDst = "C:\Program Files\tv-state-local"
$firewallRuleName = "tv-state-local 8765"
$pm2ScheduleTaskName = "tv-state-local"
$kioskScheduleTaskName = "tv-kiosk-edge"

# 1) PM2プロセスの停止
$pm2Command = Get-Command pm2 -ErrorAction SilentlyContinue
$pm2Exe = if ($pm2Command) { $pm2Command.Source } else { $null }
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

# 2) スケジュールタスクの削除
# PM2自動起動タスクの削除
try {
  Unregister-ScheduledTask -TaskName $pm2ScheduleTaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "PM2自動起動タスク削除: $pm2ScheduleTaskName"
} catch {
  Write-Warning "PM2自動起動タスク削除でエラー: $_"
}

# キオスクタスクの削除
try {
  Unregister-ScheduledTask -TaskName $kioskScheduleTaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "キオスクタスク削除: $kioskScheduleTaskName"
} catch {
  Write-Warning "キオスクタスク削除でエラー: $_"
}

# 3) ファイアウォールルールの削除
try {
  Remove-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue
  Write-Host "ファイアウォールルール削除: $firewallRuleName"
} catch {
  Write-Warning "ファイアウォールルール削除でエラー: $_"
}

# 4) Node.jsプロセスの停止
try {
  Stop-Process -Name node -Force -ErrorAction SilentlyContinue
  Write-Host "Node.jsプロセス停止"
} catch {
  Write-Warning "Node.jsプロセス停止でエラー: $_"
}

# 5) libCECのアンインストール（オプション）
$response = Read-Host "libCEC もアンインストールしますか？ (y/N)"
if ($response -eq 'y' -or $response -eq 'Y') {
  Uninstall-LibCEC
} else {
  Write-Host "libCEC はそのまま残します。"
}

# 6) ログファイルの削除確認（アプリケーションディレクトリ削除前）
$logDir = Join-Path $appDst "logs"
if (Test-Path $logDir) {
  $response = Read-Host "ログファイルも削除しますか？ (y/N)"
  if ($response -eq 'y' -or $response -eq 'Y') {
    Remove-Item -Recurse -Force $logDir
    Write-Host "ログファイル削除完了"
  }
}

# 7) アプリケーションディレクトリの削除
if (Test-Path $appDst) {
  Remove-Item -Recurse -Force $appDst
  Write-Host "アプリケーションディレクトリ削除: $appDst"
}

Write-Host "=== アンインストール完了 ==="
Read-Host "Enter を押して閉じます"
