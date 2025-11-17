import type { Request, Response } from 'express';

export interface HealthResponse {
  ok: boolean;
  timestamp: string;
  uptime: number;
  memory: {
    used: number;
    total: number;
  };
}

export const GetHealth = async (_: Request, res: Response): Promise<void> => {
  const timestamp = new Date().toISOString();
  const uptime = Math.floor(process.uptime());
  const memoryUsage = process.memoryUsage();
  const memoryUsageMb = Math.round(memoryUsage.heapUsed / 1024 / 1024);
  const memoryTotalMb = Math.round(memoryUsage.heapTotal / 1024 / 1024);
  const cmmHealthy = true; // TODO: CMMの状態チェック
  const statusCode = cmmHealthy ? 200 : 503;

  const health: HealthResponse = {
    ok: cmmHealthy,
    timestamp,
    uptime,
    memory: {
      used: memoryUsageMb,
      total: memoryTotalMb
    },
  };

  res.status(statusCode).json(health);
};