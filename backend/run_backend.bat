@echo off
setlocal
cd /d "%~dp0\.."
python backend\server.py
if %errorlevel% neq 0 (
  py -3 backend\server.py
)
