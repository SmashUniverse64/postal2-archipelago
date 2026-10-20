@echo off
cd /d "%~dp0..\System"
if exist Archipelago.u del Archipelago.u
echo Compiling UnrealScript (Archipelago package)...
UCC.exe make
echo.
if exist Archipelago.u (
    echo OK: Archipelago.u is in %CD%
    copy /Y "%~dp0Archipelago.int" "%CD%\Archipelago.int" >nul
    echo Copied Archipelago.int into System
) else (
    echo FAILED: Archipelago.u was not produced. Check ucc.log in this folder.
)
pause
