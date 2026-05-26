import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';

export class AppError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: Record<string, string[]>
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.message,
      code: err.code,
      details: err.details,
    });
    return;
  }

  if (err instanceof ZodError) {
    const details: Record<string, string[]> = {};
    for (const issue of err.issues) {
      const path = issue.path.join('.');
      details[path] = details[path] ?? [];
      details[path].push(issue.message);
    }
    res.status(400).json({
      error: '请求参数校验失败',
      code: 'VALIDATION_ERROR',
      details,
    });
    return;
  }

  console.error('Unhandled error:', err);
  res.status(500).json({
    error: '服务器内部错误',
    code: 'INTERNAL_ERROR',
  });
}
