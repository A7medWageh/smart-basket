import { Response } from 'express';
import { prisma } from '../lib/prisma';
import { AuthRequest } from '../middlewares/authMiddleware';
import { CartService } from '../services/cartService';
import { socketService } from '../services/socketService';

export class CartController {
  /**
   * Pair mobile app with physical cart via QR code (cartCode: "CART_01")
   * Accepts optional faceVerified boolean
   */
  static async pairCart(req: AuthRequest, res: Response) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { cartCode, faceVerified = false } = req.body;
      if (!cartCode) {
        return res.status(400).json({
          success: false,
          message: 'cartCode is required (e.g. "CART_01")',
        });
      }

      const normalizedCode = cartCode.trim().toUpperCase();

      // Find cart in DB
      let cart = await prisma.cart.findUnique({
        where: { cartCode: normalizedCode },
      });

      if (!cart) {
        // Auto-create cart if it doesn't exist yet for seamless testing
        cart = await prisma.cart.create({
          data: {
            cartCode: normalizedCode,
            status: 'AVAILABLE',
          },
        });
      }

      // Check if user already has an active session for this cart
      const currentActiveSession = await prisma.shoppingSession.findFirst({
        where: {
          userId,
          status: 'ACTIVE',
        },
      });

      if (currentActiveSession && currentActiveSession.cartId === cart.id) {
        // Update Face ID status if passed
        if (faceVerified && !currentActiveSession.faceVerified) {
          await CartService.verifySessionFace(currentActiveSession.id);
        }

        const sessionData = await CartService.getActiveSessionByUserId(userId);
        const formatted = CartService.formatCartResponse(sessionData);

        return res.json({
          success: true,
          message: 'Cart already paired and active',
          data: formatted,
        });
      }

      // If user had another active session, cancel or complete it first
      if (currentActiveSession) {
        await prisma.shoppingSession.update({
          where: { id: currentActiveSession.id },
          data: { status: 'CANCELLED', completedAt: new Date() },
        });

        // Set previous cart back to AVAILABLE
        await prisma.cart.update({
          where: { id: currentActiveSession.cartId },
          data: { status: 'AVAILABLE' },
        });
      }

      // Update cart status to IN_USE
      await prisma.cart.update({
        where: { id: cart.id },
        data: { status: 'IN_USE' },
      });

      // Create new active shopping session
      const newSession = await prisma.shoppingSession.create({
        data: {
          userId,
          cartId: cart.id,
          status: 'ACTIVE',
          faceVerified: Boolean(faceVerified),
          faceVerifiedAt: faceVerified ? new Date() : null,
        },
        include: {
          cart: true,
          items: { include: { product: true } },
        },
      });

      const formatted = CartService.formatCartResponse(newSession);

      // Notify socket rooms
      socketService.emitToCart(normalizedCode, 'cart:paired', {
        userId,
        cartCode: normalizedCode,
        session: formatted,
      });
      socketService.emitToUser(userId, 'cart:paired', formatted);

      return res.status(200).json({
        success: true,
        message: `Successfully paired with Cart ${normalizedCode}`,
        data: formatted,
      });
    } catch (error: any) {
      console.error('Error pairing cart:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to pair with cart',
        error: error.message,
      });
    }
  }

  /**
   * Verify Face ID for active cart session
   */
  static async verifyFace(req: AuthRequest, res: Response) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const activeSession = await CartService.getActiveSessionByUserId(userId);
      if (!activeSession) {
        return res.status(404).json({
          success: false,
          message: 'No active cart session found to verify Face ID.',
        });
      }

      const updatedSession = await CartService.verifySessionFace(activeSession.id);
      const formatted = CartService.formatCartResponse(updatedSession);

      if (activeSession.cart?.cartCode) {
        socketService.emitToCart(activeSession.cart.cartCode, 'cart:face_verified', {
          cartCode: activeSession.cart.cartCode,
          cart: formatted,
        });
      }
      socketService.emitToUser(userId, 'cart:face_verified', formatted);

      return res.json({
        success: true,
        message: 'Face ID verified successfully! Session secured.',
        data: formatted,
      });
    } catch (error: any) {
      console.error('Error verifying face:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to verify Face ID',
        error: error.message,
      });
    }
  }

  /**
   * Get user's active shopping cart session
   */
  static async getActiveCart(req: AuthRequest, res: Response) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const session = await CartService.getActiveSessionByUserId(userId);

      if (!session) {
        return res.json({
          success: true,
          message: 'No active cart session found. Please scan a cart QR code.',
          data: null,
        });
      }

      const formatted = CartService.formatCartResponse(session);
      return res.json({
        success: true,
        data: formatted,
      });
    } catch (error: any) {
      console.error('Error getting active cart:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to retrieve active cart',
        error: error.message,
      });
    }
  }

  /**
   * Add item to active cart manually (from app barcode scanner or UI)
   */
  static async addItem(req: AuthRequest, res: Response) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { productId, barcode } = req.body;
      let targetProductId = productId;

      if (!targetProductId && barcode) {
        const prod = await prisma.product.findUnique({
          where: { barcode: barcode.toString().trim() },
        });
        if (prod) targetProductId = prod.id;
      }

      if (!targetProductId) {
        return res.status(400).json({
          success: false,
          message: 'productId or barcode is required',
        });
      }

      const activeSession = await CartService.getActiveSessionByUserId(userId);
      if (!activeSession) {
        return res.status(404).json({
          success: false,
          message: 'No active shopping session found. Scan a cart first.',
        });
      }

      const updatedSession = await CartService.addItemToCart(
        activeSession.id,
        parseInt(targetProductId, 10),
        'MANUAL'
      );

      const formatted = CartService.formatCartResponse(updatedSession);

      // Emit real-time update
      if (activeSession.cart?.cartCode) {
        socketService.emitToCart(activeSession.cart.cartCode, 'cart:updated', {
          action: 'item_added',
          cart: formatted,
        });
      }
      socketService.emitToUser(userId, 'cart:updated', {
        action: 'item_added',
        cart: formatted,
      });

      return res.json({
        success: true,
        message: 'Item added to cart',
        data: formatted,
      });
    } catch (error: any) {
      console.error('Error adding item:', error);
      return res.status(500).json({
        success: false,
        message: error.message || 'Failed to add item',
      });
    }
  }

  /**
   * Remove or decrement item from active cart
   */
  static async removeItem(req: AuthRequest, res: Response) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { cartItemId, forceDelete } = req.body;
      if (!cartItemId) {
        return res.status(400).json({
          success: false,
          message: 'cartItemId is required',
        });
      }

      const activeSession = await CartService.getActiveSessionByUserId(userId);
      if (!activeSession) {
        return res.status(404).json({
          success: false,
          message: 'No active shopping session found',
        });
      }

      const updatedSession = await CartService.removeItemFromCart(
        activeSession.id,
        parseInt(cartItemId, 10),
        Boolean(forceDelete)
      );

      const formatted = CartService.formatCartResponse(updatedSession);

      // Emit real-time update
      if (activeSession.cart?.cartCode) {
        socketService.emitToCart(activeSession.cart.cartCode, 'cart:updated', {
          action: 'item_removed',
          cart: formatted,
        });
      }
      socketService.emitToUser(userId, 'cart:updated', {
        action: 'item_removed',
        cart: formatted,
      });

      return res.json({
        success: true,
        message: 'Item removed from cart',
        data: formatted,
      });
    } catch (error: any) {
      console.error('Error removing item:', error);
      return res.status(500).json({
        success: false,
        message: error.message || 'Failed to remove item',
      });
    }
  }

  /**
   * Unpair / Abandon active cart session
   */
  static async unpairCart(req: AuthRequest, res: Response) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const session = await CartService.getActiveSessionByUserId(userId);
      if (!session) {
        return res.status(404).json({
          success: false,
          message: 'No active cart session to unpair',
        });
      }

      // Mark session as CANCELLED
      await prisma.shoppingSession.update({
        where: { id: session.id },
        data: { status: 'CANCELLED', completedAt: new Date() },
      });

      // Free cart
      await prisma.cart.update({
        where: { id: session.cartId },
        data: { status: 'AVAILABLE' },
      });

      socketService.emitToCart(session.cart.cartCode, 'cart:unpaired', {
        userId,
        cartCode: session.cart.cartCode,
      });

      return res.json({
        success: true,
        message: 'Cart session cancelled successfully',
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Failed to unpair cart',
        error: error.message,
      });
    }
  }
}
