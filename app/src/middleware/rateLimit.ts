import type { Request, Response, NextFunction } from 'express';
import { config } from '../config';
import { log } from '../utils/logger';

export interface RateLimitData {
  count: number;
  resetTime: number;
}

const requestCounts = new Map<string, RateLimitData>();

export function rateLimit(req: Request, res: Response, next: NextFunction): void | Response {
  const clientIp = req.ip || req.socket.remoteAddress || 'unknown';
  const now = Date.now();

  if (!requestCounts.has(clientIp)) {
    requestCounts.set(clientIp, {
      count: 1,
      resetTime: now + config.RATE_LIMIT.WINDOW_MS
    });
    return next();
  }

  const clientData = requestCounts.get(clientIp);

  if (!clientData) {
    return next();
  }

  if (now > clientData.resetTime) {
    clientData.count = 1;
    clientData.resetTime = now + config.RATE_LIMIT.WINDOW_MS;
    return next();
  }

  if (clientData.count >= config.RATE_LIMIT.MAX_REQUESTS) {
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
