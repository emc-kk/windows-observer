import type { Request, Response } from 'express';
import { execCecAsync } from '../utils/execCecAsync';
import { log } from '../utils/logger';

export type TvOnResponse = { error?: string };

export const PostTvOn = async (_: Request, res: Response): Promise<Response<TvOnResponse>> => {
  try {
    await execCecAsync('on 0');
    return res.status(200).json({});
  } catch (error) {
    log('error', 'CEC テストコマンド失敗', { error });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}