// Get-CimInstance -Namespace root\wmi -Class WmiMonitorID
// .\ControlMyMonitor.exe /sjson $json
// (Get-Content $json | ConvertFrom-Json) | Where-Object { $_.'VCP Code' -eq 'D6'} | Select-Object -ExpandProperty 'Current Value'

import 'dotenv/config';
import express from 'express';
import morgan from 'morgan';
import cors from 'cors';
import { createWriteStream } from 'fs';
import { join } from 'path';
import { config } from './config';
import { rateLimit } from './middleware/rateLimit';
import { GetHealth } from './routes/GetHealth';
import { GetTvState } from './routes/GetTvState';
import { execCecAsync } from './utils/execCecAsync';
import { log } from './utils/logger';

const app = express();

// アクセスログストリーム作成
const accessLogStream = createWriteStream(
  join(config.LOG_DIR, 'access.log'),
  { flags: 'a' } // append mode
);

// ミドルウェア設定
app.use(cors({
  origin: config.ALLOWED_ORIGINS,
  credentials: true
}));
app.use(rateLimit);
app.use(express.json({ limit: '1mb' }));

// HTTPアクセスログ（ファイルに保存）
app.use(morgan('combined', { stream: accessLogStream }));

// 開発時はコンソールにも出力
if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
}

// ルート設定
app.get('/health', GetHealth);
app.get('/tv-state', GetTvState);
app.get('/tv-on', GetTvState);
app.get('/tv-off', GetTvState);
app.get('/test', async (_, res) => {
  try {
    const output = await execCecAsync('pow 0');
    log('info', 'CEC テストコマンド実行', { output });
    return res.status(200).json({ output });
  } catch (error) {
    log('error', 'CEC テストコマンド失敗', { error });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// サーバー起動
app.listen(config.PORT, () => {
  log('info', 'サーバー起動', { port: config.PORT, url: `http://localhost:${config.PORT}` });
});
