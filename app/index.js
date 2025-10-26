import express from 'express';
import morgan from 'morgan';
import cors from 'cors';
import {
  execFile
} from 'child_process';
import {
  existsSync,
  writeFileSync,
  appendFileSync
} from 'fs';
import {
  join
} from 'path';

// ---- 設定 ----
const PORT = parseInt(process.env.PORT || '8765', 10);
const CEC = process.env.CEC_CLIENT_PATH || 'C:\\Program Files (x86)\\Pulse-Eight\\USB-CEC Adapter\\cec-client.exe'; // 既定パス
const TV_ADDR = process.env.CEC_LOGICAL_ADDR || '0'; // 0 = TV
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const LOG_FILE = process.env.LOG_FILE || join(process.cwd(), 'logs', 'app.log');

// ログディレクトリの作成
const logDir = join(process.cwd(), 'logs');
if (!existsSync(logDir)) {
  try {
    require('fs').mkdirSync(logDir, {
      recursive: true
    });
  } catch (e) {
    console.warn('[WARN] ログディレクトリの作成に失敗:', e.message);
  }
}

// ログ機能
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    data
  };

  console.log(`[${level.toUpperCase()}] ${message}`, data || '');

  try {
    appendFileSync(LOG_FILE, JSON.stringify(logEntry) + '\n');
  } catch (e) {
    console.warn('[WARN] ログファイルへの書き込みに失敗:', e.message);
  }
}

if (!existsSync(CEC)) {
  log('warn', 'cec-client.exe が見つかりません', {
    path: CEC
  });
  log('warn', '.env の CEC_CLIENT_PATH を設定してください');
}

// ---- ユーティリティ ----
function runCEC(argsStr) {
  return new Promise((resolve, reject) => {
    // cec-client.exe -s -d 1 "pow 0"
    const args = ['-s', '-d', '1', argsStr];
    log('debug', 'CECコマンド実行', {
      command: CEC,
      args: argsStr
    });

    execFile(CEC, args, {
      windowsHide: true,
      timeout: 10000 // 10秒タイムアウト
    }, (err, stdout, stderr) => {
      if (err) {
        log('error', 'CECコマンド実行エラー', {
          command: argsStr,
          error: err.message,
          code: err.code
        });
        return reject(err);
      }
      const out = (stdout || '') + (stderr || '');
      log('debug', 'CECコマンド結果', {
        command: argsStr,
        output: out
      });
      resolve(out);
    });
  });
}

async function getTvPowerState() {
  try {
    const out = await runCEC(`"pow ${TV_ADDR}"`);
    // 返り値に on / standby / in transition 等が含まれる
    const low = out.toLowerCase();
    let state = 'unknown';

    if (low.includes('on')) {
      state = 'on';
    } else if (low.includes('standby') || low.includes('off')) {
      state = 'standby';
    }

    log('info', 'テレビ電源状態取得', {
      state,
      output: out
    });
    return state;
  } catch (e) {
    log('error', 'テレビ電源状態取得エラー', {
      error: e.message
    });
    return 'unknown';
  }
}

async function tvPowerOn() {
  await runCEC(`"on ${TV_ADDR}"`);
}
async function tvSetActiveSource() {
  await runCEC('"as"'); // Active Source
}

// ---- サーバ ----
const app = express();

// セキュリティ設定
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : true,
  credentials: true
}));

// レート制限（簡易版）
const requestCounts = new Map();
const RATE_LIMIT_WINDOW = 60000; // 1分
const RATE_LIMIT_MAX = 100; // 最大リクエスト数

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

app.use(rateLimit);
app.use(express.json({
  limit: '1mb'
}));
app.use(morgan('combined'));

// ヘルスチェック機能
let lastCecCheck = null;
let cecStatus = 'unknown';

async function checkCecHealth() {
  try {
    if (!existsSync(CEC)) {
      cecStatus = 'not_found';
      return false;
    }

    const out = await runCEC('"scan"');
    cecStatus = out.includes('device') ? 'connected' : 'disconnected';
    lastCecCheck = new Date().toISOString();
    return cecStatus === 'connected';
  } catch (e) {
    cecStatus = 'error';
    log('error', 'CECヘルスチェックエラー', {
      error: e.message
    });
    return false;
  }
}

app.get('/health', async (req, res) => {
  const cecHealthy = await checkCecHealth();
  const uptime = process.uptime();
  const memoryUsage = process.memoryUsage();

  const health = {
    ok: cecHealthy,
    timestamp: new Date().toISOString(),
    uptime: Math.floor(uptime),
    memory: {
      used: Math.round(memoryUsage.heapUsed / 1024 / 1024),
      total: Math.round(memoryUsage.heapTotal / 1024 / 1024)
    },
    cec: {
      status: cecStatus,
      lastCheck: lastCecCheck,
      path: CEC
    }
  };

  const statusCode = cecHealthy ? 200 : 503;
  res.status(statusCode).json(health);
});

app.get('/tv-state', async (req, res) => {
  const state = await getTvPowerState();
  res.json({
    state
  });
});

// オプション: WebからTVを起こす/入力を取る
app.post('/tv/on', async (req, res) => {
  try {
    await tvPowerOn();
    // 待機 → 入力をアクティブ化
    setTimeout(async () => {
      try {
        await tvSetActiveSource();
      } catch {}
    }, 2000);
    res.json({
      ok: true
    });
  } catch (e) {
    res.status(500).json({
      ok: false,
      error: String(e)
    });
  }
});

app.post('/tv/as', async (req, res) => {
  try {
    await tvSetActiveSource();
    res.json({
      ok: true
    });
  } catch (e) {
    res.status(500).json({
      ok: false,
      error: String(e)
    });
  }
});

app.listen(PORT, () => {
  console.log(`[tv-state-local] listening on http://127.0.0.1:${PORT}`);
  console.log(`CEC client: ${CEC}`);
});