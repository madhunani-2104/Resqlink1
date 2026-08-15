const mongoose = require('mongoose');
const logger = require('./logger');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/resq_db');
    logger.info(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    logger.error(`MongoDB Connection Error: ${error.message}`);
    if (process.env.NODE_ENV !== 'test') {
      // Avoid exiting in test mode to allow in-memory/mock fallback
      console.warn('MongoDB connection failed. Please ensure MongoDB is running or check MONGO_URI.');
    }
  }
};

module.exports = connectDB;
