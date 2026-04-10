@echo off
set "PATH=%PATH%;%LOCALAPPDATA%\Android\Sdk\platform-tools"
set "BASE_DIR=%~dp0"
echo [CyberOwl] Launching App on Android Device...

:: Check paths for built APKs
set "P1=CyberOwl_android\build\app\outputs\flutter-apk\app-release.apk"
set "P2=CyberOwl_android\build\app\outputs\flutter-apk\app-debug.apk"

if exist "%BASE_DIR%%P1%" (
    echo [CyberOwl] Found at %BASE_DIR%%P1%
    echo [CyberOwl] Installing...
    adb install -r "%BASE_DIR%%P1%"
    echo [CyberOwl] Starting...
    adb shell am start -n "com.cyberowl.cyberowl_parent/com.cyberowl.cyberowl_parent.MainActivity"
    exit /b 0
)

if exist "%BASE_DIR%%P2%" (
    echo [CyberOwl] Found at %BASE_DIR%%P2%
    echo [CyberOwl] Installing...
    adb install -r "%BASE_DIR%%P2%"
    echo [CyberOwl] Starting...
    adb shell am start -n "com.cyberowl.cyberowl_parent/com.cyberowl.cyberowl_parent.MainActivity"
    exit /b 0
)

echo [CyberOwl] ERROR: APK not found! Please build the app first.
pause
exit /b 1
