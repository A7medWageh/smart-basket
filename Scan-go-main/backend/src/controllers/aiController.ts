import { Request, Response } from 'express';
import { prisma } from '../lib/prisma';
import { CartService } from '../services/cartService';
import { socketService } from '../services/socketService';

export class AIController {
  /**
   * Webhook endpoint called by the AI / Vision Server
   * Expected Body:
   * {
   *   "cart_code": "CART_01",
   *   "product_id": 1,         // OR "barcode": "6221001001" OR "label": "pepsi"
   *   "confidence": 0.95,
   *   "action": "added"        // optional, "added" (default) or "removed"
   * }
   */
  static async handleDetection(req: Request, res: Response) {
    try {
      const {
        cart_code,
        cartCode,
        cart_id,
        product_id,
        productId,
        barcode,
        label,
        confidence,
        action = 'added',
      } = req.body;

      const code = (cart_code || cartCode || (cart_id ? `CART_${cart_id}` : ''))?.toString().trim().toUpperCase();

      if (!code) {
        return res.status(400).json({
          success: false,
          message: 'cart_code is required (e.g. "CART_01")',
        });
      }

      // 1. Find Product by ID, Barcode, or Name/Label match
      let product = null;

      const targetId = product_id || productId;
      if (targetId) {
        product = await prisma.product.findUnique({
          where: { id: parseInt(targetId, 10) },
        });
      } else if (barcode) {
        product = await prisma.product.findUnique({
          where: { barcode: barcode.toString().trim() },
        });
      } else if (label) {
        // Fuzzy / Contains search on product names
        product = await prisma.product.findFirst({
          where: {
            OR: [
              { nameEn: { contains: label } },
              { nameAr: { contains: label } },
              { category: { contains: label } },
            ],
          },
        });
      }

      if (!product) {
        return res.status(404).json({
          success: false,
          message: `Product could not be identified from the provided data (id: ${targetId}, barcode: ${barcode}, label: ${label})`,
        });
      }

      // 2. Find Active Shopping Session for this Cart
      const activeSession = await CartService.getActiveSessionByCartCode(code);

      if (!activeSession) {
        console.warn(`⚠️ [AI Webhook] Item detected for Cart ${code}, but no active shopping session is currently open.`);
        return res.status(404).json({
          success: false,
          message: `No active user session found for Cart ${code}. Ensure a customer scanned the cart QR first.`,
          detectedProduct: {
            id: product.id,
            nameAr: product.nameAr,
            nameEn: product.nameEn,
            price: product.price,
          },
        });
      }

      let updatedSession;

      if (action === 'removed') {
        // Find existing cart item to decrement
        const existingItem = await prisma.cartItem.findFirst({
          where: {
            sessionId: activeSession.id,
            productId: product.id,
          },
        });

        if (existingItem) {
          updatedSession = await CartService.removeItemFromCart(activeSession.id, existingItem.id);
        } else {
          updatedSession = activeSession;
        }
      } else {
        // Add item to cart
        updatedSession = await CartService.addItemToCart(activeSession.id, product.id, 'AI');
      }

      const formattedCart = CartService.formatCartResponse(updatedSession);

      // 3. Push Real-Time Socket Event to Mobile App
      const eventPayload = {
        action: action === 'removed' ? 'item_removed' : 'item_added',
        detectedProduct: {
          id: product.id,
          nameAr: product.nameAr,
          nameEn: product.nameEn,
          barcode: product.barcode,
          price: product.price,
          imageUrl: product.imageUrl,
          confidence: confidence || 1.0,
        },
        cart: formattedCart,
      };

      socketService.emitToCart(code, 'cart:updated', eventPayload);
      if (activeSession.userId) {
        socketService.emitToUser(activeSession.userId, 'cart:updated', eventPayload);
      }

      console.log(`✅ [AI Webhook] Processed ${action} for product "${product.nameEn}" in Cart "${code}" (Session #${activeSession.id})`);

      return res.status(200).json({
        success: true,
        message: `Product ${product.nameEn} successfully processed into Cart ${code}`,
        data: eventPayload,
      });
    } catch (error: any) {
      console.error('❌ [AI Webhook Error]:', error);
      return res.status(500).json({
        success: false,
        message: 'Internal server error while processing AI detection',
        error: error.message,
      });
    }
  }
}
