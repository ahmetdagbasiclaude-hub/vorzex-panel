@echo off
rem Vorzex Gelistirme Araci kurulumu (her bilgisayarda bir kez; yonetici izni gerekmez).
rem Araci %LOCALAPPDATA%\VorzexGelistirme klasorune indirir ve "vorzex-gelistir:" adresini ona baglar
rem (paneldeki Gelistirme dugmeleri bu adresi acar). Kaldirmak: reg delete HKCU\Software\Classes\vorzex-gelistir /f
chcp 65001 >nul
echo Vorzex Gelistirme Araci kuruluyor...
set "D=%LOCALAPPDATA%\VorzexGelistirme"
if not exist "%D%" mkdir "%D%"
if defined VX_KAYNAK (
  copy /y "%VX_KAYNAK%" "%D%\vorzex-gelistir.ps1" >nul
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; Invoke-WebRequest -UseBasicParsing 'https://ahmetdagbasiclaude-hub.github.io/vorzex-panel/gelistirme/vorzex-gelistir.ps1' -OutFile ($env:LOCALAPPDATA + '\VorzexGelistirme\vorzex-gelistir.ps1')"
)
if errorlevel 1 goto hata
if not exist "%D%\vorzex-gelistir.ps1" goto hata
reg add "HKCU\Software\Classes\vorzex-gelistir" /ve /d "URL:Vorzex Gelistirme" /f >nul || goto hata
reg add "HKCU\Software\Classes\vorzex-gelistir" /v "URL Protocol" /d "" /f >nul || goto hata
reg add "HKCU\Software\Classes\vorzex-gelistir\shell\open\command" /ve /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%D%\vorzex-gelistir.ps1\" \"%%1\"" /f >nul || goto hata
echo.
echo Kuruldu. Paneldeki Gelistirme sekmesinde "Araci dene" ile kontrol edebilirsin.
if not defined VX_KAYNAK pause
exit /b 0
:hata
echo.
echo Kurulum olmadi: internet baglantini kontrol edip tekrar calistir.
if not defined VX_KAYNAK pause
exit /b 1
