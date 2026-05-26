import { Router, Response } from 'express';
import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { createJournalSchema, updateJournalSchema } from '../schemas';

const router = Router();

router.use(authMiddleware);

// 获取用户所有手帐
router.get('/', async (req: AuthRequest, res: Response) => {
  const journals = await prisma.journal.findMany({
    where: { trip: { userId: req.userId } },
    orderBy: { createdAt: 'desc' },
    include: { trip: { select: { id: true, name: true } } },
  });
  res.json({ journals });
});

// 创建手帐
router.post('/', async (req: AuthRequest, res: Response) => {
  const body = createJournalSchema.parse(req.body);

  const trip = await prisma.trip.findFirst({ where: { id: body.tripId, userId: req.userId } });
  if (!trip) { res.status(404).json({ error: '旅行不存在或无权限' }); return; }

  const journal = await prisma.journal.create({
    data: {
      tripId: body.tripId,
      title: body.title,
      templateID: body.templateID || 'auto',
      contentJSON: body.contentJSON,
      coverURL: body.coverURL || null,
    },
  });
  res.status(201).json({ journal });
});

// 更新手帐
router.put('/:id', async (req: AuthRequest, res: Response) => {
  const id = req.params.id as string;
  const body = updateJournalSchema.parse(req.body);

  const existing = await prisma.journal.findFirst({
    where: { id, trip: { userId: req.userId } },
  });
  if (!existing) { res.status(404).json({ error: '手帐不存在或无权限' }); return; }

  const updateData: Prisma.JournalUpdateInput = {};
  if (body.title !== undefined) updateData.title = body.title;
  if (body.contentJSON !== undefined) updateData.contentJSON = body.contentJSON;
  if (body.coverURL !== undefined) updateData.coverURL = body.coverURL;

  const updated = await prisma.journal.update({ where: { id }, data: updateData });
  res.json({ journal: updated });
});

// 删除手帐
router.delete('/:id', async (req: AuthRequest, res: Response) => {
  const id = req.params.id as string;
  const existing = await prisma.journal.findFirst({
    where: { id, trip: { userId: req.userId } },
  });
  if (!existing) { res.status(404).json({ error: '手帐不存在或无权限' }); return; }

  await prisma.journal.delete({ where: { id } });
  res.json({ success: true });
});

export default router;
