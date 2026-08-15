const express = require('express');
const http = require('http');
const socketio = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');

dotenv.config();

const connectDB = require('./src/config/db');
const logger = require('./src/config/logger');
const setupSockets = require('./src/sockets/socketHandler');
const { errorHandler, notFound } = require('./src/middleware/errorMiddleware');

// Route Imports
const authRoutes = require('./src/routes/authRoutes');
const sosRoutes = require('./src/routes/sosRoutes');
const meshRoutes = require('./src/routes/meshRoutes');
const mapRoutes = require('./src/routes/mapRoutes');
const userRoutes = require('./src/routes/userRoutes');
const adminRoutes = require('./src/routes/adminRoutes');

const app = express();
const server = http.createServer(app);

const io = socketio(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
  },
});

// Attach socket.io instance to app for controller access
app.set('socketio', io);

// Connect to Database
connectDB();

// Setup Express Middlewares
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// API Routes
app.get('/api/health', (req, res) => {
  res.json({
    status: 'HEALTHY',
    service: 'ResQ Emergency Backend API',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/mesh', meshRoutes);
app.use('/api/map', mapRoutes);
app.use('/api/user', userRoutes);
app.use('/api/admin', adminRoutes);

// Socket.io initialization
setupSockets(io);

// Error Handling Middlewares
app.use(notFound);
app.use(errorHandler);

const PORT = process.env.PORT || 5000;

// Listen on all network interfaces so the phone can access the backend
if (process.env.NODE_ENV !== 'test') {
  server.listen(PORT, '0.0.0.0', () => {
    logger.info(
      `Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`
    );
    logger.info(`Local: http://localhost:${PORT}`);
    logger.info(`Network: http://0.0.0.0:${PORT}`);
  });
}

module.exports = { app, server };