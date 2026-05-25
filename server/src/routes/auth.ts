import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { generateToken } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

interface AppleSignInBody {
  appleUserID: string;
  name?: string;
  identityToken?: string;
}

router.post('/apple', async (req: Request, res: Response) => {
  try {
    const { appleUserID, name, identityToken } = req.body as AppleSignInBody;
    
    if (!appleUserID) {
      res.status(400).json({ error: '缺少 appleUserID' });
      return;
    }
    
    // 生产环境需验证 Apple identityToken
    // 开发阶段：直接查找或创建用户
    
    let user = await prisma.user.findUnique({ where: { appleUserID } });
    
    if (!user) {
      user = await prisma.user.create({
        data: {
          appleUserID,
          name: name || '旅行者',
        },
      });
    } else if (name && user.name === '旅行者') {
      // 更新用户名（首次登录时 Apple 只返回一次名字）
      user = await prisma.user.update({
        where: { id: user.id },
        data: { name },
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
  } catch (error) {
    console.error('Apple sign in error:', error);
    res.status(500).json({ error: '登录失败' });
  }
});

export default router;
