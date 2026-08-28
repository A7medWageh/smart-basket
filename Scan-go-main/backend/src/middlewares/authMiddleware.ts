import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env';
import { prisma } from '../lib/prisma';

export interface AuthRequest extends Request {
  user?: {
    id: number;
    email: string;
    name: string;
  };
}

export const authenticateJWT = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      success: false,
      message: 'Unauthorized: Missing or invalid token format. Please log in.',
    });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, ENV.JWT_SECRET) as {
      id: number;
      email: string;
      name: string;
    };

    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: { id: true, email: true, name: true },
    });

    if (!user) {
      res.status(401).json({ success: false, message: 'User not found' });
      return;
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({
      success: false,
      message: 'Unauthorized: Token is invalid or has expired',
    });
  }
};
