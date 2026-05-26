import { Router, Response } from 'express';
import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { createTripSchema, updateTripSchema, createLocationSchema } from '../schemas';

const router = Router();

router.use(authMiddleware);

// 获取用户所有旅行
router.get('/', async (req: AuthRequest, res: Response) => {
  const trips = await prisma.trip.findMany({
    where: { userId: req.userId },
    orderBy: { startDate: 'desc' },
    include: { locations: true, journals: { select: { id: true, title: true, coverURL: true } } },
  });
  res.json({ trips });
});

// 创建旅行
router.post('/', async (req: AuthRequest, res: Response) => {
  const body = createTripSchema.parse(req.body);
  const trip = await prisma.trip.create({
    data: {
      userId: req.userId!,
      name: body.name,
      startDate: new Date(body.startDate),
      endDate: body.endDate ? new Date(body.endDate) : null,
    },
  });
  res.status(201).json({ trip });
});

// 更新旅行
router.put('/:id', async (req: AuthRequest, res: Response) => {
  const id = req.params.id as string;
  const body = updateTripSchema.parse(req.body);

  const existing = await prisma.trip.findFirst({ where: { id, userId: req.userId } });
  if (!existing) { res.status(404).json({ error: '旅行不存在或无权限' }); return; }

  const updateData: Prisma.TripUpdateInput = {};
  if (body.name !== undefined) updateData.name = body.name;
  if (body.startDate !== undefined) updateData.startDate = new Date(body.startDate);
  if (body.endDate !== undefined) updateData.endDate = body.endDate ? new Date(body.endDate) : null;
  if (body.coverURL !== undefined) updateData.coverURL = body.coverURL;

  const updated = await prisma.trip.update({ where: { id }, data: updateData });
  res.json({ trip: updated });
});

// 删除旅行
router.delete('/:id', async (req: AuthRequest, res: Response) => {
  const id = req.params.id as string;
  const { count } = await prisma.trip.deleteMany({ where: { id, userId: req.userId } });
  if (count === 0) { res.status(404).json({ error: '旅行不存在或无权限' }); return; }
  res.json({ success: true });
});

// 添加地点
router.post('/:tripId/locations', async (req: AuthRequest, res: Response) => {
  const tripId = req.params.tripId as string;
  const body = createLocationSchema.parse(req.body);

  const trip = await prisma.trip.findFirst({ where: { id: tripId, userId: req.userId } });
  if (!trip) { res.status(404).json({ error: '旅行不存在' }); return; }

  const location = await prisma.location.create({
    data: { tripId, name: body.name, latitude: body.latitude, longitude: body.longitude },
  });
  res.status(201).json({ location });
});

// 删除地点
router.delete('/:tripId/locations/:locId', async (req: AuthRequest, res: Response) => {
  const tripId = req.params.tripId as string;
  const locId = req.params.locId as string;

  const trip = await prisma.trip.findFirst({ where: { id: tripId, userId: req.userId } });
  if (!trip) { res.status(404).json({ error: '旅行不存在或无权限' }); return; }

  const { count } = await prisma.location.deleteMany({ where: { id: locId, tripId } });
  if (count === 0) { res.status(404).json({ error: '地点不存在' }); return; }
  res.json({ success: true });
});

export default router;
