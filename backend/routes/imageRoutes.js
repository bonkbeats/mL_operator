const express = require('express');
const router = express.Router();
const imageController = require('../controllers/imageController');
const { verifyToken, checkRole } = require('../middleware/auth');

router.use(verifyToken);

router.post('/', imageController.saveImage);
router.put('/url', imageController.updateImageUrl);
router.get('/user', imageController.getUserImages);
router.delete('/:id', imageController.deleteImage);

// Admin route to get all images or images by user
router.get('/admin', checkRole(['admin']), imageController.getAdminImages);

module.exports = router; 