const express = require('express');
const router = express.Router();
const {
  registerUser,
  loginUser,
  rescueRegister,
  rescueLogin,
  forgotPassword,
  resetPassword,
  getMe,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

router.post('/register', registerUser);
router.post('/login', loginUser);
router.post('/rescue-register', rescueRegister);
router.post('/rescue-login', rescueLogin);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.get('/me', protect, getMe);

module.exports = router;
