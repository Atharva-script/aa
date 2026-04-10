@echo off
echo Starting Cyber Owl Windows PC App...
cd /d "%~dp0Main_Cyber_Owl_App"

:: Check if backend is already running on port 5000
netstat -ano | findstr LISTENING | findstr :5000 > nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Backend server is not running on port 5000.
    echo [WARNING] The app may fail to connect.
    echo [TIP] Run start_backend.bat first.
    echo.
    timeout /t 5
)

call launch_cyberowl.bat
pause
