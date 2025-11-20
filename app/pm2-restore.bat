@echo off
REM PM2 プロセス復元用バッチファイル
REM システム起動時にタスクスケジューラーから実行される

cd /d "%~dp0"
npm run pm2:resurrect
npm run pm2:save