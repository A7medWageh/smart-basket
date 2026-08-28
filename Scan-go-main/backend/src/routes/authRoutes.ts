import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { authenticateJWT } from '../middlewares/authMiddleware';

const router = Router();

router.post('/register', AuthController.register);
router.post('/login', AuthController.login);
router.get('/me', authenticateJWT, AuthController.getMe);
router.post('/face/enroll', authenticateJWT, AuthController.enrollFace);
router.post('/face/verify', authenticateJWT, AuthController.verifyFace);

export default router;
