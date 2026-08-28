import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  PORT: process.env.PORT ? parseInt(process.env.PORT, 10) : 5001,
  JWT_SECRET: process.env.JWT_SECRET || 'scan_go_super_secret_jwt_key_2026',
  NODE_ENV: process.env.NODE_ENV || 'development',
};
