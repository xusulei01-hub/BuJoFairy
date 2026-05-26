import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import tripRoutes from './routes/trips';
import journalRoutes from './routes/journals';
import templateRoutes from './routes/templates';
import { errorHandler } from './middleware/errorHandler';

export function createApp() {
  const app = express();

  const corsOrigin = process.env.CORS_ORIGIN;
  app.use(cors(corsOrigin ? { origin: corsOrigin } : undefined));
  app.use(express.json({ limit: '10mb' }));

  // Health check
  app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // Routes
  app.use('/api/auth', authRoutes);
  app.use('/api/trips', tripRoutes);
  app.use('/api/journals', journalRoutes);
  app.use('/api/templates', templateRoutes);

  // Global error handler
  app.use(errorHandler);

  return app;
}
