@echo off
:: 管理者権限で PowerShell を実行（昇格）
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0scripts\\Setup.ps1' -Verb RunAs"
