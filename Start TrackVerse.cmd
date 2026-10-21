@echo off
set "TRACKVERSE_DATA_DIR=%~dp0.local-data"
cd /d "%~dp0"
if not exist "node_modules\electron\dist\electron.exe" (
  echo Run npm install first to download the desktop runtime.
  pause
  exit /b 1
)
start "TrackVerse" "node_modules\electron\dist\electron.exe" "."
