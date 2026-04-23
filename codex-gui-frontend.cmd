@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "FRONTEND_PS1=%SCRIPT_DIR%codex-gui-frontend.ps1"

if not exist "%FRONTEND_PS1%" (
  for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $name='codex-gui-frontend.ps1'; $roots=@((Get-Location).Path, (Join-Path $env:USERPROFILE 'Downloads'), $env:TEMP); foreach($r in $roots){ if([string]::IsNullOrWhiteSpace($r) -or -not (Test-Path -LiteralPath $r)){ continue }; $f=Get-ChildItem -LiteralPath $r -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){ $f.FullName; exit 0 } }; $zipRoots=@((Get-Location).Path, (Join-Path $env:USERPROFILE 'Downloads')); foreach($zr in $zipRoots){ if([string]::IsNullOrWhiteSpace($zr) -or -not (Test-Path -LiteralPath $zr)){ continue }; $zip=Get-ChildItem -LiteralPath $zr -File -Filter '*.zip' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'codex-win*.zip' -or $_.Name -eq 'main.zip' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if($zip){ $out=Join-Path $env:TEMP 'codex-win-bootstrap'; Expand-Archive -LiteralPath $zip.FullName -DestinationPath $out -Force; $f=Get-ChildItem -LiteralPath $out -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){ $f.FullName; exit 0 } } }; exit 1"` ) do set "FRONTEND_PS1=%%I"
)

if not exist "%FRONTEND_PS1%" (
  echo ERROR: Could not locate codex-gui-frontend.ps1.
  echo Extract the codex-win ZIP and run this script again.
  pause
  exit /b 1
)

start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%FRONTEND_PS1%"
exit /b 0
endlocal