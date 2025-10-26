# TV State Local 管理スクリプト
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "install")]
    [string]$Action
)

$appDir = "C:\Program Files\tv-state-local"
$pm2Exe = (Get-Command pm2 -ErrorAction SilentlyContinue)?.Source

function Start-Service {
    if ($pm2Exe) {
        Push-Location $appDir
        & $pm2Exe start ecosystem.config.js
        Pop-Location
        Write-Host "PM2 でサービスを開始しました"
    } else {
        Start-ScheduledTask -TaskName "tv-state-local"
        Write-Host "タスクスケジューラでサービスを開始しました"
    }
}

function Stop-Service {
    if ($pm2Exe) {
        & $pm2Exe stop tv-state-local
        Write-Host "PM2 でサービスを停止しました"
    } else {
        Stop-ScheduledTask -TaskName "tv-state-local"
        Write-Host "タスクスケジューラでサービスを停止しました"
    }
}

function Restart-Service {
    if ($pm2Exe) {
        & $pm2Exe restart tv-state-local
        Write-Host "PM2 でサービスを再起動しました"
    } else {
        Restart-ScheduledTask -TaskName "tv-state-local"
        Write-Host "タスクスケジューラでサービスを再起動しました"
    }
}

function Show-Status {
    if ($pm2Exe) {
        & $pm2Exe status
    } else {
        Get-ScheduledTask -TaskName "tv-state-local" | Select-Object TaskName, State
    }
}

function Show-Logs {
    if ($pm2Exe) {
        & $pm2Exe logs tv-state-local
    } else {
        Write-Host "タスクスケジューラモードではログ表示はサポートされていません"
    }
}

function Install-PM2 {
    if (-not $pm2Exe) {
        Write-Host "PM2 をインストール中..."
        Push-Location $appDir
        npm install -g pm2
        Pop-Location
        Write-Host "PM2 のインストールが完了しました"
    } else {
        Write-Host "PM2 は既にインストールされています"
    }
}

switch ($Action) {
    "start" { Start-Service }
    "stop" { Stop-Service }
    "restart" { Restart-Service }
    "status" { Show-Status }
    "logs" { Show-Logs }
    "install" { Install-PM2 }
}

