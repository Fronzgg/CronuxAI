# Cronux AI — MVP

## Быстрый старт (демо без GPU)

```bash
cd cronux/server
npm install
node index.js
```

Открыть: http://localhost:3000
Тестовый аккаунт: **Fronz** / **fronz123** (безлимит)

---

## Подключение реальных моделей

### Вариант 1: Ollama (локально)
```bash
# Установить Ollama: https://ollama.ai
ollama pull qwen2.5:32b
ollama pull qwen2.5-coder:32b

# В .env:
AI_MODE=ollama
OLLAMA_URL=http://localhost:11434
```

### Вариант 2: Together.ai (облако, pay-as-you-go)
```bash
# В .env:
AI_MODE=together
TOGETHER_API_KEY=ваш_ключ
```
Цены: ~$0.8/1M токенов для Qwen2.5-32B

### Вариант 3: DeepSeek API (для CronuxPro)
```bash
# В .env:
AI_MODE=deepseek
DEEPSEEK_API_KEY=ваш_ключ
```
DeepSeek-V3 — бесплатный тариф есть, платный ~$0.27/1M токенов

---

## Docker (Ollama + сервер)
```bash
cp server/.env.example server/.env
# Отредактировать .env
docker-compose up -d

# Загрузить модель в Ollama контейнер:
docker exec cronux-ollama ollama pull qwen2.5:32b
```

---

## Поиск в интернете
- Без ключа: DuckDuckGo API (бесплатно, ограничено)
- С ключом: SerpAPI (100 запросов/месяц бесплатно)
  ```
  SERP_API_KEY=ваш_ключ
  ```

---

## Рекомендации по моделям

| Роль | Модель | Хостинг |
|------|--------|---------|
| Cronux (base) | Qwen2.5-32B-Instruct | Ollama / Together.ai |
| CronuxCoder | Qwen2.5-Coder-32B | Ollama / Together.ai |
| CronuxPro | DeepSeek-V3 | DeepSeek API / Together.ai |

---

## Переход на Flutter (план)

1. Заменить HTML/JS на Flutter Web + Mobile
2. API сервер остаётся тем же (Node.js/Express)
3. Использовать `http` пакет для запросов
4. `shared_preferences` вместо localStorage
5. `image_picker` для загрузки фото (OCR)
6. `flutter_markdown` для рендера ответов
7. Деплой: Flutter Web → Netlify/Vercel, Mobile → Play Store
