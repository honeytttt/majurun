@echo off
REM MajuRun Release Build Script for Windows
REM Usage: scripts\build_release.bat [android]

setlocal EnableDelayedExpansion

REM Check if .env exists
if not exist .env (
    echo ERROR: .env file not found!
    echo Copy .env.example to .env and fill in your values.
    exit /b 1
)

REM Load .env file
for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    set "%%a=%%b"
)

REM Validate required variables
if "%CLOUDINARY_CLOUD_NAME%"=="" (
    echo ERROR: CLOUDINARY_CLOUD_NAME not set in .env
    exit /b 1
)
if "%CLOUDINARY_API_KEY%"=="" (
    echo ERROR: CLOUDINARY_API_KEY not set in .env
    exit /b 1
)
if "%CLOUDINARY_UPLOAD_PRESET%"=="" (
    echo ERROR: CLOUDINARY_UPLOAD_PRESET not set in .env
    exit /b 1
)

REM Set default environment
if "%ENVIRONMENT%"=="" set ENVIRONMENT=production

echo Building with environment: %ENVIRONMENT%

REM Build dart-define arguments
set DART_DEFINES=--dart-define=ENVIRONMENT=%ENVIRONMENT%
set DART_DEFINES=%DART_DEFINES% --dart-define=CLOUDINARY_CLOUD_NAME=%CLOUDINARY_CLOUD_NAME%
set DART_DEFINES=%DART_DEFINES% --dart-define=CLOUDINARY_API_KEY=%CLOUDINARY_API_KEY%
set DART_DEFINES=%DART_DEFINES% --dart-define=CLOUDINARY_UPLOAD_PRESET=%CLOUDINARY_UPLOAD_PRESET%

if not "%WEATHER_API_KEY%"=="" set DART_DEFINES=%DART_DEFINES% --dart-define=WEATHER_API_KEY=%WEATHER_API_KEY%
if not "%GOOGLE_MAPS_KEY%"=="" set DART_DEFINES=%DART_DEFINES% --dart-define=GOOGLE_MAPS_KEY=%GOOGLE_MAPS_KEY%
if not "%RECAPTCHA_KEY%"=="" set DART_DEFINES=%DART_DEFINES% --dart-define=RECAPTCHA_KEY=%RECAPTCHA_KEY%
if not "%API_BASE_URL%"=="" set DART_DEFINES=%DART_DEFINES% --dart-define=API_BASE_URL=%API_BASE_URL%

echo.
echo ==========================================
echo Building Android App Bundle...
echo ==========================================
flutter build appbundle --release %DART_DEFINES%

echo.
echo Build complete!
echo Android AAB: build\app\outputs\bundle\release\app-release.aab
