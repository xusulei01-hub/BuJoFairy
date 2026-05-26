import { prisma } from '../src/prisma';

// Clean database before each test
export async function cleanDatabase() {
  await prisma.journal.deleteMany();
  await prisma.location.deleteMany();
  await prisma.trip.deleteMany();
  await prisma.socialAccount.deleteMany();
  await prisma.user.deleteMany();
}

// Create a test user and return token
export async function createTestUser(appleUserID: string = 'test-apple-id') {
  const user = await prisma.user.create({
    data: { appleUserID, name: 'Test User' },
  });
  return user;
}

// Generate a valid JWT token for testing
export function generateTestToken(userId: string): string {
  const jwt = require('jsonwebtoken');
  return jwt.sign({ userId }, process.env.JWT_SECRET!, { expiresIn: '1h' });
}
