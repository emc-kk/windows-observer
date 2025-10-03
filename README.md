# Windows Observer - HDMI CEC監視アプリケーション

Windows環境でHDMI CECを使用してテレビの電源状態を監視・制御するアプリケーションです。

## 機能

- **テレビ電源状態の監視**: HDMI CEC経由でテレビの電源状態を取得
- **テレビ電源制御**: リモートでテレビの電源ON/OFF
- **入力切り替え**: アクティブソースの設定
- **RESTful API**: HTTP API経由での操作
- **自動起動**: WindowsタスクスケジューラまたはPM2によるデーモン化
- **ログ機能**: 構造化されたログファイル
- **ヘルスチェック**: システム状態の監視

## 必要な環境

- Windows 10/11
- Node.js 18.0.0以上
- Pulse-Eight USB-CEC Adapter
- libCECライブラリ

## セットアップ

### 1. 自動セットアップ（推奨）

```batch
# 管理者権限で実行
Setup.bat
```

### 2. 手動セットアップ

1. **libCECのインストール**
   - [Pulse-Eight公式サイト](https://www.pulse-eight.com/p/1041/usb-hdmi-cec-adapter)からダウンロード
   - `install/libcec-setup/`フォルダに配置

2. **Node.jsのインストール**
   - [Node.js公式サイト](https://nodejs.org/)からLTS版をダウンロード
   - `install/node-setup/`フォルダに配置（wingetが利用できない場合）

3. **アプリケーションの配置**
   ```powershell
   # 管理者権限で実行
   .\scripts\Setup.ps1
   ```

## 使用方法

### API エンドポイント

#### ヘルスチェック
```http
GET /health
```
システムの状態とCEC接続状況を確認

#### テレビ電源状態取得
```http
GET /tv-state
```
テレビの電源状態を取得（`on`, `standby`, `unknown`）

#### テレビ電源ON
```http
POST /tv/on
```
テレビの電源をONにし、アクティブソースを設定

#### アクティブソース設定
```http
POST /tv/as
```
現在の入力ソースをアクティブに設定

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

### 環境変数（.envファイル）

```env
# CEC設定
CEC_CLIENT_PATH=C:\Program Files (x86)\Pulse-Eight\USB-CEC Adapter\cec-client.exe
CEC_LOGICAL_ADDR=0

# サーバー設定
PORT=8765
LOG_LEVEL=info
LOG_FILE=logs/app.log

# セキュリティ設定
ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

### ログレベル

- `error`: エラーのみ
- `warn`: 警告以上
- `info`: 情報以上（推奨）
- `debug`: デバッグ情報含む

## トラブルシューティング

### よくある問題

1. **CECクライアントが見つからない**
   - `.env`ファイルの`CEC_CLIENT_PATH`を確認
   - libCECが正しくインストールされているか確認

2. **テレビが検出されない**
   - HDMIケーブルがCEC対応か確認
   - テレビのCEC設定が有効か確認
   - USB-CECアダプターが正しく接続されているか確認

3. **サービスが起動しない**
   - 管理者権限で実行されているか確認
   - ファイアウォール設定を確認
   - ログファイルを確認

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
