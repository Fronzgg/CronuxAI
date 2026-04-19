const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const upload = multer({
  dest: '/tmp/cronux-ocr/',
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, allowed.includes(ext));
  },
});

router.post('/', upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'image required' });

  try {
    let text;

    // Попробовать node-tesseract-ocr если установлен
    try {
      const tesseract = require('node-tesseract-ocr');
      text = await tesseract.recognize(req.file.path, {
        lang: 'rus+eng',
        oem: 1,
        psm: 3,
      });
    } catch (_) {
      // Fallback: вернуть заглушку (Tesseract.js сработает на фронте)
      text = null;
    }

    // Удалить временный файл
    fs.unlink(req.file.path, () => {});

    if (text) {
      res.json({ text: text.trim() });
    } else {
      // Сигнал фронту использовать Tesseract.js
      res.status(501).json({ error: 'server OCR unavailable, use client-side' });
    }
  } catch (err) {
    console.error('[ocr]', err.message);
    fs.unlink(req.file.path, () => {});
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
