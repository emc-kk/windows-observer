# Windows Observer

Windows環境でテレビの電源状態を監視・制御するアプリケーションです。

## 動作環境・必要品
- Windows 10/11
- USB-CEC Adapter
- CEC対応テレビ

## セットアップ

Setup.batファイルを管理者権限で実行

※ アンインストールする場合はUninstall.batを使用

詳しくは[setup.md](./setup.md)を参照

## API エンドポイント

```shell
# ヘルスチェック
GET /health
# テレビ電源状態取得
GET /tv-state
# テレビ電源オン
POST /tv-on
# テレビ電源オフ
POST /tv-off
```

## ライセンス

MIT License
