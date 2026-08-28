import { Request, Response } from 'express';
import { prisma } from '../lib/prisma';

export class ProductController {
  /**
   * Get all products with optional search query & category
   */
  static async getAllProducts(req: Request, res: Response) {
    try {
      const query = typeof req.query.query === 'string' ? req.query.query : undefined;
      const category = typeof req.query.category === 'string' ? req.query.category : undefined;

      const whereClause: any = {};

      if (category) {
        whereClause.category = { contains: category };
      }

      if (query) {
        whereClause.OR = [
          { nameAr: { contains: query } },
          { nameEn: { contains: query } },
          { barcode: { contains: query } },
        ];
      }

      const products = await prisma.product.findMany({
        where: whereClause,
        orderBy: { id: 'asc' },
      });

      return res.json({
        success: true,
        count: products.length,
        data: products,
      });
    } catch (error: any) {
      console.error('Error fetching products:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch products',
        error: error.message,
      });
    }
  }

  /**
   * Get a single product by ID or Barcode
   */
  static async getProductById(req: Request, res: Response) {
    try {
      const idParam = req.params.id;
      const idStr = Array.isArray(idParam) ? idParam[0] : idParam;

      if (!idStr) {
        return res.status(400).json({ success: false, message: 'Missing ID parameter' });
      }

      const isNumeric = /^\d+$/.test(idStr);
      let product = null;

      if (isNumeric) {
        product = await prisma.product.findFirst({
          where: {
            OR: [{ id: parseInt(idStr, 10) }, { barcode: idStr }],
          },
        });
      } else {
        product = await prisma.product.findUnique({
          where: { barcode: idStr },
        });
      }

      if (!product) {
        return res.status(404).json({
          success: false,
          message: 'Product not found',
        });
      }

      return res.json({
        success: true,
        data: product,
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch product',
        error: error.message,
      });
    }
  }
}
