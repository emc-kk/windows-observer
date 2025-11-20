import { appendFileSync } from 'fs';
import { join } from 'path';
import { config } from '../config';

const APP_LOG = join(config.LOG_DIR, 'app.log');

export type LogLevel = 'info' | 'warn' | 'error' | 'debug';

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  data?: unknown;
}

/**
 * アプリケーションログを出力
 * コンソールとファイルの両方に記録
 */
export function log(level: LogLevel, message: string, data?: unknown): void {
  const timestamp = new Date().toISOString();
  const logEntry: LogEntry = { timestamp, level, message, data };

  // コンソールに出力
  const consoleMsg = `[${level.toUpperCase()}] ${message}`;
  switch (level) {
    case 'error':
      console.error(consoleMsg, data || '');
      break;
    case 'warn':
      console.warn(consoleMsg, data || '');
      break;
    default:
      console.log(consoleMsg, data || '');
  }

  // ファイルに保存
  try {
    appendFileSync(APP_LOG, JSON.stringify(logEntry) + '\n');
  } catch (e) {
    console.warn('[Logger] ファイル書き込み失敗:', (e as Error).message);
  }
}
