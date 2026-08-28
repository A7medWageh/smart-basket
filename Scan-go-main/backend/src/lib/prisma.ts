import { PrismaClient } from '@prisma/client';
import path from 'path';
import fs from 'fs';

let dbUrl = process.env.DATABASE_URL || 'file:./dev.db';

if (process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME) {
  const tmpDbPath = '/tmp/dev.db';
  const sourceDbPath = path.join(__dirname, '../../prisma/dev.db');
  const rootSourceDbPath = path.join(process.cwd(), 'Scan-go-main/backend/prisma/dev.db');
  
  if (!fs.existsSync(tmpDbPath)) {
    if (fs.existsSync(sourceDbPath)) {
      fs.copyFileSync(sourceDbPath, tmpDbPath);
    } else if (fs.existsSync(rootSourceDbPath)) {
      fs.copyFileSync(rootSourceDbPath, tmpDbPath);
    }
  }
  dbUrl = `file:${tmpDbPath}`;
}

export const prisma = new PrismaClient({
  datasources: {
    db: {
      url: dbUrl,
    },
  },
});
