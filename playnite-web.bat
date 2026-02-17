@echo off
setlocal enabledelayedexpansion

REM Change to the script directory
cd /d "%~dp0"

REM Check if docker compose file exists, if not download it
if not exist "playnite-web.docker-compose.yaml" (
    REM curl -L -o playnite-web.docker-compose.yaml https://public.home.playniteweb.com/wiki/download/attachments/27525162/playnite-web.docker-compose.yaml?api=v2
    if not exist "playnite-web.docker-compose.yaml" (
        echo Failed to download docker compose file.
        timeout /t 5 & exit /b 1
    )
    echo Downloaded docker compose file.
)

REM Handle command line arguments

if "%~1"=="clean" (
    docker compose -f playnite-web.docker-compose.yaml down >nul 2>nul
    docker volume rm playnite-web_mqtt_config >nul 2>nul
    docker volume rm playnite-web_mqtt_data >nul 2>nul
    docker volume rm playnite-web_mqtt_log >nul 2>nul
    docker volume rm playnite-web_data >nul 2>nul
    docker volume rm playnite-web_games_assets >nul 2>nul
    REM curl -L -o playnite-web.docker-compose.yaml https://public.home.playniteweb.com/wiki/download/attachments/27525162/playnite-web.docker-compose.yaml?api=v2
    docker compose -f playnite-web.docker-compose.yaml pull
    echo.
    echo Cleaned up.
    echo.
    goto :CREATE_ENV
)
if "%~1"=="update" (
    docker compose -f playnite-web.docker-compose.yaml down >nul 2>nul
    REM curl -L -o playnite-web.docker-compose.yaml https://public.home.playniteweb.com/wiki/download/attachments/27525162/playnite-web.docker-compose.yaml?api=v2
    docker compose -f playnite-web.docker-compose.yaml pull
    docker compose -f playnite-web.docker-compose.yaml up -d
    docker compose -f playnite-web.docker-compose.yaml ps
    goto :eof
)

REM Load environment variables from .env file if it exists
if exist .env (
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
        if "%%a"=="DB_PASSWORD" set "DB_PASSWORD=%%b"
        if "%%a"=="MQTT_PASSWORD" set "MQTT_PASSWORD=%%b"
        if "%%a"=="APP_HOST" set "APP_HOST=%%b"
        if "%%a"=="APP_PORT" set "APP_PORT=%%b"
    )
)

REM If PASSWORD is not set, prompt the user to create .env file
if "%DB_PASSWORD%"=="" goto :CREATE_ENV
if "%MQTT_PASSWORD%"=="" goto :CREATE_ENV

goto :DOCKER

:CREATE_ENV
REM Generate a random characters for DB_PASSWORD, MQTT_PASSWORD and APP_SECRET
for /f "delims=" %%i in ('powershell -Command "$bytes = New-Object Byte[] 24; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes); [System.BitConverter]::ToString($bytes).Replace('-', '').ToLower()"') do set "DB_PASSWORD=%%i"
for /f "delims=" %%i in ('powershell -Command "$bytes = New-Object Byte[] 24; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes); [System.BitConverter]::ToString($bytes).Replace('-', '').ToLower()"') do set "MQTT_PASSWORD=%%i"
for /f "delims=" %%i in ('powershell -Command "$bytes = New-Object Byte[] 64; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes); [System.BitConverter]::ToString($bytes).Replace('-', '').ToLower()"') do set "APP_SECRET=%%i"

REM Prompt the user for optional environment variables
set /p CSP_ORIGINS="CSP_ORIGINS (optional): "
set /p ADDITIONAL_ORIGINS="ADDITIONAL_ORIGINS (optional): "
set /p APP_HOST="APP_HOST (if empty defaults to localhost): "
set /p APP_PORT="APP_PORT (if empty defaults to 3000): "

if "%APP_HOST%"=="" set "APP_HOST=localhost"
if "%APP_PORT%"=="" set "APP_PORT=3000"

REM Create .env file with the provided environment variables
(
  echo COMPOSE_PROJECT_NAME=playnite-web
  echo.
  echo DB_PASSWORD=%DB_PASSWORD%
  echo MQTT_PASSWORD=%MQTT_PASSWORD%
  echo APP_SECRET=%APP_SECRET%
  echo APP_PORT=%APP_PORT%
  echo APP_HOST=%APP_HOST%
  echo PROCESSOR_PORT=3001
  echo DISABLE_CSP=false
  echo CSP_ORIGINS=%CSP_ORIGINS%
  echo ADDITIONAL_ORIGINS=%ADDITIONAL_ORIGINS%
) > .env


echo .env created.


:DOCKER
REM Create volumes
docker volume create playnite-web_data >nul
docker volume create playnite-web_games_assets >nul
docker volume create playnite-web_mqtt_config >nul
docker volume create playnite-web_mqtt_data >nul
docker volume create playnite-web_mqtt_log >nul

REM Create MQTT password file and config
docker run --rm -v playnite-web_mqtt_config:/config eclipse-mosquitto:2.0.18 sh -c "mosquitto_passwd -c -b /config/passwd playnite %MQTT_PASSWORD%"
docker run --rm -v playnite-web_mqtt_config:/config eclipse-mosquitto:2.0.18 sh -c "echo 'listener 1883' > /config/mosquitto.conf ; echo 'allow_anonymous false' >> /config/mosquitto.conf ; echo 'password_file /mosquitto/config/passwd' >> /config/mosquitto.conf ; echo 'listener 9001' >> /config/mosquitto.conf ; echo 'protocol websockets' >> /config/mosquitto.conf"

REM Start the application using docker-compose
docker compose -f playnite-web.docker-compose.yaml up -d
docker compose -f playnite-web.docker-compose.yaml ps

echo.
echo Visit http://%APP_HOST%:%APP_PORT%
start http://%APP_HOST%:%APP_PORT%
timeout /t 5
exit /b

:VALIDATE
REM Prompt the user for input and validate that it is not empty
:LOOP
set "input="
for /f "delims=" %%i in ('powershell -Command "$p = read-host '%~2'; write-host $p"') do set "input=%%i"

if "%input%"=="" (
    echo [ERROR] Can not be empty!
    goto :LOOP
)
set "%~1=%input%"
goto :eof