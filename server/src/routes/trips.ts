import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest, authMiddleware } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.use(authMiddleware);

// 获取用户所有旅行
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const trips = await prisma.trip.findMany({
      where: { userId: req.userId },
      orderBy: { startDate: 'desc' },
      include: { locations: true, journals: { select: { id: true, title: true, coverURL: true } } },
    });
    res.json({ trips });
  } catch (error) {
    res.status(500).json({ error: '获取旅行列表失败' });
  }
});

// 创建旅行
router.post('/', async (req: AuthRequest, res: Response) => {
  try {
    const { name, startDate, endDate } = req.body;
    if (!name || !startDate) {
      res.status(400).json({ error: '缺少必填字段' });
      return;
    }
    const trip = await prisma.trip.create({
      data: {
        userId: req.userId!,
        name,
        startDate: new Date(startDate),
        endDate: endDate ? new Date(endDate) : null,
      },
    });
    res.status(201).json({ trip });
  } catch (error) {
    res.status(500).json({ error: '创建旅行失败' });
  }
});

// 更新旅行
router.put('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    const { name, startDate, endDate, coverURL } = req.body;
    const updateData: Record<string, unknown> = {};
    if (name !== undefined) updateData.name = name;
    if (startDate !== undefined) updateData.startDate = new Date(startDate);
    if (endDate !== undefined) updateData.endDate = endDate ? new Date(endDate) : null;
    if (coverURL !== undefined) updateData.coverURL = coverURL;

    await prisma.trip.updateMany({ where: { id, userId: req.userId }, data: updateData });
    const updated = await prisma.trip.findUnique({ where: { id } });
    res.json({ trip: updated });
  } catch (error) {
    res.status(500).json({ error: '更新旅行失败' });
  }
});

// 删除旅行
router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const id = req.params.id as string;
    await prisma.trip.deleteMany({ where: { id, userId: req.userId } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: '删除旅行失败' });
  }
});

// 添加地点
router.post('/:tripId/locations', async (req: AuthRequest, res: Response) => {
  try {
    const tripId = req.params.tripId as string;
    const { name, latitude, longitude } = req.body;
    const trip = await prisma.trip.findFirst({ where: { id: tripId, userId: req.userId } });
    if (!trip) { res.status(404).json({ error: '旅行不存在' }); return; }
    const location = await prisma.location.create({
      data: { tripId, name, latitude, longitude },
    });
    res.status(201).json({ location });
  } catch (error) {
    res.status(500).json({ error: '添加地点失败' });
  }
});

// 删除地点
router.delete('/:tripId/locations/:locId', async (req: AuthRequest, res: Response) => {
  try {
    const tripId = req.params.tripId as string; const locId = req.params.locId as string;
    await prisma.location.deleteMany({ where: { id: locId, tripId } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: '删除地点失败' });
  }
});

export default router;
