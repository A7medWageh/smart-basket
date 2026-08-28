import http from 'http';
import { createApp } from './app';
import { ENV } from './config/env';
import { socketService } from './services/socketService';

const app = createApp();
const server = http.createServer(app);

// Initialize WebSockets (Socket.io)
socketService.init(server);

server.listen(ENV.PORT, () => {
  console.log(`
=====================================================
🚀 Scan & Go Backend Server Running!
📡 HTTP URL:      http://localhost:${ENV.PORT}
⚡ Socket.io:     ws://localhost:${ENV.PORT}
🖥️ Simulator UI:  http://localhost:${ENV.PORT}
📊 Health Check:  http://localhost:${ENV.PORT}/api/health
=====================================================
  `);
});
