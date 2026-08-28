import { Response } from 'express';
import QRCode from 'qrcode';
import { prisma } from '../lib/prisma';
import { AuthRequest } from '../middlewares/authMiddleware';
import { CartService } from '../services/cartService';
import { socketService } from '../services/socketService';

export class OrderController {
  /**
   * Complete checkout and simulate payment (InstaPay / Vodafone Cash / Visa)
   */
  static async checkout(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }
      const userId = req.user.id;

      const { paymentMethod = 'INSTAPAY', cartCode, cart_code, notes } = req.body;

      // Flexibly normalize payment method
      let normalizedMethod = (paymentMethod || 'INSTAPAY').toString().toUpperCase().trim();
      if (normalizedMethod.includes('VODAFONE')) normalizedMethod = 'VODAFONE_CASH';
      else if (normalizedMethod.includes('INSTA')) normalizedMethod = 'INSTAPAY';
      else if (normalizedMethod.includes('VISA') || normalizedMethod.includes('CARD') || normalizedMethod.includes('CREDIT')) normalizedMethod = 'VISA';
      else if (normalizedMethod.includes('CASH')) normalizedMethod = 'CASH';
      else normalizedMethod = 'INSTAPAY';

      // 1. Try to find active session by userId
      let activeSession = await CartService.getActiveSessionByUserId(userId);

      // 2. Fallback: Try to find active session by cart code if specified or default
      const targetCartCode = cartCode || cart_code || (activeSession ? activeSession.cart.cartCode : 'CART_01');
      if (!activeSession || activeSession.items.length === 0) {
        const sessionByCart = await CartService.getActiveSessionByCartCode(targetCartCode);
        if (sessionByCart && sessionByCart.items.length > 0) {
          activeSession = sessionByCart;
        }
      }

      if (!activeSession || !activeSession.items || activeSession.items.length === 0) {
        return res.status(400).json({
          success: false,
          message: `Cannot checkout: Cart ${targetCartCode} is empty or no active shopping session exists. Please add products first.`,
        });
      }

      const formattedCart = CartService.formatCartResponse(activeSession);
      if (!formattedCart || formattedCart.grandTotal <= 0) {
        return res.status(400).json({ success: false, message: 'Invalid cart total or empty cart.' });
      }

      // Generate unique order number (e.g. "ORD-2026-94812")
      const orderNumber = `ORD-${new Date().getFullYear()}-${Math.floor(10000 + Math.random() * 90000)}`;

      // Generate security exit verification payload
      const exitPayload = JSON.stringify({
        orderNumber,
        userId,
        cartCode: activeSession.cart.cartCode,
        totalAmount: formattedCart.grandTotal,
        itemsCount: formattedCart.itemsCount,
        paidAt: new Date().toISOString(),
        status: 'PAID_VERIFIED',
      });

      // Generate QR Code Data URL (Base64 PNG)
      const exitQrCodeDataUrl = await QRCode.toDataURL(exitPayload, {
        errorCorrectionLevel: 'H',
        margin: 2,
        width: 300,
        color: {
          dark: '#111827',
          light: '#FFFFFF',
        },
      });

      // Save Order in Database
      const order = await prisma.order.create({
        data: {
          orderNumber,
          sessionId: activeSession.id,
          userId,
          totalAmount: formattedCart.grandTotal,
          paymentMethod: normalizedMethod,
          paymentStatus: 'COMPLETED',
          exitQrCode: exitQrCodeDataUrl,
        },
      });

      // Mark session as COMPLETED
      await prisma.shoppingSession.update({
        where: { id: activeSession.id },
        data: {
          status: 'COMPLETED',
          completedAt: new Date(),
        },
      });

      // Release the physical cart back to AVAILABLE
      await prisma.cart.update({
        where: { id: activeSession.cartId },
        data: { status: 'AVAILABLE' },
      });

      // Prepare comprehensive receipt
      const receipt = {
        orderId: order.id,
        orderNumber: order.orderNumber,
        createdAt: order.createdAt,
        paymentMethod: order.paymentMethod,
        paymentStatus: order.paymentStatus,
        customer: {
          name: req.user.name,
          email: req.user.email,
        },
        cartCode: activeSession.cart.cartCode,
        items: formattedCart.items,
        subtotal: formattedCart.subtotal,
        tax: formattedCart.tax,
        totalAmount: formattedCart.grandTotal,
        itemsCount: formattedCart.itemsCount,
        exitQrCode: exitQrCodeDataUrl,
        notes: notes || 'Thank you for shopping with Scan & Go!',
      };

      // Notify sockets
      socketService.emitToCart(activeSession.cart.cartCode, 'checkout:completed', receipt);
      socketService.emitToUser(userId, 'checkout:completed', receipt);

      return res.status(200).json({
        success: true,
        message: 'Payment completed successfully! Show your Exit QR code at the gate.',
        data: receipt,
      });
    } catch (error: any) {
      console.error('Checkout error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error processing checkout and payment simulation',
        error: error.message,
      });
    }
  }

  /**
   * Get user order history
   */
  static async getHistory(req: AuthRequest, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }
      const userId = req.user.id;

      const orders = await prisma.order.findMany({
        where: { userId },
        include: {
          session: {
            include: {
              cart: true,
              items: { include: { product: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      return res.json({
        success: true,
        count: orders.length,
        data: orders.map((o) => ({
          id: o.id,
          orderNumber: o.orderNumber,
          totalAmount: o.totalAmount,
          paymentMethod: o.paymentMethod,
          paymentStatus: o.paymentStatus,
          cartCode: o.session.cart.cartCode,
          itemsCount: o.session.items.reduce((acc, i) => acc + i.quantity, 0),
          createdAt: o.createdAt,
          exitQrCode: o.exitQrCode,
        })),
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch order history',
        error: error.message,
      });
    }
  }

  /**
   * Get receipt details for a specific order
   */
  static async getReceipt(req: AuthRequest, res: Response) {
    try {
      const idParam = req.params.id;
      const idStr = Array.isArray(idParam) ? idParam[0] : idParam;

      if (!idStr) {
        return res.status(400).json({ success: false, message: 'Missing order ID' });
      }

      const isNumeric = /^\d+$/.test(idStr);

      const order = await prisma.order.findFirst({
        where: isNumeric
          ? { id: parseInt(idStr, 10) }
          : { orderNumber: idStr },
        include: {
          user: { select: { id: true, name: true, email: true, phone: true } },
          session: {
            include: {
              cart: true,
              items: { include: { product: true } },
            },
          },
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: 'Order not found' });
      }

      return res.json({
        success: true,
        data: {
          id: order.id,
          orderNumber: order.orderNumber,
          totalAmount: order.totalAmount,
          paymentMethod: order.paymentMethod,
          paymentStatus: order.paymentStatus,
          createdAt: order.createdAt,
          exitQrCode: order.exitQrCode,
          customer: order.user,
          cartCode: order.session.cart.cartCode,
          items: order.session.items.map((i: any) => ({
            productId: i.productId,
            nameAr: i.product.nameAr,
            nameEn: i.product.nameEn,
            price: i.unitPrice,
            quantity: i.quantity,
            total: i.quantity * i.unitPrice,
          })),
        },
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Failed to get receipt',
        error: error.message,
      });
    }
  }
}
