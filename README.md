# Windows Observer

Windows環境でテレビの電源状態を監視・制御するアプリケーションです。

## 機能
- **テレビ電源状態の監視**: CMM経由でテレビの電源状態を取得
- **RESTful API**: HTTP API経由での操作
- **自動起動**: WindowsタスクスケジューラまたはPM2によるデーモン化
- **ログ機能**: 構造化されたログファイル
- **ヘルスチェック**: システム状態の監視

## 必要な環境
- Windows 10/11
- Node.js 18.0.0以上

## セットアップ

Setup.batファイルを管理者権限で実行

※ アンインストールする場合はUninstall.batを使用

## API エンドポイント

```http
# ヘルスチェック
GET /health
# テレビ電源状態取得
GET /tv-state
# テレビ電源オン
POST /tv-on
# テレビ電源オフ
POST /tv-off
```

### プロセス管理

### PM2を使用する場合
```bash
# サービス開始
npm run pm2:start

# サービス停止
npm run pm2:stop

# サービス再起動
npm run pm2:restart

# 状態確認
npm run pm2:status

# ログ確認
npm run pm2:logs
```

### PowerShellスクリプトを使用する場合
```powershell
# サービス開始
.\scripts\Manage.ps1 -Action start

# サービス停止
.\scripts\Manage.ps1 -Action stop

# サービス再起動
.\scripts\Manage.ps1 -Action restart

# 状態確認
.\scripts\Manage.ps1 -Action status

# ログ確認
.\scripts\Manage.ps1 -Action logs
```


## ライセンス

MIT License
