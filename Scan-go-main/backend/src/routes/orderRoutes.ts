import { Router } from 'express';
import { OrderController } from '../controllers/orderController';
import { authenticateJWT } from '../middlewares/authMiddleware';

const router = Router();

router.use(authenticateJWT);

router.post('/checkout', OrderController.checkout);
router.get('/history', OrderController.getHistory);
router.get('/:id/receipt', OrderController.getReceipt);

export default router;
