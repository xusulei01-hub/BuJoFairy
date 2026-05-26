import { Router, Request, Response } from 'express';
import { prisma } from '../prisma';
import { generateToken } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';
import { verifyAppleToken } from '../utils/appleAuth';
import { appleSignInSchema } from '../schemas';

const router = Router();

const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID || 'com.example.TravelJournal';

router.post('/apple', async (req: Request, res: Response) => {
  const body = appleSignInSchema.parse(req.body);

  let payload;
  try {
    payload = await verifyAppleToken(body.identityToken, APPLE_CLIENT_ID);
  } catch {
    throw new AppError(401, 'AUTH_FAILED', 'Apple 登录验证失败');
  }

  const verifiedAppleUserID = payload.sub;

  let user = await prisma.user.findUnique({ where: { appleUserID: verifiedAppleUserID } });

  if (!user) {
    user = await prisma.user.create({
      data: {
        appleUserID: verifiedAppleUserID,
        name: body.name || '旅行者',
      },
    });
  } else if (body.name && user.name === '旅行者') {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { name: body.name },
    });
  }

  const token = generateToken(user.id);
  res.json({
    token,
    user: {
      id: user.id,
      name: user.name,
    },
  });
});

export default router;
