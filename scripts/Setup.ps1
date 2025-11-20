#requires -version 5

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$appDir = Join-Path $root "app"

# インストール先
$appDst = "C:\Program Files\tv-state-local"

# Helper functions
function Get-EnvValue {
  param([string]$FilePath, [string]$Key)

  if (!(Test-Path $FilePath)) { return $null }

  # UTF-8で読み込み
  $content = Get-Content $FilePath -Encoding UTF8 -ErrorAction SilentlyContinue
  foreach ($line in $content) {
    $line = $line.Trim()
    if ($line -match "^$Key\s*=\s*(.*)$") {
      $value = $matches[1].Trim().Trim('"')
      # 空文字列の場合はnullを返す
      if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
      }
      return $value
    }
  }
  return $null
}

# 定数定義
$envTemplate = Join-Path $appDir ".env.template"
$cecClientExeDefault = Get-EnvValue -FilePath $envTemplate -Key "CEC_CLIENT_PATH"
$tvKioskUrl = Get-EnvValue -FilePath $envTemplate -Key "TV_KIOSK_URL"
$firewallRuleName = "tv-state-local 8765"
$pm2ScheduleTaskName = "tv-state-local"
$kioskScheduleTaskName = "tv-kiosk-edge"

# 状態チェック（定数として定義）
$hasWinget = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
$hasNode = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
$hasLibCEC = if ($cecClientExeDefault) { Test-Path $cecClientExeDefault } else { $false }

# Helper functions (continued)
function Test-Administrator {
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Winget {
  Write-Host "winget をインストール中..."
  try {
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    Write-Host "winget のインストールが完了しました。"
    return $true
  } catch {
    Write-Warning "winget のインストールに失敗しました: $_"
    Write-Host "手動でMicrosoft Storeからインストールしてください。"
    return $false
  }
}

function Install-LibCEC {
  Write-Host "libCEC をGitHubからダウンロード・インストール中..."

  try {
    $libcecVersion = "6.0.2"
    $downloadUrl = "https://github.com/Pulse-Eight/libcec/releases/download/libcec-$libcecVersion/libcec-$libcecVersion.exe"
    $tempDir = [System.IO.Path]::GetTempPath()
    $exePath = Join-Path $tempDir "libcec-$libcecVersion.exe"

    Write-Host "libCEC v$libcecVersion をダウンロード中..."
    Write-Host "URL: $downloadUrl"

    # ダウンロード実行
    Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing
    Write-Host "ダウンロード完了: $exePath"

    # ダウンロードしたEXEをサイレントインストール
    Write-Host "libCEC をサイレントインストール中..."

    # 複数のサイレントパラメータを試行
    $silentArgs = @("/S", "/SILENT", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/NOCANCEL")

    try {
      # 最初にNSISタイプのサイレントインストールを試行
      Start-Process -FilePath $exePath -ArgumentList $silentArgs -Wait -WindowStyle Hidden
      Write-Host "サイレントインストール完了"
    } catch {
      Write-Warning "サイレントインストールに失敗しました。通常インストールを試行します..."
      Start-Process -FilePath $exePath -ArgumentList "/S" -Wait
    }

    # 一時ファイルをクリーンアップ
    Remove-Item $exePath -ErrorAction SilentlyContinue

    Write-Host "libCEC のダウンロード・インストールが完了しました。"
    return $true
  } catch {
    Write-Warning "libCEC のダウンロード・インストールに失敗しました: $_"
    Write-Host "手動でhttps://github.com/Pulse-Eight/libcec/releases からダウンロードしてください。"
    return $false
  }
}

function Install-NodeJS {
  Write-Host "Node.js をwingetでインストール中..."

  try {
    # wingetでインストール
    winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent
    Write-Host "Node.js のインストールが完了しました。"
    return $true
  } catch {
    Write-Warning "Node.js のインストールに失敗しました: $_"
    Write-Host "手動でhttps://nodejs.org からダウンロードしてインストールしてください。"
    return $false
  }
}

function Register-KioskTask {
  param([string]$TaskName, [string]$Url, [string]$EdgePath)

  $kioskArgs = "--kiosk `"$Url`" --edge-kiosk-type=fullscreen --no-first-run --disable-features=msEdgeTabPreloading"
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest

  try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $edgeAction = New-ScheduledTaskAction -Execute $EdgePath -Argument $kioskArgs -WorkingDirectory "C:\"
    Register-ScheduledTask -TaskName $TaskName -Action $edgeAction -Trigger $trigger -Principal $principal | Out-Null
    Write-Host "キオスクタスク登録: $TaskName"
    return $true
  } catch {
    Write-Warning "キオスクタスク登録失敗: $_"
    return $false
  }
}

function Register-PM2AutoStart {
  param([string]$TaskName, [string]$AppPath)

  try {
    $pm2RestoreScript = Join-Path $AppPath "pm2-restore.bat"

    # 既存のタスクを削除（エラーは無視）
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    # 新しいタスクを作成（システム起動時に実行）
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    $action = New-ScheduledTaskAction -Execute $pm2RestoreScript

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal | Out-Null

    Write-Host "PM2自動起動タスクが正常に登録されました: $TaskName"
    Write-Host "システム再起動後、PM2プロセスが自動的に復元されます"

  } catch {
    Write-Warning "PM2自動起動設定中にエラーが発生しました: $_"
  }
}

Write-Host "=== tv-state-local セットアップ開始 ==="

# 管理者権限チェック
if (-not (Test-Administrator)) {
  Write-Warning "このスクリプトは管理者権限で実行する必要があります。"
  Write-Host "Setup.batを右クリックして「管理者として実行」を選択してください。"
  exit 1
}

Write-Host "管理者権限を確認しました。"

# wingetのインストール確認
if (-not $hasWinget) {
  Write-Host "winget が見つかりません。インストールを試行します..."
  if (-not (Install-Winget)) {
    Write-Warning "winget のインストールに失敗しました。続行できません。"
    exit 1
  }
} else {
  Write-Host "winget は既にインストールされています。"
}

# libCECのインストール
if (-not $hasLibCEC) {
  Write-Host "libCEC が見つかりません。インストールを試行します..."
  Install-LibCEC
} else {
  Write-Host "libCEC は既に存在します。"
}

# Node.jsのインストール
if (-not $hasNode) {
  Write-Host "Node.js が見つかりません。インストールを試行します..."
  Install-NodeJS
} else {
  Write-Host "Node.js は既に導入済みです。"
}

# 4) アプリ配置
Write-Host "アプリを配置: $appDst"
New-Item -Force -ItemType Directory $appDst | Out-Null
Copy-Item -Recurse -Force (Join-Path $appDir "*") $appDst

# 5) .env 作成（無ければテンプレから）
$envPath = Join-Path $appDst ".env"
if (!(Test-Path $envPath)) {
  $tpl = Join-Path $appDir ".env.template"
  Copy-Item $tpl $envPath
  Write-Host ".env を作成: $envPath"
} else {
  Write-Host ".env は既に存在: $envPath"
}

# 6) npm install（失敗しても続行）
try {
  Push-Location $appDst
  # Node.jsインストール後のPATH更新とnpm確認
  Write-Host "npm コマンドの確認中..."

  # PATH環境変数を更新（新しくインストールされたNode.jsを認識するため）
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

  $npmRetries = 5
  $npmFound = $false

  for ($i = 1; $i -le $npmRetries; $i++) {
    $npmCommand = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCommand) {
      Write-Host "npm コマンドが見つかりました: $($npmCommand.Source)"
      $npmFound = $true
      break
    } else {
      Write-Host "npm コマンド確認試行 $i/$npmRetries (5秒待機)..."
      Start-Sleep -Seconds 5
    }
  }

  if ($npmFound) {
    Write-Host "npm install 実行中..."
    npm install --silent
    Write-Host "npm install が完了しました。"
  } else {
    Write-Warning "npm コマンドが見つかりませんでした。Node.js のインストールが完了していない可能性があります。"
    Write-Host "後で手動で以下のコマンドを実行してください："
    Write-Host "  cd `"$appDst`""
    Write-Host "  npm install"
  }
} catch {
  Write-Warning "npm install でエラー: $_"
  Write-Host "後で手動で npm install を実行してください。"
} finally {
  Pop-Location
}

# 7) PM2によるデーモン化設定
try {
  Write-Host "PM2 を使用してデーモン化を設定中..."
  Push-Location $appDst
  # PM2でプロセスを開始
  npm run pm2:start
  npm run pm2:save

  # Windows環境では pm2 startup は非対応のため、タスクスケジューラーを使用
  Write-Host "Windows用のPM2自動起動設定を行います..."
  Register-PM2AutoStart -TaskName $pm2ScheduleTaskName -AppPath $appDst

  # PM2の現在の状態を保存
  Write-Host "PM2 デーモン化完了"
} catch {
  Write-Error "PM2 設定に失敗しました。PM2は必須コンポーネントです: $_"
  exit 1
} finally {
  Pop-Location
}

# 8) Firewall（ローカルポート8765）
if (-not (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName $firewallRuleName -Direction Inbound -Protocol TCP -LocalPort 8765 -Action Allow | Out-Null
  Write-Host "Firewall 例外を登録: $firewallRuleName"
} else {
  Write-Host "Firewall 例外は既に存在: $firewallRuleName"
}

# （任意）Edge キオスクの自動起動タスク
if (-not $tvKioskUrl) {
  Write-Host "TV_KIOSK_URL が未設定のためキオスク登録をスキップ。"
} else {
  # Edge実行ファイル取得
  $edgeCommand = Get-Command msedge -ErrorAction SilentlyContinue
  $edgePath = if ($edgeCommand) { $edgeCommand.Source } else { $null }

  if (-not $edgePath) {
    Write-Warning "Edge が見つかりません。キオスクタスクをスキップ。"
  } else {
    Register-KioskTask -TaskName $kioskScheduleTaskName -Url $tvKioskUrl -EdgePath $edgePath
  }
}

# 9) すぐ起動確認
try {
  # PM2でプロセス管理されているため既に起動済み
  Write-Host "PM2 プロセス管理で起動済み"

  # サーバー起動待機とヘルスチェック
  Write-Host "サーバーの起動を待機中..."
  $maxRetries = 6
  $retryDelay = 10
  $success = $false

  for ($i = 1; $i -le $maxRetries; $i++) {
    Write-Host "起動確認試行 $i/$maxRetries (${retryDelay}秒間隔)..."
    Start-Sleep -Seconds $retryDelay

    try {
      $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8765/health" -TimeoutSec 10
      Write-Host "サーバ応答: $($resp.Content)"
      Write-Host "ステータスコード: $($resp.StatusCode)"

      # ステータスコード200でレスポンスがあれば成功とみなす
      if ($resp.StatusCode -eq 200) {
        $success = $true
        Write-Host "サーバーが正常に応答しています"
        break
      }
    } catch {
      Write-Host "試行 $i 失敗: $($_.Exception.Message)"
    }
  }

  if (-not $success) {
    Write-Warning "サーバーの起動確認に失敗しました。手動で確認してください。"
    Write-Host "ブラウザで http://127.0.0.1:8765/health にアクセスして確認できます。"
  }
} catch {
  Write-Warning "起動処理でエラーが発生: $_"
}

Write-Host "=== tv-state-local セットアップ終了 ==="
