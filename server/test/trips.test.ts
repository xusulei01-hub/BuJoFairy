import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app';
import { cleanDatabase, createTestUser, generateTestToken } from './setup';

describe('Trips', () => {
  let token: string;
  let userId: string;

  beforeEach(async () => {
    await cleanDatabase();
    const user = await createTestUser();
    userId = user.id;
    token = generateTestToken(user.id);
  });

  describe('GET /api/trips', () => {
    it('should return empty array for new user', async () => {
      const app = createApp();
      const res = await request(app)
        .get('/api/trips')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.trips).toEqual([]);
    });
  });

  describe('POST /api/trips', () => {
    it('should create a trip with valid data', async () => {
      const app = createApp();
      const res = await request(app)
        .post('/api/trips')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Japan Trip', startDate: '2024-01-01T00:00:00Z' });

      expect(res.status).toBe(201);
      expect(res.body.trip.name).toBe('Japan Trip');
      expect(res.body.trip.userId).toBe(userId);
    });

    it('should reject invalid date format', async () => {
      const app = createApp();
      const res = await request(app)
        .post('/api/trips')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Japan Trip', startDate: 'not-a-date' });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });

    it('should reject empty name', async () => {
      const app = createApp();
      const res = await request(app)
        .post('/api/trips')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: '', startDate: '2024-01-01T00:00:00Z' });

      expect(res.status).toBe(400);
    });
  });

  describe('PUT /api/trips/:id', () => {
    it('should prevent updating another users trip', async () => {
      const app = createApp();

      // Create a trip for user1
      const createRes = await request(app)
        .post('/api/trips')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'My Trip', startDate: '2024-01-01T00:00:00Z' });
      const tripId = createRes.body.trip.id;

      // Create another user
      const { createTestUser: createUser2, generateTestToken: genToken2 } = await import('./setup');
      const user2 = await createUser2('other-apple-id');
      const token2 = genToken2(user2.id);

      // Try to update with user2's token
      const res = await request(app)
        .put(`/api/trips/${tripId}`)
        .set('Authorization', `Bearer ${token2}`)
        .send({ name: 'Hacked Trip' });

      expect(res.status).toBe(404);
    });
  });
});
