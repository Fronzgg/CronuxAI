@echo off
:: Cronux — установка на Windows
echo.
echo   [Cronux AI - Setup]
echo.

:: Проверить Ollama
where ollama >nul 2>&1
if %errorlevel% neq 0 (
    echo Ollama не найден.
    echo Скачай и установи с: https://ollama.ai/download
    echo После установки запусти этот скрипт снова.
    pause
    exit /b 1
)

echo [OK] Ollama найден

:: Запустить Ollama
echo Запускаю Ollama...
start /B ollama serve
timeout /t 3 /nobreak >nul

:: Скачать модели
echo.
echo Скачиваю Qwen2.5:7b (Cronux base)...
ollama pull qwen2.5:7b

:: Node зависимости
echo.
echo Устанавливаю Node.js зависимости...
cd server
npm install
cd ..

echo.
echo [ГОТОВО]
echo.
echo Запуск: cd cronux\server ^&^& node index.js
echo Браузер: http://localhost:3000
echo Логин: Fronz / fronz123
pause
