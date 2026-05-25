import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest, authMiddleware } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.use(authMiddleware);

// 获取用户所有手帐
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const journals = await prisma.journal.findMany({
      where: { trip: { userId: req.userId } },
      orderBy: { createdAt: 'desc' },
      include: { trip: { select: { id: true, name: true } } },
    });
    res.json({ journals });
  } catch (error) {
    res.status(500).json({ error: '获取手帐列表失败' });
  }
});

// 创建手帐
router.post('/', async (req: AuthRequest, res: Response) => {
  try {
    const { tripId, title, templateID, contentJSON, coverURL } = req.body;
    if (!tripId || !title || !contentJSON) {
      res.status(400).json({ error: '缺少必填字段' });
      return;
    }
    const jsonStr = typeof contentJSON === 'string' ? contentJSON : JSON.stringify(contentJSON);
    const journal = await prisma.journal.create({
      data: {
        tripId,
        title,
        templateID: templateID || 'auto',
        contentJSON: jsonStr,
        coverURL: coverURL || null,
      },
    });
    res.status(201).json({ journal });
  } catch (error) {
    res.status(500).json({ error: '创建手帐失败' });
  }
});

// 更新手帐
router.put('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const { title, contentJSON, coverURL } = req.body;
    const updateData: Record<string, unknown> = {};
    if (title !== undefined) updateData.title = title;
    if (contentJSON !== undefined) updateData.contentJSON = typeof contentJSON === 'string' ? contentJSON : JSON.stringify(contentJSON);
    if (coverURL !== undefined) updateData.coverURL = coverURL;

    await prisma.journal.updateMany({ where: { id }, data: updateData });
    const updated = await prisma.journal.findUnique({ where: { id } });
    res.json({ journal: updated });
  } catch (error) {
    res.status(500).json({ error: '更新手帐失败' });
  }
});

// 删除手帐
router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    await prisma.journal.deleteMany({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: '删除手帐失败' });
  }
});

export default router;
