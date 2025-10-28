// Get-CimInstance -Namespace root\wmi -Class WmiMonitorID
// .\ControlMyMonitor.exe /sjson $json
// (Get-Content $json | ConvertFrom-Json) | Where-Object { $_.'VCP Code' -eq 'D6'} | Select-Object -ExpandProperty 'Current Value'

import express from 'express';
import morgan from 'morgan';
import cors from 'cors';
import { execFile } from 'child_process';
import { join } from 'path';
import {
  existsSync,
  writeFileSync,
  appendFileSync
} from 'fs';

// ---- 設定 ----
const PORT = parseInt(process.env.PORT, 10);
const LOG_LEVEL = process.env.LOG_LEVEL
const LOG_FILE = process.env.LOG_FILE

const requestCounts = new Map();
const RATE_LIMIT_WINDOW = 60000; // 1分
const RATE_LIMIT_MAX = 100; // 最大リクエスト数

// ---- ユーティリティ ----
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const logEntry = { timestamp, level, message, data };

  console.log(`[${level.toUpperCase()}] ${message}`, data || '');

  try {
    appendFileSync(LOG_FILE, JSON.stringify(logEntry) + '\n');
  } catch (e) {
    console.warn('[WARN] ログファイルへの書き込みに失敗:', e.message);
  }
}

// レート制限（簡易版）
function rateLimit(req, res, next) {
  const clientIp = req.ip || req.connection.remoteAddress;
  const now = Date.now();

  if (!requestCounts.has(clientIp)) {
    requestCounts.set(clientIp, {
      count: 1,
      resetTime: now + RATE_LIMIT_WINDOW
    });
    return next();
  }

  const clientData = requestCounts.get(clientIp);

  if (now > clientData.resetTime) {
    clientData.count = 1;
    clientData.resetTime = now + RATE_LIMIT_WINDOW;
    return next();
  }

  if (clientData.count >= RATE_LIMIT_MAX) {
    log('warn', 'レート制限に達しました', {
      ip: clientIp,
      count: clientData.count
    });
    return res.status(429).json({
      error: 'Too many requests'
    });
  }

  clientData.count++;
  next();
}

// ---- サーバ ----
const app = express();

// セキュリティ設定
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : true,
  credentials: true
}));
app.use(rateLimit);
app.use(express.json({ limit: '1mb'}));
app.use(morgan('combined'));

app.get('/health', async (req, res) => {
  const timestamp = new Date().toISOString();
  const uptime = Math.floor(process.uptime());
  const memoryUsage = process.memoryUsage();
  const memoryUsageMb = Math.round(memoryUsage.heapUsed / 1024 / 1024);
  const memoryTotalMb = Math.round(memoryUsage.heapTotal / 1024 / 1024);
  const cmmHealthy = true; // TODO: CMMの状態チェック
  const statusCode = cmmHealthy ? 200 : 503;

  const health = {
    ok: cmmHealthy,
    timestamp,
    uptime,
    memory: {
      used: memoryUsageMb,
      total: memoryTotalMb
    },
  };

  res.status(statusCode).json(health);
});

app.get('/tv-state', async (req, res) => {
  // TODO: CMMで電源状態取得
  const state = null;
  res.json({});
});

app.listen(PORT, () => {
  console.log(`[tv-state-local] listening on http://127.0.0.1:${PORT}`);
});