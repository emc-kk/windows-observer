# Windows Observer

Windows環境でテレビの電源状態を監視・制御するアプリケーションです。

## 機能
TODO: 整理

- **テレビ電源状態の監視**: CMM経由でテレビの電源状態を取得
- **RESTful API**: HTTP API経由での操作
- **自動起動**: WindowsタスクスケジューラまたはPM2によるデーモン化
- **ログ機能**: 構造化されたログファイル
- **ヘルスチェック**: システム状態の監視

## 必要な環境
- Windows 10/11
- Node.js 18.0.0以上

## セットアップ

```batch
# 管理者権限で実行
Setup.bat
```

## 使用方法

### API エンドポイント

#### ヘルスチェック
```http
GET /health
```

#### テレビ電源状態取得
```http
GET /tv
```

### サービス管理

#### PM2を使用する場合
```bash
# サービス開始
npm run start:pm2

# サービス停止
npm run stop:pm2

# サービス再起動
npm run restart:pm2

# 状態確認
npm run status:pm2

# ログ確認
npm run logs:pm2
```

#### PowerShellスクリプトを使用する場合
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

## 設定

### ログレベル

- `error`: エラーのみ
- `warn`: 警告以上
- `info`: 情報以上（推奨）
- `debug`: デバッグ情報含む

## トラブルシューティング
### ログの確認

```bash
# アプリケーションログ
type logs\app.log

# PM2ログ
npm run logs:pm2
```

## アンインストール

```powershell
# 管理者権限で実行
.\scripts\Uninstall.ps1
```

## ライセンス

MIT License
