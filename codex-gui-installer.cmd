@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "ORIGINAL_USERPROFILE="
set "CLOSE_ON_ELEVATE=0"
set "SINGLE_ACTION=0"
set "ACTION="

:parse_args
if "%~1"=="" goto args_done

if /I "%~1"=="--userprofile-b64" (
  if not "%~2"=="" (
    set "UP_B64=%~2"
    for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$v=$env:UP_B64; $b=[Convert]::FromBase64String($v); [Text.Encoding]::UTF8.GetString($b)"`) do set "ORIGINAL_USERPROFILE=%%I"
    shift
    shift
    goto parse_args
  )
)

if /I "%~1"=="--use-profile-file" (
  if not "%~2"=="" (
    set "PROFILE_FILE=%~2"
    if exist "%PROFILE_FILE%" (
      for /f "usebackq delims=" %%I in ("%PROFILE_FILE%") do set "ORIGINAL_USERPROFILE=%%I"
    )
    shift
    shift
    goto parse_args
  )
)

if /I "%~1"=="--userprofile" (
  if not "%~2"=="" (
    set "ORIGINAL_USERPROFILE=%~2"
    shift
    shift
    :collect_userprofile_tail
    if "%~1"=="" goto parse_args
    if /I "%~1"=="--close-on-elevate" goto parse_args
    if /I "%~1"=="--action" goto parse_args
    if /I "%~1"=="install" goto parse_args
    if /I "%~1"=="reinstall" goto parse_args
    if /I "%~1"=="uninstall" goto parse_args
    if /I "%~1"=="update-api-key" goto parse_args
    if /I "%~1"=="update_api_key" goto parse_args
    set "ORIGINAL_USERPROFILE=%ORIGINAL_USERPROFILE% %~1"
    shift
    goto collect_userprofile_tail
  )
)

if /I "%~1"=="--close-on-elevate" (
  set "CLOSE_ON_ELEVATE=1"
  shift
  goto parse_args
)

if /I "%~1"=="--action" (
  if not "%~2"=="" (
    set "SINGLE_ACTION=1"
    set "ACTION=%~2"
    shift
    shift
    goto parse_args
  )
)

if /I "%~1"=="install" set "SINGLE_ACTION=1" & set "ACTION=install"
if /I "%~1"=="reinstall" set "SINGLE_ACTION=1" & set "ACTION=reinstall"
if /I "%~1"=="uninstall" set "SINGLE_ACTION=1" & set "ACTION=uninstall"
if /I "%~1"=="update-api-key" set "SINGLE_ACTION=1" & set "ACTION=update-api-key"
if /I "%~1"=="update_api_key" set "SINGLE_ACTION=1" & set "ACTION=update-api-key"

shift
goto parse_args

:args_done
if not defined ORIGINAL_USERPROFILE set "ORIGINAL_USERPROFILE=%USERPROFILE%"

call :ensure_elevated "%ORIGINAL_USERPROFILE%"
title Codex GUI Installer

set "CODEX_DIR=%ORIGINAL_USERPROFILE%\.codex"
set "CONFIG_PATH=%CODEX_DIR%\config.toml"
set "AUTH_JSON_PATH=%CODEX_DIR%\auth.json"
set "API_PORTAL_URL=https://apex.oraclecorp.com/pls/apex/r/oca/api-key/home"

set "POST_ACTION_TARGET=menu"
set "ON_FAIL_TARGET=menu"
if "%SINGLE_ACTION%"=="1" (
  set "POST_ACTION_TARGET=end"
  set "ON_FAIL_TARGET=end_fail"
  goto run_action
)

:menu
echo.
echo Codex GUI Installer
echo 1. Install
echo 2. Reinstall
echo 3. Uninstall
echo 4. Update API Key
echo Q. Quit
set /p "CHOICE=Select an option: "

if /I "%CHOICE%"=="1" goto install
if /I "%CHOICE%"=="2" goto reinstall
if /I "%CHOICE%"=="3" goto uninstall
if /I "%CHOICE%"=="4" goto update_api_key
if /I "%CHOICE%"=="Q" goto end

echo Invalid option. Select 1, 2, 3, 4, or Q.
goto menu

:run_action
if /I "%ACTION%"=="install" goto install
if /I "%ACTION%"=="reinstall" goto reinstall
if /I "%ACTION%"=="uninstall" goto uninstall
if /I "%ACTION%"=="update-api-key" goto update_api_key
echo ERROR: Unknown action "%ACTION%".
goto end_fail

:install
call :install_prereqs || goto %ON_FAIL_TARGET%
call :install_codex || goto %ON_FAIL_TARGET%
call :init_config || goto %ON_FAIL_TARGET%
call :prompt_and_store_key || goto %ON_FAIL_TARGET%
echo.
echo Install complete.
goto %POST_ACTION_TARGET%

:reinstall
call :uninstall_codex_allow_fail
call :remove_codex_folder || goto %ON_FAIL_TARGET%
call :install
goto %POST_ACTION_TARGET%

:uninstall
call :uninstall_codex_allow_fail
call :remove_codex_folder || goto %ON_FAIL_TARGET%
echo.
echo Uninstall complete.
goto %POST_ACTION_TARGET%

:update_api_key
if not exist "%CONFIG_PATH%" (
  echo ERROR: %CONFIG_PATH% not found. Run Install first.
  goto %ON_FAIL_TARGET%
)
call :prompt_and_store_key || goto %ON_FAIL_TARGET%
echo.
echo API key and auth file updated.
goto %POST_ACTION_TARGET%

:end_fail
endlocal
exit /b 1
:install_prereqs
echo.
echo ==== Installing prerequisites ====
winget install Git.Git Python.Python.3.14 Microsoft.DotNet.SDK.10 -h --accept-source-agreements --accept-package-agreements --disable-interactivity --source winget
if errorlevel 1 (
  echo ERROR: Failed to install prerequisites.
  exit /b 1
)
exit /b 0

:install_codex
echo.
echo ==== Installing Codex ====
winget install --id 9PLM9XGG6VKS -e -h --accept-source-agreements --accept-package-agreements --disable-interactivity
if errorlevel 1 (
  echo ERROR: Failed to install Codex.
  exit /b 1
)
exit /b 0

:uninstall_codex_allow_fail
echo.
echo ==== Uninstalling Codex GUI (Store app) ====
winget uninstall --id 9PLM9XGG6VKS -e -h --disable-interactivity
if errorlevel 1 (
  echo Store Codex uninstall returned a non-zero code. Continuing.
)
exit /b 0

:remove_codex_folder
echo.
set "CODEX_DIR_PATH=%CODEX_DIR%"
echo ==== Removing "%CODEX_DIR_PATH%" ====
if exist "%CODEX_DIR_PATH%\." (
  rmdir /s /q "%CODEX_DIR_PATH%"
  if errorlevel 1 (
    echo ERROR: Failed to remove "%CODEX_DIR_PATH%".
    exit /b 1
  )
  echo Removed "%CODEX_DIR_PATH%"
) else (
  echo Folder not found: "%CODEX_DIR_PATH%". Skipping.
)
exit /b 0

:init_config
echo.
echo ==== Creating %CONFIG_PATH% ====
if not exist "%CODEX_DIR%" mkdir "%CODEX_DIR%"
if errorlevel 1 (
  echo ERROR: Failed to create %CODEX_DIR%.
  exit /b 1
)

> "%CONFIG_PATH%" (
  echo approval_policy = "on-request"
  echo model_provider = "oca"
  echo preferred_auth_method = "apikey"
  echo model = "gpt-5.3-codex"
  echo profile = "gpt-5-3-codex"
  echo sandbox_mode = "workspace-write"
  echo web_search_request = true
  echo.
  echo trust_level = "trusted"
  echo.
  echo [model_providers.oca]
  echo base_url = "https://code-internal.aiservice.us-chicago-1.oci.oraclecloud.com/20250206/app/litellm"
  echo http_headers = { "client" = "codex-cli", "client-version" = "0" }
  echo model = "gpt5"
  echo name = "Oracle Code Assist"
  echo wire_api = "responses"
  echo api_key = "XXXX"
  echo.
  echo.
  echo [profiles.gpt-4-1]
  echo model = "gpt-4.1"
  echo model_provider = "oca"
  echo review_model = "gpt-4.1"
  echo.
  echo [profiles.gpt-5]
  echo model = "gpt5"
  echo model_provider = "oca"
  echo review_model = "gpt5"
  echo.
  echo [profiles.gpt-5-2]
  echo model = "gpt-5.2"
  echo model_provider = "oca"
  echo review_model = "gpt-5.2"
  echo.
  echo [profiles.gpt-5-codex]
  echo model = "gpt-5-codex"
  echo model_provider = "oca"
  echo review_model = "gpt-5-codex"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-1-codex]
  echo model = "gpt-5.1-codex"
  echo model_provider = "oca"
  echo review_model = "gpt-5.1-codex"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-1-codex-mini]
  echo model = "gpt-5.1-codex-mini"
  echo model_provider = "oca"
  echo review_model = "gpt-5.1-codex-mini"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-1-codex-max]
  echo model = "gpt-5.1-codex-max"
  echo model_provider = "oca"
  echo review_model = "gpt-5.1-codex-max"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-2-codex]
  echo model = "gpt-5.2-codex"
  echo model_provider = "oca"
  echo review_model = "gpt-5.2-codex"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-3-codex]
  echo model = "gpt-5.3-codex"
  echo model_provider = "oca"
  echo review_model = "gpt-5.3-codex"
  echo personality = "pragmatic"
  echo model_reasoning_effort = "medium"
  echo.
  echo [profiles.gpt-5-3-codex.windows]
  echo sandbox = "elevated"
  echo.
  echo [profiles.gpt-5-4]
  echo model = "gpt-5.4"
  echo model_provider = "oca"
  echo review_model = "gpt-5.4"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-4-pro]
  echo model = "gpt-5.4-pro"
  echo model_provider = "oca"
  echo review_model = "gpt-5.4-pro"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-4-mini]
  echo model = "gpt-5.4-mini"
  echo model_provider = "oca"
  echo review_model = "gpt-5.4-mini"
  echo personality = "pragmatic"
  echo.
  echo [profiles.gpt-5-4-nano]
  echo model = "gpt-5.4-nano"
  echo model_provider = "oca"
  echo review_model = "gpt-5.4-nano"
  echo personality = "pragmatic"
  echo.
  echo [notice.model_migrations]
  echo "gpt-5.3-codex" = "gpt-5.4"
)
if errorlevel 1 (
  echo ERROR: Failed to write %CONFIG_PATH%.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=$env:CONFIG_PATH; $c=Get-Content -Raw -Path $p; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($p,$c,$enc)"
if errorlevel 1 (
  echo ERROR: Failed to normalize %CONFIG_PATH% encoding.
  exit /b 1
)
exit /b 0

:prompt_and_store_key
echo.
echo ==== Open API key portal ====
:check_vpn
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u=[uri]$env:API_PORTAL_URL; $h=$u.Host; $p=if($u.Port -gt 0){$u.Port}else{443}; try { $tcp=New-Object Net.Sockets.TcpClient; $ar=$tcp.BeginConnect($h,$p,$null,$null); if(-not $ar.AsyncWaitHandle.WaitOne(10000,$false)){ $tcp.Close(); exit 1 }; $tcp.EndConnect($ar); $tcp.Close(); exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo You must connect to the Oracle VPN before obtaining the API key.
  pause
  goto check_vpn
)
start "" "%API_PORTAL_URL%"

:read_key
set "API_KEY="
set /p "API_KEY=Enter API key: "
if "%API_KEY%"=="" (
  echo API key cannot be blank.
  goto read_key
)

set "CODEX_API_KEY=%API_KEY%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=$env:CONFIG_PATH; $k=$env:CODEX_API_KEY; $c=Get-Content -Raw -Path $p; if($c.Contains('api_key = \"XXXX\"')) { $c=$c.Replace('api_key = \"XXXX\"', ('api_key = \"' + $k + '\"')) } elseif($c -match '(?m)^\s*api_key\s*=\s*\".*?\"\s*$') { $c=[regex]::Replace($c,'(?m)^\s*api_key\s*=\s*\".*?\"\s*$','api_key = \"' + $k + '\"',1) } else { $c=$c.TrimEnd() + [Environment]::NewLine + 'api_key = \"' + $k + '\"' + [Environment]::NewLine }; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($p,$c,$enc)"

if errorlevel 1 (
  echo ERROR: Failed to update api_key in %CONFIG_PATH%.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$a=$env:AUTH_JSON_PATH; $k=$env:CODEX_API_KEY; $obj=[ordered]@{auth_mode='apikey'; OPENAI_API_KEY=$k}; $json=$obj | ConvertTo-Json; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($a,$json,$enc)"

if errorlevel 1 (
  echo ERROR: Failed to write %AUTH_JSON_PATH%.
  exit /b 1
)

echo API key saved to %CONFIG_PATH%.
echo Auth file saved to %AUTH_JSON_PATH%.
exit /b 0

:ensure_elevated
set "TARGET_PROFILE=%~1"
if not defined TARGET_PROFILE set "TARGET_PROFILE=%USERPROFILE%"
set "SCRIPT_PATH=%~f0"
set "PROFILE_FILE=%ProgramData%\codex-win-userprofile.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$id=[Security.Principal.WindowsIdentity]::GetCurrent(); $p=New-Object Security.Principal.WindowsPrincipal($id); if($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 0}else{exit 1}"
if errorlevel 1 (
  echo Requesting administrator privileges...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$pf=$env:PROFILE_FILE; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($pf,$env:TARGET_PROFILE,$enc)"
  if errorlevel 1 (
    echo ERROR: Failed to write %PROFILE_FILE%.
    exit /b 1
  )
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$sw='/c'; if('%CLOSE_ON_ELEVATE%' -eq '1'){ $sw='/k' }; $cmd='call "' + $env:SCRIPT_PATH + '" --use-profile-file "' + $env:PROFILE_FILE + '"'; if('%CLOSE_ON_ELEVATE%' -eq '1'){ $cmd += ' --close-on-elevate' }; if('%ACTION%' -ne ''){ $cmd += ' %ACTION%' }; Start-Process -FilePath $env:ComSpec -ArgumentList @($sw, $cmd) -Verb RunAs"
  if errorlevel 1 (
    echo ERROR: Elevation was cancelled or failed.
    pause
    exit /b 1
  )
  if /I "%CLOSE_ON_ELEVATE%"=="1" (
    exit
  )
  exit /b 0
)
exit /b 0
:end
endlocal
exit /b 0
