import 'dotenv/config';
import { createApp } from './app';

const app = createApp();

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Travel Journal API running on port ${PORT}`);
});
