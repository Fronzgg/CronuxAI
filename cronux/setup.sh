#!/bin/bash
# Cronux — автоустановка с Ollama
# Запуск: bash setup.sh

set -e

GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "  ⬡  CRONUX AI — Setup"
echo -e "${NC}"

# 1. Проверить Ollama
if ! command -v ollama &> /dev/null; then
  echo "📦 Устанавливаю Ollama..."
  curl -fsSL https://ollama.ai/install.sh | sh
else
  echo -e "${GREEN}✓ Ollama уже установлен${NC}"
fi

# 2. Запустить Ollama в фоне если не запущен
if ! curl -s http://localhost:11434 > /dev/null 2>&1; then
  echo "🚀 Запускаю Ollama..."
  ollama serve &
  sleep 3
else
  echo -e "${GREEN}✓ Ollama уже запущен${NC}"
fi

# 3. Скачать модели (7B — работает на 8GB RAM)
echo ""
echo "📥 Скачиваю модели Qwen2.5 (7B)..."
echo "   Cronux (base)..."
ollama pull qwen2.5:7b

echo "   CronuxCoder..."
ollama pull qwen2.5-coder:7b

echo "   CronuxPro (14B, нужно 16GB RAM)..."
ollama pull qwen2.5:14b

# 4. Установить Node зависимости
echo ""
echo "📦 Устанавливаю Node.js зависимости..."
cd server && npm install && cd ..

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""
echo "Запуск сервера:"
echo "  cd cronux/server && node index.js"
echo ""
echo "Открыть в браузере: http://localhost:3000"
echo "Логин: Fronz / fronz123"
