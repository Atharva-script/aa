@echo off
title Cyber Owl - Setup Wizard
echo ========================================
echo    CYBER OWL - Installation
echo    Ensure Child Security
echo ========================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed!
    echo Please install Python 3.8 or higher from python.org
    pause
    exit /b 1
)

echo Running setup wizard...
echo.
python setup_wizard.py

if errorlevel 1 (
    echo.
    echo Setup encountered errors!
    pause
    exit /b 1
)

echo.
echo ========================================
echo    Installation Complete!
echo ========================================
pause
