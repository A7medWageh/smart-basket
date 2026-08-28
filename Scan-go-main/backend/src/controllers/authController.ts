import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../lib/prisma';
import { ENV } from '../config/env';
import { AuthRequest } from '../middlewares/authMiddleware';
import { CartService } from '../services/cartService';

export class AuthController {
  /**
   * Register a new user
   */
  static async register(req: Request, res: Response) {
    try {
      const { name, fullName, email, password, phone } = req.body;
      const displayName = (name || fullName || '').toString().trim();

      if (!displayName || !email || !password) {
        return res.status(400).json({
          success: false,
          message: 'Please provide name, email, and password.',
        });
      }

      const existingUser = await prisma.user.findUnique({
        where: { email: email.toLowerCase().trim() },
      });

      if (existingUser) {
        return res.status(400).json({
          success: false,
          message: 'An account with this email already exists.',
        });
      }

      const passwordHash = await bcrypt.hash(password, 10);

      const user = await prisma.user.create({
        data: {
          name: displayName,
          email: email.toLowerCase().trim(),
          phone: phone || null,
          password: passwordHash,
        },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          faceEnrolled: true,
          createdAt: true,
        },
      });

      const token = jwt.sign(
        { id: user.id, email: user.email, name: user.name },
        ENV.JWT_SECRET,
        { expiresIn: '30d' }
      );

      return res.status(201).json({
        success: true,
        message: 'Account created successfully',
        data: {
          user,
          token,
        },
      });
    } catch (error: any) {
      console.error('Registration error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error creating user account',
        error: error.message,
      });
    }
  }

  /**
   * Log in an existing user
   */
  static async login(req: Request, res: Response) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({
          success: false,
          message: 'Email and password are required',
        });
      }

      const user = await prisma.user.findUnique({
        where: { email: email.toLowerCase().trim() },
      });

      if (!user) {
        return res.status(401).json({
          success: false,
          message: 'Invalid email or password',
        });
      }

      const isPasswordValid = await bcrypt.compare(password, user.password);
      if (!isPasswordValid) {
        return res.status(401).json({
          success: false,
          message: 'Invalid email or password',
        });
      }

      const token = jwt.sign(
        { id: user.id, email: user.email, name: user.name },
        ENV.JWT_SECRET,
        { expiresIn: '30d' }
      );

      // Check if user has an active cart session
      const activeSession = await CartService.getActiveSessionByUserId(user.id);

      return res.json({
        success: true,
        message: 'Login successful',
        data: {
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            phone: user.phone,
            faceEnrolled: user.faceEnrolled,
          },
          token,
          activeCart: CartService.formatCartResponse(activeSession),
        },
      });
    } catch (error: any) {
      console.error('Login error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error processing login',
        error: error.message,
      });
    }
  }

  /**
   * Get current authenticated user profile
   */
  static async getMe(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          faceEnrolled: true,
          createdAt: true,
        },
      });

      const activeSession = await CartService.getActiveSessionByUserId(req.user.id);

      return res.json({
        success: true,
        data: {
          user,
          activeCart: CartService.formatCartResponse(activeSession),
        },
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Error fetching user profile',
        error: error.message,
      });
    }
  }

  /**
   * Register Face ID against the logged-in account.
   * The mobile app captures the face locally; this endpoint stores enrollment status.
   */
  static async enrollFace(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const user = await prisma.user.update({
        where: { id: req.user.id },
        data: {
          faceEnrolled: true,
          faceEnrolledAt: new Date(),
        },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          faceEnrolled: true,
          faceEnrolledAt: true,
        },
      });

      return res.json({
        success: true,
        message: 'Face enrolled successfully',
        data: { user },
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Failed to enroll Face ID',
        error: error.message,
      });
    }
  }

  /**
   * Verify Face ID for the logged-in user and optionally secure the active cart session.
   */
  static async verifyFace(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          faceEnrolled: true,
        },
      });

      if (!user) {
        return res.status(401).json({ success: false, message: 'User not found' });
      }

      const { cartCode } = req.body || {};
      let activeCart = await CartService.getActiveSessionByUserId(user.id);

      if (cartCode && !activeCart) {
        return res.status(404).json({
          success: false,
          message: 'No active cart session found. Pair a cart first.',
        });
      }

      if (activeCart && !activeCart.faceVerified) {
        activeCart = await CartService.verifySessionFace(activeCart.id);
      }

      const formatted = CartService.formatCartResponse(activeCart);

      return res.json({
        success: true,
        message: 'Face verified successfully',
        data: {
          user,
          userId: user.id,
          token: jwt.sign(
            { id: user.id, email: user.email, name: user.name },
            ENV.JWT_SECRET,
            { expiresIn: '30d' }
          ),
          activeCart: formatted,
        },
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Failed to verify Face ID',
        error: error.message,
      });
    }
  }
}
