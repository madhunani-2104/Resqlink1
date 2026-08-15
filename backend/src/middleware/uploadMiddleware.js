const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination(req, file, cb) {
    cb(null, uploadDir);
  },
  filename(req, file, cb) {
    const extension = path.extname(file.originalname).toLowerCase();
    cb(null, `${crypto.randomUUID()}${extension}`);
  },
});

const allowedMimeTypes = new Set([
  'image/jpeg', 'image/png', 'image/gif', 'image/webp',
  'application/pdf',
  'text/plain', 'text/csv',
  'application/zip',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
]);

const allowedExtensions = new Set([
  '.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf', '.txt', '.csv', '.zip',
  '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
]);

function checkFileType(file, cb) {
  const extension = path.extname(file.originalname).toLowerCase();
  if (allowedExtensions.has(extension) && allowedMimeTypes.has(file.mimetype)) {
    return cb(null, true);
  }
  cb(new Error('Unsupported file type.'));
}

const upload = multer({
  storage,
  limits: { fileSize: 5000000 },
  fileFilter: function (req, file, cb) {
    checkFileType(file, cb);
  },
});

module.exports = upload;
