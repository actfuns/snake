SET PYTHONPATH=./tools/Python27/Lib/site-packages
@echo off
color 07
chcp 936
rmdir /S /Q luadata
mkdir luadata
set START_TIME=%time%
.\tools\Python27\python.exe xls2lua.py
if ERRORLEVEL 1 (
	color 04 
	pause
)
set XLS_END_TIME=%time%

del /a /f gamedata\server\data.lua
.\tools\lua\lua.exe .\lua2game_scripts\server\init.lua luadata gamedata/server
if ERRORLEVEL 1 (
	color 04 
	pause
)
set PARSE_END_TIME=%time%
chcp 65001
if ERRORLEVEL 1 (
	color 04 
	pause
)

color 02
echo 服务端导表成功!!!!!!!!!!!
echo 耗时情况----------
echo   start at:        %START_TIME%
echo   xlsx trans done: %XLS_END_TIME%
echo   end parse:       %PARSE_END_TIME%


.\tools\lua\lua.exe .\client\convert\_run.lua
if ERRORLEVEL 1 (
    color 04 
    pause
)
chcp 65001
if ERRORLEVEL 1 (
    color 04 
    pause
)

color 02
echo 客户端导表成功!!!!!!!!!!!

pause
