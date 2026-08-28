import { PrismaClient } from '@prisma/client';

let client: PrismaClient | null = null;

try {
  client = new PrismaClient();
} catch (err) {
  console.warn('⚠️ [Prisma] Failed to instantiate PrismaClient in serverless environment:', err);
}

export const prisma = client || ({} as any);
