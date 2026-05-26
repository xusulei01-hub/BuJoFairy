import { z } from 'zod';

export const createTripSchema = z.object({
  name: z.string().min(1, '旅行名称不能为空').max(100, '旅行名称过长'),
  startDate: z.string().datetime({ message: 'startDate 必须是有效的 ISO 日期字符串' }),
  endDate: z.string().datetime({ message: 'endDate 必须是有效的 ISO 日期字符串' }).optional().nullable(),
});

export const updateTripSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional().nullable(),
  coverURL: z.string().url().optional().nullable(),
});

export const createLocationSchema = z.object({
  name: z.string().min(1).max(100),
  latitude: z.number({ message: 'latitude 必须是数字' }).min(-90).max(90),
  longitude: z.number({ message: 'longitude 必须是数字' }).min(-180).max(180),
});

export const journalContentSchema = z.object({
  pages: z.array(z.object({
    type: z.string(),
    layout: z.string(),
    title: z.string().optional().nullable(),
    text: z.string().optional().nullable(),
    photoIndices: z.array(z.number().int().nonnegative()).optional().nullable(),
    caption: z.string().optional().nullable(),
  })),
});

// 接受 JSON 字符串，解析后校验结构
const contentJSONFromString = z.string().min(1, 'contentJSON 不能为空').transform((val, ctx) => {
  try {
    const parsed = JSON.parse(val);
    return journalContentSchema.parse(parsed);
  } catch {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'contentJSON 不是有效的 JSON' });
    return z.NEVER;
  }
});

// 也接受已解析的 JSON 对象
const contentJSONObject = journalContentSchema;

export const createJournalSchema = z.object({
  tripId: z.string().min(1, 'tripId 不能为空'),
  title: z.string().min(1, '标题不能为空').max(200, '标题过长'),
  templateID: z.string().optional(),
  contentJSON: contentJSONFromString,
  coverURL: z.string().url().optional().nullable(),
});

export const updateJournalSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  contentJSON: contentJSONFromString.optional(),
  coverURL: z.string().url().optional().nullable(),
});

export const appleSignInSchema = z.object({
  appleUserID: z.string().min(1),
  name: z.string().max(50).optional(),
  identityToken: z.string().min(1, 'identityToken 不能为空'),
});
