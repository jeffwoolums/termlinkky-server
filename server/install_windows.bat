@echo off
echo TermLinkky Server Installer for Windows
echo ========================================
echo.

REM Check for Python
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Install from: https://www.python.org/downloads/
    pause
    exit /b 1
)

REM Check for OpenSSL
openssl version >nul 2>&1
if errorlevel 1 (
    echo Warning: OpenSSL not found. Certificate generation may fail.
    echo Install from: https://slproweb.com/products/Win32OpenSSL.html
)

REM Install dependencies
echo Installing Python dependencies...
pip install aiohttp pywinpty

REM Generate certificate
if not exist "certs\server.crt" (
    echo Generating SSL certificate...
    mkdir certs 2>nul
    openssl req -x509 -newkey rsa:4096 -keyout certs\server.key -out certs\server.crt -days 3650 -nodes -subj "/CN=%COMPUTERNAME%/O=TermLinkky"
)

echo.
echo Installation complete!
echo.
echo To start the server, run:
echo   python server_windows.py
echo.
pause
