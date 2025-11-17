import { execFile } from 'child_process';
import { config } from '../config';
import { log } from './logger';

const CEC_TIMEOUT = 10_000; // 10秒
const CEC_ARGS = ['-s', '-d', '1'];

/**
 * CEC コマンドを実行
 * @param command CECコマンド文字列 (例: "pow 0", "on 0")
 * @returns 実行結果の出力
 */
export async function execCecAsync(command: string): Promise<string> {
  const { CEC_CLIENT_PATH } = config;

  if (!CEC_CLIENT_PATH) {
    throw new Error('CEC_CLIENT_PATH が設定されていません');
  }

  log('info', 'CEC コマンド実行', { command });

  try {
    const output = await new Promise<string>((resolve, reject) => {
      const child = execFile(
        CEC_CLIENT_PATH,
        CEC_ARGS,
        {
          windowsHide: true,
          timeout: CEC_TIMEOUT,
        },
        (error, stdout, stderr) => {
          if (error) {
            const err = error as Error & { code?: string };
            log('error', 'CEC コマンド失敗', {
              command,
              error: err.message,
              code: err.code,
            });
            return reject(err);
          }

          const out = stdout + stderr;
          log('info', 'CEC コマンド成功', { command, output: out });
          resolve(out);
        },
      );

      // PowerShell の `"pow 0" | cec-client -s -d 1` を再現
      child.stdin?.write(command + '\n');
      child.stdin?.end();
    });

    return output;
  } catch (error) {
    throw error;
  }
}
