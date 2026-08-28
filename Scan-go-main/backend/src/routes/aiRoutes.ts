import { Router } from 'express';
import { AIController } from '../controllers/aiController';

const router = Router();

// Webhook endpoint called by the AI Computer Vision service
router.post('/detection', AIController.handleDetection);

export default router;
