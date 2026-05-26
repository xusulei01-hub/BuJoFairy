import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app';
import { cleanDatabase, createTestUser, generateTestToken } from './setup';
import { prisma } from '../src/prisma';

describe('Auth', () => {
  beforeEach(async () => {
    await cleanDatabase();
  });

  describe('POST /api/auth/apple', () => {
    it('should reject request without identityToken', async () => {
      const app = createApp();
      const res = await request(app)
        .post('/api/auth/apple')
        .send({ appleUserID: 'test-id', name: 'Test' });

      expect(res.status).toBe(400);
      expect(res.body.error).toBeDefined();
    });

    it('should reject invalid identityToken', async () => {
      const app = createApp();
      const res = await request(app)
        .post('/api/auth/apple')
        .send({ appleUserID: 'test-id', name: 'Test', identityToken: 'invalid-token' });

      expect(res.status).toBe(401);
    });
  });

  describe('Auth Middleware', () => {
    it('should reject requests without Authorization header', async () => {
      const app = createApp();
      const res = await request(app).get('/api/trips');
      expect(res.status).toBe(401);
    });

    it('should reject invalid token', async () => {
      const app = createApp();
      const res = await request(app)
        .get('/api/trips')
        .set('Authorization', 'Bearer invalid-token');
      expect(res.status).toBe(401);
    });

    it('should accept valid token', async () => {
      const app = createApp();
      const user = await createTestUser();
      const token = generateTestToken(user.id);

      const res = await request(app)
        .get('/api/trips')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.trips).toEqual([]);
    });
  });
});
