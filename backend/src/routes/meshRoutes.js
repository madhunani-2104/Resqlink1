const express = require('express');
const router = express.Router();
const {
  postMeshMessage,
  getMeshMessages,
  uploadMeshFile,
  downloadMeshFile,
  syncBatch,
} = require('../controllers/meshController');
const { protect } = require('../middleware/authMiddleware');
const upload = require('../middleware/uploadMiddleware');

router.post('/message', protect, postMeshMessage);
router.post('/files', protect, upload.single('file'), uploadMeshFile);
router.get('/files/:fileId', protect, downloadMeshFile);
router.get('/messages', protect, getMeshMessages);
router.post('/sync-batch', protect, syncBatch);

module.exports = router;
