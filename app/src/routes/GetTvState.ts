import type { Request, Response } from 'express';
import { execCecAsync } from '../utils/execCecAsync';
import { log } from '../utils/logger';

export type TvStateResponse =
  | { tvOn: boolean }
  | { error: string };

export const GetTvState = async (_: Request, res: Response): Promise<Response<TvStateResponse>> => {
  try {
    const output = await execCecAsync('pow 0');
    const tvOn = output.includes('power status: on');
    return res.status(200).json({ tvOn });
  } catch (error) {
    log('error', 'CEC テストコマンド失敗', { error });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}