export const config = {
  PORT: parseInt(process.env.PORT || '8765', 10),
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : true,
  RATE_LIMIT: {
    WINDOW_MS: 60000, // 1分
    MAX_REQUESTS: 100, // 最大リクエスト数
  },
  CEC_CLIENT_PATH: process.env.CEC_CLIENT_PATH,
  CEC_LOGICAL_ADDR: process.env.CEC_LOGICAL_ADDR,
  LOG_DIR: process.env.LOG_DIR || 'log',
} as const;
