const express = require('express');
const router = express.Router();
const fetch = require('node-fetch');

router.post('/', async (req, res) => {
  const { query } = req.body;
  if (!query) return res.status(400).json({ error: 'query required' });

  try {
    let results;

    if (process.env.SERP_API_KEY) {
      results = await serpSearch(query);
    } else {
      results = await duckduckgoSearch(query);
    }

    res.json({ results });
  } catch (err) {
    console.error('[search]', err.message);
    // Не падаем — возвращаем пустой результат, LLM ответит без контекста
    res.json({ results: '' });
  }
});

// SerpAPI
async function serpSearch(query) {
  const url = `https://serpapi.com/search.json?q=${encodeURIComponent(query)}&api_key=${process.env.SERP_API_KEY}&num=5&hl=ru`;
  const res = await fetch(url);
  const data = await res.json();

  return (data.organic_results || [])
    .slice(0, 5)
    .map(r => `• ${r.title}\n  ${r.snippet}\n  Источник: ${r.link}`)
    .join('\n\n');
}

// DuckDuckGo (бесплатно, без ключа)
async function duckduckgoSearch(query) {
  const url = `https://api.duckduckgo.com/?q=${encodeURIComponent(query)}&format=json&no_html=1&skip_disambig=1`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'CronuxAI/1.0' }
  });
  const data = await res.json();

  const parts = [];

  if (data.AbstractText) {
    parts.push(`${data.AbstractText}\nИсточник: ${data.AbstractURL}`);
  }

  (data.RelatedTopics || []).slice(0, 4).forEach(t => {
    if (t.Text) parts.push(`• ${t.Text}`);
  });

  return parts.join('\n\n') || `Поиск по запросу "${query}" не дал результатов через DuckDuckGo API.`;
}

module.exports = router;
