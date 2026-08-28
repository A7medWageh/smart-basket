import { prisma } from '../lib/prisma';

export class CartService {
  /**
   * Get active shopping session for a user
   */
  static async getActiveSessionByUserId(userId: number) {
    return prisma.shoppingSession.findFirst({
      where: {
        userId,
        status: 'ACTIVE',
      },
      include: {
        cart: true,
        items: {
          include: {
            product: true,
          },
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });
  }

  /**
   * Get active shopping session by physical cart code (e.g. "CART_01")
   */
  static async getActiveSessionByCartCode(cartCode: string) {
    const normalizedCode = cartCode.trim().toUpperCase();
    const cart = await prisma.cart.findUnique({
      where: { cartCode: normalizedCode },
    });

    if (!cart) return null;

    return prisma.shoppingSession.findFirst({
      where: {
        cartId: cart.id,
        status: 'ACTIVE',
      },
      include: {
        cart: true,
        user: {
          select: { id: true, name: true, email: true, phone: true },
        },
        items: {
          include: {
            product: true,
          },
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });
  }

  /**
   * Format session data for clean API / Socket output
   */
  static formatCartResponse(session: any) {
    if (!session) return null;

    let subtotal = 0;
    let totalItems = 0;
    let totalWeightGrams = 0;

    const formattedItems = (session.items || []).map((item: any) => {
      const itemTotal = item.quantity * item.unitPrice;
      subtotal += itemTotal;
      totalItems += item.quantity;
      totalWeightGrams += (item.product?.weightGrams || 0) * item.quantity;

      return {
        cartItemId: item.id,
        productId: item.product?.id,
        nameAr: item.product?.nameAr || 'منتج',
        nameEn: item.product?.nameEn || 'Product',
        barcode: item.product?.barcode || '',
        category: item.product?.category || '',
        imageUrl: item.product?.imageUrl || '',
        unitPrice: item.unitPrice,
        quantity: item.quantity,
        totalPrice: parseFloat(itemTotal.toFixed(2)),
        detectedBy: item.detectedBy || 'AI',
        addedAt: item.createdAt,
      };
    });

    const tax = parseFloat((subtotal * 0.03).toFixed(2));
    const grandTotal = parseFloat((subtotal + tax).toFixed(2));

    return {
      sessionId: session.id,
      cartCode: session.cart?.cartCode || null,
      cartStatus: session.cart?.status || null,
      sessionStatus: session.status,
      faceVerified: Boolean(session.faceVerified),
      faceVerifiedAt: session.faceVerifiedAt || null,
      startedAt: session.startedAt,
      itemsCount: totalItems,
      items: formattedItems,
      subtotal: parseFloat(subtotal.toFixed(2)),
      tax: parseFloat(tax.toFixed(2)),
      grandTotal: parseFloat(grandTotal.toFixed(2)),
      estimatedWeightGrams: totalWeightGrams,
      user: session.user || undefined,
    };
  }

  /**
   * Mark session Face ID as verified
   */
  static async verifySessionFace(sessionId: number) {
    return prisma.shoppingSession.update({
      where: { id: sessionId },
      data: {
        faceVerified: true,
        faceVerifiedAt: new Date(),
      },
      include: {
        cart: true,
        user: { select: { id: true, name: true, email: true } },
        items: { include: { product: true } },
      },
    });
  }

  /**
   * Add a product to the active cart session
   */
  static async addItemToCart(sessionId: number, productId: number, detectedBy = 'AI') {
    const product = await prisma.product.findUnique({
      where: { id: productId },
    });

    if (!product) {
      throw new Error(`Product with ID ${productId} not found.`);
    }

    // Check if item already in this cart session
    const existingItem = await prisma.cartItem.findFirst({
      where: {
        sessionId,
        productId,
      },
    });

    if (existingItem) {
      // Increment quantity
      await prisma.cartItem.update({
        where: { id: existingItem.id },
        data: {
          quantity: existingItem.quantity + 1,
          detectedBy,
        },
      });
    } else {
      // Create new cart item
      await prisma.cartItem.create({
        data: {
          sessionId,
          productId,
          quantity: 1,
          unitPrice: product.price,
          detectedBy,
        },
      });
    }

    // Return updated session
    return prisma.shoppingSession.findUnique({
      where: { id: sessionId },
      include: {
        cart: true,
        user: { select: { id: true, name: true, email: true } },
        items: {
          include: { product: true },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
  }

  /**
   * Remove or decrement an item from the cart
   */
  static async removeItemFromCart(sessionId: number, cartItemId: number, forceDelete = false) {
    const item = await prisma.cartItem.findFirst({
      where: {
        id: cartItemId,
        sessionId,
      },
    });

    if (!item) {
      throw new Error('Item not found in this cart session');
    }

    if (!forceDelete && item.quantity > 1) {
      await prisma.cartItem.update({
        where: { id: item.id },
        data: { quantity: item.quantity - 1 },
      });
    } else {
      await prisma.cartItem.delete({
        where: { id: item.id },
      });
    }

    // Return updated session
    return prisma.shoppingSession.findUnique({
      where: { id: sessionId },
      include: {
        cart: true,
        user: { select: { id: true, name: true, email: true } },
        items: {
          include: { product: true },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
  }
}
