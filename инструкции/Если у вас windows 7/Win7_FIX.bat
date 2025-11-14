@echo off
cd /d "%~dp0\..\.." >nul
if not exist "Smart_Zapret_Launcher.bat" exit

echo Loading...
copy "Smart_Zapret_Launcher.bat" "temp_fix.bat" >nul

(
for /f "usebackq delims=" %%i in ("temp_fix.bat") do (
  set "line=%%i"
  setlocal enabledelayedexpansion
  set "line=!line:[90m=!"
  set "line=!line:[91m=!"
  set "line=!line:[92m=!"
  set "line=!line:[93m=!"
  set "line=!line:[94m=!"
  set "line=!line:[95m=!"
  set "line=!line:[96m=!"
  set "line=!line:[97m=!"
  set "line=!line:[0m=!"
  set "line=!line:=!"
  echo(!line!
  endlocal
)
) > "Smart_Zapret_Launcher.bat"

del "temp_fix.bat" >nul
echo Completed. Press any key to exit
pause >nul