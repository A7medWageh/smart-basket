import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import http from 'http';
import authRoutes from './routes/authRoutes';
import productRoutes from './routes/productRoutes';
import cartRoutes from './routes/cartRoutes';
import aiRoutes from './routes/aiRoutes';
import orderRoutes from './routes/orderRoutes';
import { errorHandler } from './middlewares/errorHandler';

export const createApp = (): Express => {
  const app = express();

  // Middleware
  app.use(cors({ origin: '*' }));
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Raw body parser for camera images sent to /predict
  app.use('/predict', express.raw({ type: '*/*', limit: '10mb' }));

  // Serve static files (Simulator Dashboard)
  app.use(express.static(path.join(__dirname, '../public')));

  // Health Check
  app.get('/api/health', (req: Request, res: Response) => {
    res.json({
      status: 'OK',
      timestamp: new Date().toISOString(),
      service: 'Scan & Go Smart Shopping Cart Backend',
    });
  });

  // Proxy /predict requests to Python AI Vision service on port 8000
  app.post('/predict', (req: Request, res: Response) => {
    const cartCode = req.query.cart_code || 'CART_01';
    const action = req.query.action || 'added';
    const aiTargetUrl = `http://localhost:8000/predict?cart_code=${cartCode}&action=${action}`;

    console.log(`📡 [Backend Proxy] Forwarding ESP32 image request to AI Service (port 8000)...`);

    const contentType = req.headers['content-type'] || 'image/jpeg';
    const payloadBuffer = Buffer.isBuffer(req.body) ? req.body : Buffer.from(req.body || '');

    const options: http.RequestOptions = {
      hostname: '127.0.0.1',
      port: 8000,
      path: `/predict?cart_code=${cartCode}&action=${action}`,
      method: 'POST',
      headers: {
        'Content-Type': contentType,
        'Content-Length': payloadBuffer.length,
      },
    };

    const proxyReq = http.request(options, (aiRes) => {
      let body = '';
      aiRes.on('data', (chunk) => (body += chunk));
      aiRes.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          res.status(aiRes.statusCode || 200).json(parsed);
        } catch (_) {
          res.status(aiRes.statusCode || 200).send(body);
        }
      });
    });

    proxyReq.on('error', (err) => {
      console.error('❌ [Backend Proxy Error] AI service (port 8000) not reachable:', err.message);
      res.status(502).json({
        success: false,
        message: 'AI Service on port 8000 is not running. Make sure "python app.py" is active.',
        error: err.message,
      });
    });

    proxyReq.write(payloadBuffer);
    proxyReq.end();
  });

  // API Routes
  app.use('/api/auth', authRoutes);
  app.use('/api/products', productRoutes);
  app.use('/api/cart', cartRoutes);
  app.use('/api/ai', aiRoutes);
  app.use('/api/orders', orderRoutes);
  // Alias from the original plan
  app.use('/api/checkout', orderRoutes);

  // Global Error Handler
  app.use(errorHandler);

  return app;
};
