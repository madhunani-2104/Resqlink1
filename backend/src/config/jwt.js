const jwt = require('jsonwebtoken');

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET || 'resq_emergency_secret_key_2026_jwt_token_btech_capstone', {
    expiresIn: process.env.JWT_EXPIRE || '30d',
  });
};

const verifyToken = (token) => {
  return jwt.verify(token, process.env.JWT_SECRET || 'resq_emergency_secret_key_2026_jwt_token_btech_capstone');
};

module.exports = { generateToken, verifyToken };
