@echo off
chcp 65001 >nul
title 借光 - 本机游戏服务
echo 正在启动借光。浏览器打开后，请保持此窗口开启。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-local.ps1"
pause
