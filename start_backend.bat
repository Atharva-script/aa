@echo off
title Cyber Owl Backend Server
echo ============================================================
echo Starting Cyber Owl Backend Server...
echo IMPORTANT: If Windows Firewall asks, select "Allow Access" 
echo for BOTH Private and Public networks to enable mobile connection.
echo ============================================================
cd /d "%~dp0Main_Cyber_Owl_App"
call "%~dp0.venv\Scripts\activate.bat"
echo Checking for LAN IP...
:loop
python api_server_updated.py
echo.
echo Server has stopped. Restarting in 5 seconds...
timeout /t 5
goto loop
