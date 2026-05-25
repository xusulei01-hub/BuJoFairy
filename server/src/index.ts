import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import tripRoutes from './routes/trips';
import journalRoutes from './routes/journals';
import templateRoutes from './routes/templates';

const app = express();

app.use(cors());
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

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Travel Journal API running on port ${PORT}`);
});
