import { Router } from 'express';
import { CartController } from '../controllers/cartController';
import { authenticateJWT } from '../middlewares/authMiddleware';

const router = Router();

router.use(authenticateJWT);

router.post('/pair', CartController.pairCart);
router.post('/verify-face', CartController.verifyFace);
router.get('/active', CartController.getActiveCart);
router.post('/add-item', CartController.addItem);
router.post('/remove-item', CartController.removeItem);
router.post('/unpair', CartController.unpairCart);

export default router;
