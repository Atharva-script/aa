# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['api_server_updated.py'],
    pathex=[],
    binaries=[],
    datas=[('.env', '.'), ('components', 'components'), ('email_system', 'email_system')],
    hiddenimports=['pymongo', 'pymongo.server_api', 'certifi', 'onnxruntime', 'flask_socketio', 'flask_cors', 'engineio.async_drivers.threading', 'dotenv', 'SpeechRecognition', 'pyaudio', 'nudenet', 'pyttsx3', 'win32com.client'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='CyberOwl_Server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
