import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';

class SocketService {
  private io: SocketIOServer | null = null;

  public init(httpServer: HTTPServer) {
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: '*', // Allow all origins for mobile apps & web simulator
        methods: ['GET', 'POST'],
      },
    });

    this.io.on('connection', (socket: Socket) => {
      console.log(`🔌 [Socket.io] Client connected: ${socket.id}`);

      // Client joins room for their active cart code (e.g., 'cart:CART_01')
      socket.on('join:cart', (cartCode: string) => {
        if (cartCode) {
          const room = `cart:${cartCode.trim().toUpperCase()}`;
          socket.join(room);
          console.log(`👥 Socket ${socket.id} joined room ${room}`);
          socket.emit('joined', { room, message: `Joined ${room} successfully` });
        }
      });

      // Client joins room for their user ID (e.g., 'user:1')
      socket.on('join:user', (userId: number | string) => {
        if (userId) {
          const room = `user:${userId}`;
          socket.join(room);
          console.log(`👤 Socket ${socket.id} joined user room ${room}`);
          socket.emit('joined', { room, message: `Joined ${room} successfully` });
        }
      });

      socket.on('disconnect', () => {
        console.log(`❌ [Socket.io] Client disconnected: ${socket.id}`);
      });
    });

    console.log('⚡ Socket.io service initialized successfully.');
  }

  public emitToCart(cartCode: string, event: string, payload: any) {
    if (!this.io) {
      console.warn('⚠️ Socket.io is not initialized yet.');
      return;
    }
    const room = `cart:${cartCode.trim().toUpperCase()}`;
    console.log(`📢 Emitting event "${event}" to room "${room}"`);
    this.io.to(room).emit(event, payload);
    // Also emit broadcast for any listening clients / simulator
    this.io.emit(`global:${event}`, { cartCode, ...payload });
  }

  public emitToUser(userId: number, event: string, payload: any) {
    if (!this.io) return;
    const room = `user:${userId}`;
    console.log(`📢 Emitting event "${event}" to room "${room}"`);
    this.io.to(room).emit(event, payload);
  }

  public broadcast(event: string, payload: any) {
    if (!this.io) return;
    this.io.emit(event, payload);
  }
}

export const socketService = new SocketService();
