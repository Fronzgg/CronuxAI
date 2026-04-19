require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Отдаём фронтенд статически
app.use(express.static(path.join(__dirname, '..')));

// Роуты
app.use('/api/chat',    require('./routes/chat'));
app.use('/api/search',  require('./routes/search'));
app.use('/api/ocr',     require('./routes/ocr'));
app.use('/api/credits', require('./routes/credits'));

app.listen(PORT, () => {
  console.log(`\n🟣 Cronux сервер запущен: http://localhost:${PORT}`);
  console.log(`   Режим AI: ${process.env.AI_MODE || 'mock'}`);
  console.log(`   Фронтенд: http://localhost:${PORT}/index.html\n`);
});
