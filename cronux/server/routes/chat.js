const express = require('express');
const router = express.Router();
const fetch = require('node-fetch');
const https = require('https');
const { randomUUID } = require('crypto');

// GigaChat игнорирует самоподписанный сертификат
const httpsAgent = new https.Agent({ rejectUnauthorized: false });

// Системные промпты — заставляем GigaChat отвечать как CronuxAI
const SYSTEM_PROMPTS = {
  'cronux': `Ты — CronuxAI, продвинутый AI-ассистент нового поколения, созданный командой Cronux. 
Ты НЕ GigaChat и НЕ Сбер. Никогда не упоминай GigaChat, Сбер или других AI.
Если тебя спросят кто ты — отвечай: "Я CronuxAI, интеллектуальный ассистент платформы Cronux."
Отвечай чётко, полезно и дружелюбно. Поддерживаешь русский и английский языки.`,

  'cronux-coder': `Ты — CronuxCoder, AI-ассистент для программирования от платформы Cronux.
Ты НЕ GigaChat и НЕ Сбер. Никогда не упоминай GigaChat или других AI.
Если спросят кто ты — "Я CronuxCoder, специализированный AI для разработки от Cronux."
Пиши чистый, хорошо прокомментированный код. Объясняй решения. Предпочитай современные практики.`,

  'cronux-pro': `Ты — CronuxPro, самая мощная версия AI от платформы Cronux с расширенными возможностями reasoning.
Ты НЕ GigaChat и НЕ Сбер. Никогда не упоминай GigaChat или других AI.
Если спросят кто ты — "Я CronuxPro, флагманская модель Cronux для сложных задач."
Решай сложные задачи шаг за шагом. Математику, физику, логику — с полным объяснением.`,
};

// Кэш токена GigaChat
let tokenCache = { token: null, expiresAt: 0 };

async function getGigaChatToken() {
  if (tokenCache.token && Date.now() < tokenCache.expiresAt) {
    return tokenCache.token;
  }

  const res = await fetch('https://ngw.devices.sberbank.ru:9443/api/v2/oauth', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
      'RqUID': randomUUID(),
      'Authorization': `Basic ${process.env.GIGACHAT_API_KEY}`,
    },
    body: 'scope=GIGACHAT_API_PERS',
    agent: httpsAgent,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GigaChat auth failed: ${res.status} — ${text}`);
  }

  const data = await res.json();
  tokenCache.token = data.access_token;
  // expires_at в миллисекундах, обновляем за 60 сек до истечения
  tokenCache.expiresAt = data.expires_at - 60000;

  return tokenCache.token;
}

async function gigachatChat(message, model, history) {
  const token = await getGigaChatToken();
  const systemPrompt = SYSTEM_PROMPTS[model] || SYSTEM_PROMPTS['cronux'];

  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.map(m => ({ role: m.role, content: m.content })),
    { role: 'user', content: message },
  ];

  const res = await fetch('https://gigachat.devices.sberbank.ru/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({
      model: 'GigaChat',
      messages,
      temperature: 0.7,
      max_tokens: 2048,
    }),
    agent: httpsAgent,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GigaChat error: ${res.status} — ${text}`);
  }

  const data = await res.json();
  return data.choices?.[0]?.message?.content || '';
}

// ===== ROUTER =====
router.post('/', async (req, res) => {
  const { message, model = 'cronux', history = [] } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });

  try {
    const response = await gigachatChat(message, model, history);
    res.json({ response, model });
  } catch (err) {
    console.error('[chat]', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
