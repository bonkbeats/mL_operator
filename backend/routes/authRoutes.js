const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { verifyToken, checkRole } = require('../middleware/auth');

// Public routes
router.post('/register', authController.register);
router.post('/login', authController.login);

// Protected routes
router.use(verifyToken); // Apply verifyToken to all routes below this line

router.get('/profile', authController.getProfile);
router.put('/profile', authController.updateProfile);
router.put('/change-password', authController.changePassword);

// Admin route to get all users (requires admin role)
router.get('/users', checkRole(['admin']), authController.getAllUsers);

module.exports = router; 