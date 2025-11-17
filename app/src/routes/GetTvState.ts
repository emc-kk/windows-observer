import type { Request, Response } from 'express';

export interface TvStateResponse {
  state?: string | null;
}

export const GetTvState = async (_: Request, res: Response): Promise<void> => {
  // TODO: CMMで電源状態取得
  const state: string | null = null;
  const response: TvStateResponse = { state };
  res.json(response);
}