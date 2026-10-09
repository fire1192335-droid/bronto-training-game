@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
if not errorlevel 1 goto :eof
python -c "import http.server" >nul 2>nul
if errorlevel 1 (
  echo 無法啟動本機伺服器：這台電腦的 PowerShell 與 Python 都無法使用。
  echo 請改用發布網址開啟遊戲。
  pause
  goto :eof
)
start "" cmd /c "timeout /t 2 >nul & start "" http://127.0.0.1:8730/"
python -m http.server 8730 --bind 127.0.0.1
if errorlevel 1 (
  echo 本機伺服器啟動失敗，可能是連接埠 8730 已被占用。請關閉其他視窗後再試一次。
  pause
)
