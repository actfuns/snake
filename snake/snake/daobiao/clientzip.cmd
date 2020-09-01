SET PYTHONPATH=./tools/Python27/Lib/site-packages
@echo off
color 07
chcp 936

rmdir /S /Q logic\data\
mkdir logic\data\
.\tools\lua\lua.exe .\client\convert\_run.lua .\logic\data\

if ERRORLEVEL 1 (
    color 04 
    pause
)
chcp 65001
if ERRORLEVEL 1 (
    color 04 
    pause
)

.\tools\Python27\python.exe clientzip.py .\logic\data\ opendata ./gamedata/server/client-daobiao
rmdir /S /Q logic\

color 02
echo 生成客户端导表MD5验证包!!!!!!!!!!!!!!!!!!!!!!!!!!

pause