import type { Request, Response } from 'express';
import { execCecAsync } from '../utils/execCecAsync';
import { log } from '../utils/logger';

export type TvOffResponse = { error?: string };

export const PostTvOff = async (_: Request, res: Response): Promise<Response<TvOffResponse>> => {
  try {
    await execCecAsync('standby 0');
    return res.status(200).json({});
  } catch (error) {
    log('error', 'CEC テストコマンド失敗', { error });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}