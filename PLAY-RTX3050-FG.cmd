@echo off
rem VIctory-Slim_Shady — RTX 3050 (4 GB VRAM + 32 GB RAM) + DLSS Frame Generation Launcher
rem Double-click or run: PLAY-RTX3050-FG.cmd -Exe "D:\GTA6\Game\game_scarlett_master.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play-rtx3050-framegen.ps1" %*
pause
