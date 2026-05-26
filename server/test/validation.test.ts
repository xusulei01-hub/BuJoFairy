import { describe, it, expect } from 'vitest';
import {
  createTripSchema,
  updateTripSchema,
  createJournalSchema,
  appleSignInSchema,
} from '../src/schemas';

describe('Zod Schemas', () => {
  describe('createTripSchema', () => {
    it('should accept valid data', () => {
      const result = createTripSchema.safeParse({
        name: 'Japan Trip',
        startDate: '2024-01-01T00:00:00Z',
      });
      expect(result.success).toBe(true);
    });

    it('should reject empty name', () => {
      const result = createTripSchema.safeParse({
        name: '',
        startDate: '2024-01-01T00:00:00Z',
      });
      expect(result.success).toBe(false);
    });

    it('should reject invalid date', () => {
      const result = createTripSchema.safeParse({
        name: 'Japan Trip',
        startDate: 'not-a-date',
      });
      expect(result.success).toBe(false);
    });

    it('should reject missing fields', () => {
      const result = createTripSchema.safeParse({ name: 'Japan Trip' });
      expect(result.success).toBe(false);
    });
  });

  describe('createJournalSchema', () => {
    const validContentJSON = JSON.stringify({
      pages: [{ type: 'cover', layout: 'full_photo_title_overlay', title: 'Trip', text: 'Great trip' }],
    });

    it('should accept valid contentJSON with pages', () => {
      const result = createJournalSchema.safeParse({
        tripId: 'trip-123',
        title: 'My Journal',
        contentJSON: validContentJSON,
      });
      expect(result.success).toBe(true);
    });

    it('should reject empty contentJSON', () => {
      const result = createJournalSchema.safeParse({
        tripId: 'trip-123',
        title: 'My Journal',
        contentJSON: '',
      });
      expect(result.success).toBe(false);
    });

    it('should reject malformed JSON', () => {
      const result = createJournalSchema.safeParse({
        tripId: 'trip-123',
        title: 'My Journal',
        contentJSON: 'not-json',
      });
      expect(result.success).toBe(false);
    });

    it('should reject contentJSON without pages', () => {
      const result = createJournalSchema.safeParse({
        tripId: 'trip-123',
        title: 'My Journal',
        contentJSON: '{"notPages":[]}',
      });
      expect(result.success).toBe(false);
    });
  });

  describe('appleSignInSchema', () => {
    it('should accept valid data', () => {
      const result = appleSignInSchema.safeParse({
        appleUserID: 'test-id',
        identityToken: 'valid-token-string',
        name: 'Test User',
      });
      expect(result.success).toBe(true);
    });

    it('should reject missing identityToken', () => {
      const result = appleSignInSchema.safeParse({
        appleUserID: 'test-id',
      });
      expect(result.success).toBe(false);
    });
  });
});
