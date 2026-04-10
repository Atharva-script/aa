@echo off
set "BASE_DIR=%~dp0"
echo [CyberOwl] Launching App...

:: Check paths one by one to avoid parser issues with complex list syntax
set "P1=main_login_system\main_login_system\build\windows\x64\runner\Release\main_login_system.exe"
set "P2=main_login_system\main_login_system\build\windows\x64\runner\Debug\main_login_system.exe"
set "P3=CyberOwl_setup\bin\main_login_system.exe"

if exist "%BASE_DIR%%P1%" (
    echo [CyberOwl] Found at %BASE_DIR%%P1%
    start "" "%BASE_DIR%%P1%"
    exit /b 0
)

if exist "%BASE_DIR%%P2%" (
    echo [CyberOwl] Found at %BASE_DIR%%P2%
    start "" "%BASE_DIR%%P2%"
    exit /b 0
)

if exist "%BASE_DIR%%P3%" (
    echo [CyberOwl] Found at %BASE_DIR%%P3%
    start "" "%BASE_DIR%%P3%"
    exit /b 0
)

echo [CyberOwl] ERROR: Executable not found!
pause
exit /b 1
