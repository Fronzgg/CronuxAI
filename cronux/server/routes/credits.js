const express = require('express');
const router = express.Router();

// В прототипе кредиты хранятся на фронте в localStorage.
// Этот роут — заглушка для будущей интеграции с БД (PostgreSQL/MongoDB).

// GET /api/credits/:username
router.get('/:username', (req, res) => {
  const { username } = req.params;

  // Специальный пользователь — безлимит
  if (username.toLowerCase() === 'fronz') {
    return res.json({ unlimited: true, current: 999999, max: 999999 });
  }

  // TODO: получить из БД
  res.json({ unlimited: false, current: 100, max: 100, resetDate: todayStr() });
});

// POST /api/credits/use
router.post('/use', (req, res) => {
  const { username } = req.body;
  if (!username) return res.status(400).json({ error: 'username required' });

  if (username.toLowerCase() === 'fronz') {
    return res.json({ ok: true, unlimited: true });
  }

  // TODO: декрементировать в БД
  res.json({ ok: true, remaining: 99 });
});

function todayStr() { return new Date().toISOString().split('T')[0]; }

module.exports = router;
