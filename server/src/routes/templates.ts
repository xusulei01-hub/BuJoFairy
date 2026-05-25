import { Router, Response } from 'express';
import { AuthRequest, authMiddleware } from '../middleware/auth';

const router = Router();

interface TemplatePage {
  type: string;
  layout: string;
}

interface Template {
  id: string;
  name: string;
  category: string;
  description: string;
  thumbnailColor: string;
  pages: TemplatePage[];
}

const TEMPLATES: Template[] = [
  {
    id: 'city_walk', name: '城市漫步', category: 'city',
    description: '适合城市街拍与建筑主题', thumbnailColor: '#2C3E50',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'neon_city', name: '霓虹都市', category: 'city',
    description: '现代都市夜景风格', thumbnailColor: '#1A1A2E',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'photo_top_text_bottom' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'mountain_sea', name: '山海之间', category: 'nature',
    description: '自然风光与户外旅行', thumbnailColor: '#2D6A4F',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'daily', layout: 'text_top_photo_bottom' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'forest_tale', name: '森林物语', category: 'nature',
    description: '清新自然风格', thumbnailColor: '#40916C',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'taste_map', name: '味蕾地图', category: 'food',
    description: '美食探店记录', thumbnailColor: '#E07A5F',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'night_canteen', name: '深夜食堂', category: 'food',
    description: '温暖治愈系美食', thumbnailColor: '#3D405B',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'text_top_photo_bottom' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'old_days', name: '旧时光', category: 'vintage',
    description: '复古胶片风格', thumbnailColor: '#8B5E3C',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
  {
    id: 'film_diary', name: '胶片日记', category: 'vintage',
    description: '文艺人文游记', thumbnailColor: '#6B705C',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'ending', layout: 'summary_stats' },
    ],
  },
];

router.get('/', authMiddleware, (_req: AuthRequest, res: Response) => {
  res.json({ templates: TEMPLATES });
});

export default router;
